package hub

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
)

func createFakeClient(id, role string) *Client {
	if id == "" {
		id = uuid.NewString()
	}
	return &Client{
		ID:         id,
		ClientType: "web",
		Role:       role,
		send:       make(chan []byte, 20),
	}
}

func readMessage(t *testing.T, c *Client) Envelope {
	t.Helper()
	select {
	case msg := <-c.send:
		var env Envelope
		if err := json.Unmarshal(msg, &env); err != nil {
			t.Fatalf("failed to decode message: %v", err)
		}
		return env
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for an envelope from client")
		return Envelope{}
	}
}

func sendInboundMsg(h *Hub, c *Client, msgType string, payload any) {
	h.incoming <- inboundMessage{
		client: c,
		envelope: Envelope{
			Type:     msgType,
			ClientID: c.ID,
			Payload:  payload,
		},
	}
}

func TestRegisterAssignsFirstClientAsActive(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	h.register <- c1
	msg := readMessage(t, c1)
	if msg.Type != MsgRoleChange {
		t.Fatalf("expected ROLE_CHANGE, got %s", msg.Type)
	}
	msgSync := readMessage(t, c1)
	if msgSync.Type != MsgStateSync {
		t.Fatalf("expected STATE_SYNC, got %s", msgSync.Type)
	}

	h.mu.RLock()
	active := h.activeClientID
	role1 := c1.Role
	h.mu.RUnlock()

	if active != "client-1" {
		t.Errorf("expected client-1 to be active, got %s", active)
	}
	if role1 != "active" {
		t.Errorf("expected client-1 role to be 'active', got %s", role1)
	}

	h.register <- c2
	msgRC2 := readMessage(t, c2)
	if msgRC2.Type != MsgRoleChange {
		t.Fatalf("expected ROLE_CHANGE on c2, got %s", msgRC2.Type)
	}
	msgSync2 := readMessage(t, c2)
	if msgSync2.Type != MsgStateSync {
		t.Errorf("expected STATE_SYNC on c2, got %s", msgSync2.Type)
	}

	h.mu.RLock()
	role2 := c2.Role
	h.mu.RUnlock()
	if role2 != "observer" {
		t.Errorf("expected client-2 role to be 'observer', got %s", role2)
	}
}

func TestClaimTransfersActiveRole(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	h.register <- c1
	readMessage(t, c1) // ROLE_CHANGE
	readMessage(t, c1) // STATE_SYNC

	h.register <- c2
	readMessage(t, c2) // ROLE_CHANGE
	readMessage(t, c2) // STATE_SYNC

	sendInboundMsg(h, c2, MsgClaim, nil)

	// B becomes active: A receives STOP command and ROLE_CHANGE, B receives ROLE_CHANGE
	msgStop := readMessage(t, c1)
	if msgStop.Type != MsgCommand {
		t.Errorf("expected COMMAND, got %s", msgStop.Type)
	}
	payload, _ := msgStop.Payload.(map[string]interface{})
	if payload["action"] != "STOP" {
		t.Errorf("expected STOP command payload, got %v", msgStop.Payload)
	}

	msgRoleChange1 := readMessage(t, c1)
	if msgRoleChange1.Type != MsgRoleChange {
		t.Errorf("expected ROLE_CHANGE, got %s", msgRoleChange1.Type)
	}

	msgRoleChange2 := readMessage(t, c2)
	if msgRoleChange2.Type != MsgRoleChange {
		t.Errorf("expected ROLE_CHANGE, got %s", msgRoleChange2.Type)
	}

	msgStateSync1 := readMessage(t, c1)
	if msgStateSync1.Type != MsgStateSync {
		t.Errorf("expected STATE_SYNC, got %s", msgStateSync1.Type)
	}
	msgStateSync2 := readMessage(t, c2)
	if msgStateSync2.Type != MsgStateSync {
		t.Errorf("expected STATE_SYNC, got %s", msgStateSync2.Type)
	}
}

func TestCommandsForwardedToActiveClient(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	h.register <- c1
	readMessage(t, c1)
	readMessage(t, c1)

	h.register <- c2
	readMessage(t, c2)
	readMessage(t, c2)

	sendInboundMsg(h, c2, MsgPlay, nil)
	msgCmdFromC2 := readMessage(t, c1) // C2 sent play, C1 (active) receives it
	if msgCmdFromC2.Type != MsgCommand {
		t.Errorf("expected COMMAND, got %s", msgCmdFromC2.Type)
	}

	sendInboundMsg(h, c1, MsgPlay, nil)
	msgCmdFromC1 := readMessage(t, c1)
	if msgCmdFromC1.Type != MsgCommand {
		t.Errorf("expected COMMAND, got %s", msgCmdFromC1.Type)
	}
}

