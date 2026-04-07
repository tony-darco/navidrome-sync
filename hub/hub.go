package hub

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"

	"navidrome-sync/navidrome"
)

// --- Message types ---

const (
	// Inbound
	MsgRegister           = "REGISTER"
	MsgNowPlaying         = "NOW_PLAYING"
	MsgPositionUpdate     = "POSITION_UPDATE"
	MsgClaim              = "CLAIM"
	MsgPlay               = "PLAY"
	MsgPause              = "PAUSE"
	MsgNext               = "NEXT"
	MsgPrev               = "PREV"
	MsgSeek               = "SEEK"
	MsgPlaySong           = "PLAY_SONG"
	MsgLoadQueue          = "LOAD_QUEUE"
	MsgSetQueue           = "SET_QUEUE"
	MsgSetPlaybackOptions = "SET_PLAYBACK_OPTIONS"
	MsgPlaylistChanged    = "PLAYLIST_CHANGED"
	MsgStarChanged        = "STAR_CHANGED"

	// Outbound
	MsgStateSync          = "STATE_SYNC"
	MsgCommand            = "COMMAND"
	MsgRoleChange         = "ROLE_CHANGE"
	MsgError              = "ERROR"
	MsgPlaylistInvalidate = "PLAYLIST_INVALIDATE"
	MsgStarNotify         = "STAR_NOTIFY"
)

// Envelope is the wire format for every WebSocket message.
// Inbound messages include clientId; outbound messages omit it.
type Envelope struct {
	Type     string `json:"type"`
	ClientID string `json:"clientId,omitempty"`
	Payload  any    `json:"payload"`
}

// NowPlayingState is the shared playback state held by the hub.
type NowPlayingState struct {
	SongID       string  `json:"songId,omitempty"`
	Title        string  `json:"title,omitempty"`
	Artist       string  `json:"artist,omitempty"`
	Album        string  `json:"album,omitempty"`
	CoverArtID   string  `json:"coverArtId,omitempty"`
	DurationSecs int     `json:"durationSecs,omitempty"`
	PositionSecs float64 `json:"positionSecs"`
	IsPlaying    bool    `json:"isPlaying"`
}

// clientInfo is the per-client summary included in STATE_SYNC broadcasts.
type clientInfo struct {
	ClientID   string `json:"clientId"`
	ClientType string `json:"clientType"`
	Role       string `json:"role"`
}

type inboundMessage struct {
	client   *Client
	envelope Envelope
}

// QueueItem represents a song in the playback queue.
type QueueItem struct {
	SongID       string `json:"songId"`
	Title        string `json:"title"`
	Artist       string `json:"artist"`
	Album        string `json:"album"`
	CoverArtID   string `json:"coverArtId"`
	DurationSecs int    `json:"durationSecs"`
}

// Hub maintains connected clients and the shared playback state.
type Hub struct {
	mu             sync.RWMutex
	clients        map[string]*Client
	activeClientID string
	state          *NowPlayingState
	queue          []QueueItem
	queueIndex     int
	shuffle        bool
	repeatMode     string // "off", "all", "one"

	register   chan *Client
	unregister chan *Client
	incoming   chan inboundMessage
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[string]*Client),
		repeatMode: "off",
		register:   make(chan *Client),
		unregister: make(chan *Client),
		incoming:   make(chan inboundMessage, 64),
	}
}

// Run is the hub's main event loop — must be started as a goroutine.
func (h *Hub) Run() {
	for {
		select {
		case c := <-h.register:
			h.handleRegister(c)
		case c := <-h.unregister:
			h.handleUnregister(c)
		case msg := <-h.incoming:
			h.handleMessage(msg)
		}
	}
}

// CurrentState returns a snapshot of the current now-playing state (thread-safe).
func (h *Hub) CurrentState() *NowPlayingState {
	h.mu.RLock()
	defer h.mu.RUnlock()
	if h.state == nil {
		return nil
	}
	cp := *h.state
	return &cp
}

// UpdateFromPoll is called by the polling goroutine when a new song is detected.
func (h *Hub) UpdateFromPoll(entry *navidrome.NowPlayingEntry) {
	h.mu.Lock()
	if entry == nil {
		h.state = nil
	} else {
		// Preserve the existing play/pause state across poll updates so that a
		// metadata refresh doesn't flip observers back to "paused".
		isPlaying := false
		if h.state != nil {
			isPlaying = h.state.IsPlaying
		}
		h.state = &NowPlayingState{
			SongID:       entry.SongID,
			Title:        entry.Title,
			Artist:       entry.Artist,
			Album:        entry.Album,
			CoverArtID:   entry.CoverArtID,
			DurationSecs: entry.DurationSecs,
			IsPlaying:    isPlaying,
		}
	}
	h.mu.Unlock()

	h.broadcastStateSync()
}

