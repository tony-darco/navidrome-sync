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

func TestDisconnectActiveClientKeepsState(t *testing.T) {
	h := NewHub()
	go h.Run()

	c1 := createFakeClient("client-1", "")

	h.register <- c1
	readMessage(t, c1)
	readMessage(t, c1)

	h.unregister <- c1
	time.Sleep(50 * time.Millisecond)

	h.mu.RLock()
	defer h.mu.RUnlock()

	if h.activeClientID != "client-1" {
		t.Errorf("expected active client client-1, got %s", h.activeClientID)
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