func TestDisconnectActiveClientClearsActive(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")

	h.register <- c1
	readMessage(t, c1)
	readMessage(t, c1)

	// Set some state so we can verify it's preserved (but paused)
	sendInboundMsg(h, c1, MsgNowPlaying, map[string]interface{}{
		"songId": "song-1", "title": "Test", "artist": "Artist",
	})
	readMessage(t, c1) // state sync

	h.unregister <- c1
	time.Sleep(50 * time.Millisecond)

	h.mu.RLock()
	defer h.mu.RUnlock()

	// With no remaining clients, activeClientID should be cleared
	if h.activeClientID != "" {
		t.Errorf("expected activeClientID to be empty, got %s", h.activeClientID)
	}
	// Song state should be preserved but paused
	if h.state == nil {
		t.Fatal("expected state to be preserved")
	}
	if h.state.IsPlaying {
		t.Error("expected isPlaying to be false after active client disconnected")
	}
	if h.state.SongID != "song-1" {
		t.Errorf("expected song state to be preserved, got songId=%s", h.state.SongID)
	}
}

func TestNowPlayingUpdatesState(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	h.register <- c1
	readMessage(t, c1)
	readMessage(t, c1)

	h.register <- c2
	readMessage(t, c2)
	readMessage(t, c2)

	sendInboundMsg(h, c1, MsgNowPlaying, map[string]interface{}{"songId": "song-1"})

	msg1 := readMessage(t, c1)
	msg2 := readMessage(t, c2)

	if msg1.Type != MsgStateSync || msg2.Type != MsgStateSync {
		t.Errorf("expected STATE_SYNC broadcast")
	}
}

func TestObserverSendsPlaySongCommand(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	// Register active
	h.register <- c1
	readMessage(t, c1) // ROLE_CHANGE
	readMessage(t, c1) // STATE_SYNC

	// Register observer
	h.register <- c2
	readMessage(t, c2) // ROLE_CHANGE
	readMessage(t, c2) // STATE_SYNC

	// Observer sending PLAY_SONG with payload
	payload := map[string]interface{}{
		"songId": "test-song",
		"index":  float64(5), // JSON maps numbers to float64
	}
	sendInboundMsg(h, c2, MsgPlaySong, payload)

	// Active client (c1) should receive COMMAND with action=PLAY_SONG and the payload merged
	msg := readMessage(t, c1)
	if msg.Type != MsgCommand {
		t.Fatalf("expected COMMAND to be sent to active client, got %s", msg.Type)
	}

	cmdPayload, _ := msg.Payload.(map[string]interface{})
	if cmdPayload["action"] != MsgPlaySong {
		t.Errorf("expected action=PLAY_SONG, got %v", cmdPayload["action"])
	}
	if cmdPayload["songId"] != "test-song" {
		t.Errorf("expected payload songId='test-song', got %v", cmdPayload["songId"])
	}
	if cmdPayload["index"] != float64(5) {
		t.Errorf("expected payload index=5, got %v", cmdPayload["index"])
	}
}

func TestObserverSendsLoadQueueCommand(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	// Register active
	h.register <- c1
	readMessage(t, c1)
	readMessage(t, c1)

	// Register observer
	h.register <- c2
	readMessage(t, c2)
	readMessage(t, c2)

	queuePayload := map[string]interface{}{
		"items": []interface{}{
			map[string]interface{}{"songId": "song-A"},
			map[string]interface{}{"songId": "song-B"},
		},
		"index": float64(0),
	}
	sendInboundMsg(h, c2, MsgLoadQueue, queuePayload)

	msg := readMessage(t, c1)
	if msg.Type != MsgCommand {
		t.Fatalf("expected COMMAND to be sent to active client, got %s", msg.Type)
	}

	cmdPayload, _ := msg.Payload.(map[string]interface{})
	if cmdPayload["action"] != MsgLoadQueue {
		t.Errorf("expected action=LOAD_QUEUE, got %v", cmdPayload["action"])
	}
	if items, ok := cmdPayload["items"].([]interface{}); ok {
		if len(items) != 2 {
			t.Errorf("expected 2 items, got %d", len(items))
		}
	} else {
		t.Errorf("missing or invalid items field in payload: %v", cmdPayload)
	}
}