// --- WebSocket upgrade ---

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func (h *Hub) HandleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("ws upgrade error: %v", err)
		return
	}

	clientID := r.URL.Query().Get("clientId")
	if clientID == "" {
		clientID = uuid.New().String()
	}

	c := &Client{
		ID:   clientID,
		hub:  h,
		conn: conn,
		send: make(chan []byte, 64),
	}
	h.register <- c
	go c.writePump()
	go c.readPump()
}

// --- Internal handlers ---

func (h *Hub) handleRegister(c *Client) {
	h.mu.Lock()
	if existing, ok := h.clients[c.ID]; ok {
		log.Printf("client reconnected id=%s, overriding old connection", c.ID)
		existing.conn.Close()
	}

	h.clients[c.ID] = c

	// Assign roles based on active client status.
	_, activeExists := h.clients[h.activeClientID]
	if h.activeClientID == "" || h.activeClientID == c.ID || !activeExists {
		c.Role = "active"
		h.activeClientID = c.ID
	} else {
		c.Role = "observer"
	}
	h.mu.Unlock()

	log.Printf("client registered id=%s role=%s", c.ID, c.Role)

	// Inform the client of its role and current state.
	c.sendJSON(Envelope{
		Type: MsgRoleChange,
		Payload: map[string]string{
			"clientId": c.ID,
			"role":     c.Role,
		},
	})
	h.sendStateSyncTo(c)
}

func (h *Hub) handleUnregister(c *Client) {
	h.mu.Lock()
	if existing, ok := h.clients[c.ID]; !ok || existing != c {
		h.mu.Unlock()
		return
	}
	delete(h.clients, c.ID)
	close(c.send)

	wasActive := h.activeClientID == c.ID

	if wasActive {
		// The client that was actually playing audio is gone — pause state.
		if h.state != nil {
			h.state.IsPlaying = false
		}

		// Promote the first remaining client to active, if any.
		h.activeClientID = ""
		for _, candidate := range h.clients {
			h.activeClientID = candidate.ID
			candidate.Role = "active"
			break
		}
	}
	h.mu.Unlock()

	log.Printf("client disconnected id=%s wasActive=%v newActive=%s", c.ID, wasActive, h.activeClientID)

	if wasActive {
		// Notify the promoted client of its new role.
		h.mu.RLock()
		promoted := h.clients[h.activeClientID]
		h.mu.RUnlock()
		if promoted != nil {
			promoted.sendJSON(Envelope{
				Type: MsgRoleChange,
				Payload: map[string]string{
					"clientId": promoted.ID,
					"role":     "active",
				},
			})
		}
		h.broadcastStateSync()
	}
}

func (h *Hub) handleMessage(msg inboundMessage) {
	switch msg.envelope.Type {
	case MsgRegister:
		h.onRegisterMsg(msg)
	case MsgNowPlaying:
		h.onNowPlaying(msg)
	case MsgPositionUpdate:
		h.onPositionUpdate(msg)
	case MsgClaim:
		h.onClaim(msg)
	case MsgSetQueue:
		h.onSetQueue(msg)
	case MsgSetPlaybackOptions:
		h.onSetPlaybackOptions(msg)
	case MsgPlay, MsgPause, MsgNext, MsgPrev, MsgSeek, MsgPlaySong, MsgLoadQueue:
		h.onTransportCommand(msg)
	case MsgPlaylistChanged:
		h.onPlaylistChanged(msg)
	case MsgStarChanged:
		h.onStarChanged(msg)
	default:
		msg.client.sendError("UNKNOWN_TYPE", "unrecognized message type: "+msg.envelope.Type)
	}
}

// onRegisterMsg handles an explicit REGISTER message that carries clientType.
// It also adopts the client-provided clientId so both sides agree on the ID.
func (h *Hub) onRegisterMsg(msg inboundMessage) {
	payload := parsePayloadMap(msg.envelope.Payload)

	h.mu.Lock()
	msg.client.ClientType = payload["clientType"]

	// Adopt the client-provided ID so the frontend and server agree.
	if newID := msg.envelope.ClientID; newID != "" && newID != msg.client.ID {
		oldID := msg.client.ID
		delete(h.clients, oldID)

		if existing, ok := h.clients[newID]; ok {
			existing.conn.Close()
		}

		msg.client.ID = newID
		h.clients[newID] = msg.client

		if h.activeClientID == oldID || h.activeClientID == newID {
			h.activeClientID = newID
			msg.client.Role = "active"
		}
	}
	h.mu.Unlock()

	log.Printf("client set type id=%s type=%s", msg.client.ID, msg.client.ClientType)

	// Re-broadcast so every client (including this one) gets the updated ID.
	h.broadcastStateSync()
}

