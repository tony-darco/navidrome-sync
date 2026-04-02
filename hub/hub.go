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
	MsgRegister       = "REGISTER"
	MsgNowPlaying     = "NOW_PLAYING"
	MsgPositionUpdate = "POSITION_UPDATE"
	MsgClaim          = "CLAIM"
	MsgPlay           = "PLAY"
	MsgPause          = "PAUSE"
	MsgNext           = "NEXT"
	MsgPrev           = "PREV"
	MsgSeek           = "SEEK"

	// Outbound
	MsgStateSync  = "STATE_SYNC"
	MsgCommand    = "COMMAND"
	MsgRoleChange = "ROLE_CHANGE"
	MsgError      = "ERROR"
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

// Hub maintains connected clients and the shared playback state.
type Hub struct {
	mu             sync.RWMutex
	clients        map[string]*Client
	activeClientID string
	state          *NowPlayingState

	register   chan *Client
	unregister chan *Client
	incoming   chan inboundMessage
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[string]*Client),
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
		h.state = &NowPlayingState{
			SongID:       entry.SongID,
			Title:        entry.Title,
			Artist:       entry.Artist,
			Album:        entry.Album,
			CoverArtID:   entry.CoverArtID,
			DurationSecs: entry.DurationSecs,
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
	c := &Client{
		ID:   uuid.New().String(),
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
	h.clients[c.ID] = c
	// First client becomes active; subsequent ones are observers.
	if h.activeClientID == "" {
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
	if _, ok := h.clients[c.ID]; !ok {
		h.mu.Unlock()
		return
	}
	delete(h.clients, c.ID)
	close(c.send)

	// If the active client disconnected, clear active state.
	wasActive := h.activeClientID == c.ID
	if wasActive {
		h.activeClientID = ""
	}
	h.mu.Unlock()

	log.Printf("client disconnected id=%s wasActive=%v", c.ID, wasActive)

	if wasActive {
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
	case MsgPlay, MsgPause, MsgNext, MsgPrev, MsgSeek:
		h.onTransportCommand(msg)
	default:
		msg.client.sendError("UNKNOWN_TYPE", "unrecognized message type: "+msg.envelope.Type)
	}
}

// onRegisterMsg handles an explicit REGISTER message that carries clientType.
func (h *Hub) onRegisterMsg(msg inboundMessage) {
	payload := parsePayloadMap(msg.envelope.Payload)
	h.mu.Lock()
	msg.client.ClientType = payload["clientType"]
	h.mu.Unlock()
	log.Printf("client set type id=%s type=%s", msg.client.ID, msg.client.ClientType)
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

	h.mu.Lock()
	h.state = &np
	h.mu.Unlock()

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

	// Notify the displaced client of its new role.
	if prevClient != nil && prevClient.ID != msg.client.ID {
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

// onTransportCommand handles PLAY, PAUSE, NEXT, PREV, SEEK.
// Only the active client may issue these; they are forwarded as COMMAND messages.
func (h *Hub) onTransportCommand(msg inboundMessage) {
	h.mu.RLock()
	activeID := h.activeClientID
	activeClient := h.clients[activeID]
	h.mu.RUnlock()

	if msg.client.ID != activeID {
		msg.client.sendError("NOT_ACTIVE", "only the active client may send transport commands")
		return
	}

	if activeClient == nil {
		return
	}

	// Extract positionSecs from SEEK payload, nil for other commands.
	var positionSecs any
	if msg.envelope.Type == MsgSeek {
		if pm, ok := msg.envelope.Payload.(map[string]any); ok {
			positionSecs = pm["positionSecs"]
		}
	}

	activeClient.sendJSON(Envelope{
		Type: MsgCommand,
		Payload: map[string]any{
			"action":       msg.envelope.Type,
			"positionSecs": positionSecs,
		},
	})
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
