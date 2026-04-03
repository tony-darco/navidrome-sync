package e2e

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"navidrome-sync/hub"
)

func connectWS(t *testing.T, url string) (*websocket.Conn, chan hub.Envelope) {
	t.Helper()
	wsURL := strings.Replace(url, "http://", "ws://", 1)

	conn, resp, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		if resp != nil {
			t.Fatalf("dial failed: %v, status: %v", err, resp.StatusCode)
		}
		t.Fatalf("dial failed: %v", err)
	}

	recv := make(chan hub.Envelope, 100)
	go func() {
		for {
			_, msg, err := conn.ReadMessage()
			if err != nil {
				return
			}
			var env hub.Envelope
			if err := json.Unmarshal(msg, &env); err == nil {
				// Added logging
				// fmt.Printf("Client Recv -> %s\n", env.Type)
				recv <- env
			}
		}
	}()

	// consume initial connection messages
	readEnv(t, recv) // ROLE_CHANGE
	readEnv(t, recv) // STATE_SYNC

	return conn, recv
}

func readEnv(t *testing.T, ch chan hub.Envelope) hub.Envelope {
	t.Helper()
	select {
	case env := <-ch:
		return env
	case <-time.After(2 * time.Second):
		t.Fatal("timeout waiting for websocket message")
		return hub.Envelope{}
	}
}

func createTestServer() (*hub.Hub, *httptest.Server) {
	h := hub.NewHub()
	go h.Run()
	ts := httptest.NewServer(http.HandlerFunc(h.HandleWS))
	return h, ts
}

func TestFullMultiClientSyncFlow(t *testing.T) {
	_, ts := createTestServer()
	defer ts.Close()

	connA, recvA := connectWS(t, ts.URL)
	defer connA.Close()
	connA.WriteJSON(hub.Envelope{Type: hub.MsgRegister, ClientID: "clientA"})
	envA1 := readEnv(t, recvA)
	if envA1.Type != hub.MsgStateSync {
		t.Fatal(envA1.Type)
	}

	connB, recvB := connectWS(t, ts.URL)
	defer connB.Close()
	connB.WriteJSON(hub.Envelope{Type: hub.MsgRegister, ClientID: "clientB"})
	envB1 := readEnv(t, recvB)
	if envB1.Type != hub.MsgStateSync {
		t.Fatal(envB1.Type)
	}
	envAFromB := readEnv(t, recvA)
	if envAFromB.Type != hub.MsgStateSync {
		t.Fatal(envAFromB.Type)
	}

	connA.WriteJSON(hub.Envelope{
		Type:    hub.MsgNowPlaying,
		Payload: map[string]interface{}{"songId": "song1"},
	})

	envB3 := readEnv(t, recvB)
	if envB3.Type != hub.MsgStateSync {
		t.Fatal(envB3.Type)
	}
	envA3 := readEnv(t, recvA)
	if envA3.Type != hub.MsgStateSync {
		t.Fatal(envA3.Type)
	}

	connB.WriteJSON(hub.Envelope{Type: hub.MsgClaim})

	msgActionA := readEnv(t, recvA)
	if msgActionA.Type != hub.MsgCommand {
		t.Fatal(msgActionA.Type)
	}
	msgRoleA := readEnv(t, recvA)
	if msgRoleA.Type != hub.MsgRoleChange {
		t.Fatal(msgRoleA.Type)
	}

	msgRoleB := readEnv(t, recvB)
	if msgRoleB.Type != hub.MsgRoleChange {
		t.Fatal(msgRoleB.Type)
	}

	msgSyncA := readEnv(t, recvA)
	if msgSyncA.Type != hub.MsgStateSync {
		t.Fatal(msgSyncA.Type)
	}
	msgSyncB := readEnv(t, recvB)
	if msgSyncB.Type != hub.MsgStateSync {
		t.Fatal(msgSyncB.Type)
	}
}

func TestCommandForwarding(t *testing.T) {
	_, ts := createTestServer()
	defer ts.Close()

	connA, recvA := connectWS(t, ts.URL)
	defer connA.Close()
	connA.WriteJSON(hub.Envelope{Type: hub.MsgRegister, ClientID: "clientA"})
	readEnv(t, recvA)

	connB, recvB := connectWS(t, ts.URL)
	defer connB.Close()
	connB.WriteJSON(hub.Envelope{Type: hub.MsgRegister, ClientID: "clientB"})
	readEnv(t, recvB)
	readEnv(t, recvA)

	connB.WriteJSON(hub.Envelope{Type: hub.MsgPlay})
	errResp := readEnv(t, recvB)
	if errResp.Type != hub.MsgError {
		t.Fatal(errResp.Type)
	}

	connA.WriteJSON(hub.Envelope{Type: hub.MsgPlay})
	msgCmdA := readEnv(t, recvA)
	if msgCmdA.Type != hub.MsgCommand {
		t.Fatal(msgCmdA.Type)
	}
}

func TestActiveClientDisconnect(t *testing.T) {
	_, ts := createTestServer()
	defer ts.Close()

	connA, recvA := connectWS(t, ts.URL)
	connA.WriteJSON(hub.Envelope{Type: hub.MsgRegister, ClientID: "clientA"})
	readEnv(t, recvA)

	connB, recvB := connectWS(t, ts.URL)
	defer connB.Close()
	connB.WriteJSON(hub.Envelope{Type: hub.MsgRegister, ClientID: "clientB"})
	readEnv(t, recvB)
	readEnv(t, recvA)

	connA.Close()

	msgSyncB := readEnv(t, recvB)
	if msgSyncB.Type != hub.MsgStateSync {
		t.Fatal(msgSyncB.Type)
	}
}

func TestReconnectBehavior(t *testing.T) {
	_, ts := createTestServer()
	defer ts.Close()

	connA, recvA := connectWS(t, ts.URL)
	connA.WriteJSON(hub.Envelope{Type: hub.MsgRegister, ClientID: "clientA"})
	readEnv(t, recvA)

	connA.Close()
	time.Sleep(50 * time.Millisecond)

	connA2, recvA2 := connectWS(t, ts.URL)
	defer connA2.Close()
	connA2.WriteJSON(hub.Envelope{Type: hub.MsgRegister, ClientID: "clientA"})

	msgSync := readEnv(t, recvA2)
	if msgSync.Type != hub.MsgStateSync {
		t.Fatal(msgSync.Type)
	}
}