func TestTransportCommandWithNoActiveClient(t *testing.T) {
	h := NewHub()
	go h.Run()

	c := createFakeClient("client-observer", "observer")
	h.register <- c
	readMessage(t, c)
	readMessage(t, c)

	// In test, since active client isn't fully mocked for c, we must manually unset h.activeClientID
	// or just create a hub where no one is active. Since register assigns first as active, let's clear it.
	h.mu.Lock()
	h.activeClientID = ""
	h.mu.Unlock()

	sendInboundMsg(h, c, MsgPlay, nil)

	msg := readMessage(t, c)
	if msg.Type != MsgError {
		t.Fatalf("expected ERROR message, got %s", msg.Type)
	}

	errPayload, _ := msg.Payload.(map[string]interface{})
	if errPayload["code"] != "NO_ACTIVE_CLIENT" {
		t.Errorf("expected NO_ACTIVE_CLIENT error, got %v", errPayload["code"])
	}
}

func TestNextClientBecomesActiveWhenActiveDisconnects(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	// 1. c1 connects (becomes active)
	h.register <- c1
	msgRole1 := readMessage(t, c1)
	if payload, ok := msgRole1.Payload.(map[string]interface{}); ok && payload["role"] != "active" {
		t.Fatalf("expected c1 to be active, got %s", payload["role"])
	}
	readMessage(t, c1) // state sync

	// 2. c2 connects (becomes observer)
	h.register <- c2
	msgRole2 := readMessage(t, c2)
	if payload, ok := msgRole2.Payload.(map[string]interface{}); ok && payload["role"] != "observer" {
		t.Fatalf("expected c2 to be observer, got %s", payload["role"])
	}
	readMessage(t, c2) // state sync

	// 3. c1 disconnects — c2 should be promoted to active
	h.unregister <- c1
	time.Sleep(50 * time.Millisecond)

	// c2 should receive ROLE_CHANGE (promoted) and STATE_SYNC
	msgPromotion := readMessage(t, c2)
	if msgPromotion.Type != MsgRoleChange {
		t.Fatalf("expected ROLE_CHANGE for promotion, got %s", msgPromotion.Type)
	}
	if payload, ok := msgPromotion.Payload.(map[string]interface{}); ok {
		if payload["role"] != "active" {
			t.Fatalf("expected c2 to be promoted to active, got %s", payload["role"])
		}
	}

	readMessage(t, c2) // state sync broadcast

	h.mu.RLock()
	activeID := h.activeClientID
	c2Role := c2.Role
	h.mu.RUnlock()

	if activeID != "client-2" {
		t.Errorf("expected activeClientID to be client-2, got %s", activeID)
	}
	if c2Role != "active" {
		t.Errorf("expected c2.Role to be active, got %s", c2Role)
	}
}

func TestIsPlayingPausedWhenActiveDisconnects(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	h.register <- c1
	readMessage(t, c1) // role change
	readMessage(t, c1) // state sync

	h.register <- c2
	readMessage(t, c2) // role change
	readMessage(t, c2) // state sync

	// Set a playing state
	sendInboundMsg(h, c1, MsgNowPlaying, map[string]interface{}{
		"songId": "song-1", "title": "Test", "artist": "Artist",
	})
	readMessage(t, c1) // state sync
	readMessage(t, c2) // state sync

	h.mu.RLock()
	if !h.state.IsPlaying {
		t.Fatal("state should be playing after NOW_PLAYING")
	}
	h.mu.RUnlock()

	// Active client disconnects — isPlaying should become false
	h.unregister <- c1
	time.Sleep(50 * time.Millisecond)

	// Drain c2's messages (role change + state sync)
	readMessage(t, c2)
	readMessage(t, c2)

	h.mu.RLock()
	isPlaying := h.state.IsPlaying
	h.mu.RUnlock()

	if isPlaying {
		t.Error("expected isPlaying to be false after active client disconnected")
	}
}

func TestNewClientGetsActiveWhenNoActiveExists(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")

	// c1 connects (active), then disconnects
	h.register <- c1
	readMessage(t, c1)
	readMessage(t, c1)

	h.unregister <- c1
	time.Sleep(50 * time.Millisecond)

	// No clients left. c2 connects — should become active
	c2 := createFakeClient("client-2", "")
	h.register <- c2
	msgRole := readMessage(t, c2)
	if payload, ok := msgRole.Payload.(map[string]interface{}); ok && payload["role"] != "active" {
		t.Fatalf("expected c2 to be active, got %s", payload["role"])
	}
}