// onNowPlaying updates the shared state from a client report and broadcasts.
func (h *Hub) onNowPlaying(msg inboundMessage) {
	data, err := json.Marshal(msg.envelope.Payload)
	if err != nil {
		msg.client.sendError("BAD_PAYLOAD", "invalid NOW_PLAYING payload")
		return
	}
	var np NowPlayingState
	if err := json.Unmarshal(data, &np); err != nil {
		msg.client.sendError("BAD_PAYLOAD", "invalid NOW_PLAYING payload")
		return
	}

	np.IsPlaying = true
	h.mu.Lock()
	h.state = &np
	h.mu.Unlock()

	log.Printf("now playing updated client=%s song=%q artist=%q", msg.client.ID, np.Title, np.Artist)
	h.broadcastStateSync()
}

// onPositionUpdate accepts a position report from the active client and updates
// the hub state. This is sent periodically (~1s) by the active client so that
// observers (and future CLAIM recipients) know the current playback position.
func (h *Hub) onPositionUpdate(msg inboundMessage) {
	h.mu.Lock()
	if msg.client.ID != h.activeClientID {
		h.mu.Unlock()
		msg.client.sendError("NOT_ACTIVE", "only the active client may send position updates")
		return
	}
	if h.state != nil {
		if pm, ok := msg.envelope.Payload.(map[string]any); ok {
			if pos, ok := pm["positionSecs"].(float64); ok {
				h.state.PositionSecs = pos
			}
		}
	}
	h.mu.Unlock()
	// No broadcast — observers interpolate locally. The next STATE_SYNC
	// (on song change, claim, etc.) will carry the latest position.
}

// onClaim lets any client claim the active role.
func (h *Hub) onClaim(msg inboundMessage) {
	log.Printf("claim requested client=%s", msg.client.ID)
	h.mu.Lock()
	prevActiveID := h.activeClientID
	prevClient := h.clients[prevActiveID]

	h.activeClientID = msg.client.ID
	msg.client.Role = "active"

	// Demote the previously active client, if any.
	if prevClient != nil && prevClient.ID != msg.client.ID {
		prevClient.Role = "observer"
	}
	h.mu.Unlock()

	// Tell the displaced client to stop playback and switch to observer.
	if prevClient != nil && prevClient.ID != msg.client.ID {
		prevClient.sendJSON(Envelope{
			Type: MsgCommand,
			Payload: map[string]any{
				"action": "STOP",
			},
		})
		prevClient.sendJSON(Envelope{
			Type: MsgRoleChange,
			Payload: map[string]string{
				"clientId": prevClient.ID,
				"role":     "observer",
			},
		})
	}

	// Confirm the new active client's role.
	msg.client.sendJSON(Envelope{
		Type: MsgRoleChange,
		Payload: map[string]string{
			"clientId": msg.client.ID,
			"role":     "active",
		},
	})

	h.broadcastStateSync()
}

// onTransportCommand handles PLAY, PAUSE, NEXT, PREV, SEEK, PLAY_SONG, PLAY_QUEUE.
// It forwards the command to the active client, passing through any provided payload.
func (h *Hub) onTransportCommand(msg inboundMessage) {
	h.mu.RLock()
	activeID := h.activeClientID
	activeClient := h.clients[activeID]
	h.mu.RUnlock()

	if activeClient == nil {
		msg.client.sendError("NO_ACTIVE_CLIENT", "no active client to receive transport commands")
		return
	}

	payload := map[string]any{
		"action": msg.envelope.Type,
	}

	if pm, ok := msg.envelope.Payload.(map[string]any); ok {
		for k, v := range pm {
			payload[k] = v
		}
	}

	activeClient.sendJSON(Envelope{
		Type:    MsgCommand,
		Payload: payload,
	})

	// Track play/pause state so observers always reflect the true playback state.
	// Only broadcast when state actually changes (i.e. a song is loaded).
	switch msg.envelope.Type {
	case MsgPlay:
		h.mu.Lock()
		changed := h.state != nil && !h.state.IsPlaying
		if changed {
			h.state.IsPlaying = true
		}
		h.mu.Unlock()
		if changed {
			h.broadcastStateSync()
		}
	case MsgPause:
		h.mu.Lock()
		changed := h.state != nil && h.state.IsPlaying
		if changed {
			h.state.IsPlaying = false
		}
		h.mu.Unlock()
		if changed {
			h.broadcastStateSync()
		}
	}
}

