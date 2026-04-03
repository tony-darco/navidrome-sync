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

func TestOnlyActiveClientCommand(t *testing.T) {
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
	msgErr := readMessage(t, c2)
	if msgErr.Type != MsgError {
		t.Errorf("expected ERROR, got %s", msgErr.Type)
	}

	sendInboundMsg(h, c1, MsgPlay, nil)
	msgCmd := readMessage(t, c1)
	if msgCmd.Type != MsgCommand {
		t.Errorf("expected COMMAND, got %s", msgCmd.Type)
	}
}

func TestDisconnectActiveClientClearsState(t *testing.T) {
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

	if h.activeClientID != "" {
		t.Errorf("expected no active client, got %s", h.activeClientID)
	}
	if h.state != nil {
		t.Errorf("expected nowPlaying state to be nil, got %v", h.state)
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