func TestActiveClientReconnects(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")

	// 1. c1 connects (becomes active)
	h.register <- c1
	readMessage(t, c1) // role change
	readMessage(t, c1) // state sync

	// 2. c1 disconnects
	h.unregister <- c1
	time.Sleep(50 * time.Millisecond)

	// 3. c1 reconnects. it should reclaim active.
	c1Reconnected := createFakeClient("client-1", "")
	h.register <- c1Reconnected

	msgRole := readMessage(t, c1Reconnected)
	if payload, ok := msgRole.Payload.(map[string]interface{}); ok && payload["role"] != "active" {
		t.Fatalf("expected reconnected c1 to be active, got %s", payload["role"])
	}
}

func TestPositionUpdateBroadcastsToObservers(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	h.register <- c1
	readMessage(t, c1) // ROLE_CHANGE
	readMessage(t, c1) // STATE_SYNC

	h.register <- c2
	readMessage(t, c2) // ROLE_CHANGE
	readMessage(t, c2) // STATE_SYNC

	// Set some song state first
	sendInboundMsg(h, c1, MsgNowPlaying, map[string]interface{}{
		"songId": "song-1", "title": "Test", "artist": "Artist", "durationSecs": float64(300),
	})
	readMessage(t, c1) // STATE_SYNC
	readMessage(t, c2) // STATE_SYNC

	// Active client sends a position update
	sendInboundMsg(h, c1, MsgPositionUpdate, map[string]interface{}{
		"positionSecs": float64(42.5),
	})

	// Observer (c2) should receive a POSITION_UPDATE message
	msg := readMessage(t, c2)
	if msg.Type != MsgPositionUpdate {
		t.Fatalf("expected POSITION_UPDATE, got %s", msg.Type)
	}
	payload, ok := msg.Payload.(map[string]interface{})
	if !ok {
		t.Fatal("expected map payload")
	}
	if payload["positionSecs"] != float64(42.5) {
		t.Errorf("expected positionSecs=42.5, got %v", payload["positionSecs"])
	}

	// Verify hub state was also updated
	h.mu.RLock()
	pos := h.state.PositionSecs
	h.mu.RUnlock()
	if pos != 42.5 {
		t.Errorf("expected hub state position=42.5, got %f", pos)
	}
}

func TestSeekUpdatesHubStateAndBroadcasts(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")
	c2 := createFakeClient("client-2", "")

	h.register <- c1
	readMessage(t, c1) // ROLE_CHANGE
	readMessage(t, c1) // STATE_SYNC

	h.register <- c2
	readMessage(t, c2) // ROLE_CHANGE
	readMessage(t, c2) // STATE_SYNC

	// Set song state
	sendInboundMsg(h, c1, MsgNowPlaying, map[string]interface{}{
		"songId": "song-1", "title": "Test", "artist": "Artist", "durationSecs": float64(300),
	})
	readMessage(t, c1) // STATE_SYNC
	readMessage(t, c2) // STATE_SYNC

	// Observer sends SEEK — should be forwarded to active, state updated, and position broadcast
	sendInboundMsg(h, c2, MsgSeek, map[string]interface{}{
		"positionSecs": float64(120.0),
	})

	// Active client (c1) should receive a COMMAND with action=SEEK
	cmdMsg := readMessage(t, c1)
	if cmdMsg.Type != MsgCommand {
		t.Fatalf("expected COMMAND, got %s", cmdMsg.Type)
	}
	cmdPayload, _ := cmdMsg.Payload.(map[string]interface{})
	if cmdPayload["action"] != "SEEK" {
		t.Errorf("expected action=SEEK, got %v", cmdPayload["action"])
	}
	if cmdPayload["positionSecs"] != float64(120.0) {
		t.Errorf("expected positionSecs=120, got %v", cmdPayload["positionSecs"])
	}

	// Observer (c2) should receive a POSITION_UPDATE with the new position
	posMsg := readMessage(t, c2)
	if posMsg.Type != MsgPositionUpdate {
		t.Fatalf("expected POSITION_UPDATE, got %s", posMsg.Type)
	}
	posPayload, _ := posMsg.Payload.(map[string]interface{})
	if posPayload["positionSecs"] != float64(120.0) {
		t.Errorf("expected positionSecs=120, got %v", posPayload["positionSecs"])
	}

	// Verify hub state was updated
	h.mu.RLock()
	pos := h.state.PositionSecs
	h.mu.RUnlock()
	if pos != 120.0 {
		t.Errorf("expected hub state position=120, got %f", pos)
	}
}