// onSetQueue stores the playback queue sent by the active client.
func (h *Hub) onSetQueue(msg inboundMessage) {
	h.mu.Lock()
	if msg.client.ID != h.activeClientID {
		h.mu.Unlock()
		msg.client.sendError("NOT_ACTIVE", "only the active client may set the queue")
		return
	}

	data, err := json.Marshal(msg.envelope.Payload)
	if err != nil {
		h.mu.Unlock()
		msg.client.sendError("BAD_PAYLOAD", "invalid SET_QUEUE payload")
		return
	}
	var payload struct {
		Queue      []QueueItem `json:"queue"`
		QueueIndex int         `json:"queueIndex"`
	}
	if err := json.Unmarshal(data, &payload); err != nil {
		h.mu.Unlock()
		msg.client.sendError("BAD_PAYLOAD", "invalid SET_QUEUE payload")
		return
	}
	h.queue = payload.Queue
	h.queueIndex = payload.QueueIndex
	h.mu.Unlock()

	log.Printf("queue updated client=%s items=%d index=%d", msg.client.ID, len(payload.Queue), payload.QueueIndex)
	h.broadcastStateSync()
}

// onSetPlaybackOptions stores shuffle/repeat from the active client.
func (h *Hub) onSetPlaybackOptions(msg inboundMessage) {
	h.mu.Lock()
	if msg.client.ID != h.activeClientID {
		h.mu.Unlock()
		msg.client.sendError("NOT_ACTIVE", "only the active client may set playback options")
		return
	}
	if pm, ok := msg.envelope.Payload.(map[string]any); ok {
		if s, ok := pm["shuffle"].(bool); ok {
			h.shuffle = s
		}
		if r, ok := pm["repeatMode"].(string); ok {
			switch r {
			case "off", "all", "one":
				h.repeatMode = r
			default:
				// ignore invalid values
			}
		}
	}
	h.mu.Unlock()

	log.Printf("playback options updated client=%s shuffle=%v repeat=%s", msg.client.ID, h.shuffle, h.repeatMode)
	h.broadcastStateSync()
}

// --- Broadcasting helpers ---

// buildStateSyncPayload constructs the STATE_SYNC payload snapshot.
// Must be called while h.mu is at least read-locked.
func (h *Hub) buildStateSyncPayload() map[string]any {
	ci := make([]clientInfo, 0, len(h.clients))
	for _, c := range h.clients {
		ci = append(ci, clientInfo{
			ClientID:   c.ID,
			ClientType: c.ClientType,
			Role:       c.Role,
		})
	}
	return map[string]any{
		"activeClientId": h.activeClientID,
		"song":           h.state,
		"clients":        ci,
		"queue":          h.queue,
		"queueIndex":     h.queueIndex,
		"shuffle":        h.shuffle,
		"repeatMode":     h.repeatMode,
	}
}

func (h *Hub) broadcastStateSync() {
	h.mu.RLock()
	payload := h.buildStateSyncPayload()
	clients := make([]*Client, 0, len(h.clients))
	for _, c := range h.clients {
		clients = append(clients, c)
	}
	h.mu.RUnlock()

	env := Envelope{Type: MsgStateSync, Payload: payload}
	for _, c := range clients {
		c.sendJSON(env)
	}
}

func (h *Hub) sendStateSyncTo(c *Client) {
	h.mu.RLock()
	payload := h.buildStateSyncPayload()
	h.mu.RUnlock()

	c.sendJSON(Envelope{Type: MsgStateSync, Payload: payload})
}

// onPlaylistChanged receives PLAYLIST_CHANGED from one client and re-broadcasts
// it as PLAYLIST_INVALIDATE to all other connected clients.
func (h *Hub) onPlaylistChanged(msg inboundMessage) {
	h.mu.RLock()
	clients := make([]*Client, 0, len(h.clients))
	for _, c := range h.clients {
		if c.ID != msg.client.ID {
			clients = append(clients, c)
		}
	}
	h.mu.RUnlock()

	env := Envelope{Type: MsgPlaylistInvalidate, Payload: msg.envelope.Payload}
	for _, c := range clients {
		c.sendJSON(env)
	}

	log.Printf("playlist changed client=%s, notified %d other client(s)", msg.client.ID, len(clients))
}

// onStarChanged receives STAR_CHANGED from one client and re-broadcasts
// it as STAR_NOTIFY to all other connected clients.
func (h *Hub) onStarChanged(msg inboundMessage) {
	h.mu.RLock()
	clients := make([]*Client, 0, len(h.clients))
	for _, c := range h.clients {
		if c.ID != msg.client.ID {
			clients = append(clients, c)
		}
	}
	h.mu.RUnlock()

	env := Envelope{Type: MsgStarNotify, Payload: msg.envelope.Payload}
	for _, c := range clients {
		c.sendJSON(env)
	}

	log.Printf("star changed client=%s, notified %d other client(s)", msg.client.ID, len(clients))
}

// parsePayloadMap is a small helper to coerce the Payload (which arrives as
// any after JSON unmarshalling) into a string map.
func parsePayloadMap(v any) map[string]string {
	result := make(map[string]string)
	switch m := v.(type) {
	case map[string]any:
		for k, val := range m {
			if s, ok := val.(string); ok {
				result[k] = s
			}
		}
	case map[string]string:
		return m
	}
	return result
}
