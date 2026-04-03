package hub

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait  = 10 * time.Second
	pongWait   = 60 * time.Second
	pingPeriod = (pongWait * 9) / 10
	maxMsgSize = 1048576 // 1MB to handle large playlists/queues
)

type Client struct {
	ID         string `json:"clientId"`
	ClientType string `json:"clientType"` // "ios" or "web"
	Role       string `json:"role"`       // "active" or "observer"

	hub  *Hub
	conn *websocket.Conn
	send chan []byte
	once sync.Once
}

// readPump reads messages from the WebSocket and forwards them to the hub.
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	c.conn.SetReadLimit(maxMsgSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Printf("ws read error client=%s: %v", c.ID, err)
			}
			break
		}
		var env Envelope
		if err := json.Unmarshal(message, &env); err != nil {
			c.sendError("INVALID_JSON", "malformed message")
			continue
		}
		// For REGISTER messages, preserve the client-provided clientId
		// so the hub can adopt it. For all others, use the server-assigned ID.
		if env.Type != MsgRegister {
			env.ClientID = c.ID
		}
		c.hub.incoming <- inboundMessage{client: c, envelope: env}
	}
}

// writePump pumps messages from the hub to the WebSocket connection.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case msg, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// sendJSON marshals v and queues it for delivery.
func (c *Client) sendJSON(v any) {
	data, err := json.Marshal(v)
	if err != nil {
		log.Printf("marshal error: %v", err)
		return
	}
	select {
	case c.send <- data:
	default:
		// Client too slow; drop the message to avoid blocking the hub.
		log.Printf("dropping message for slow client %s", c.ID)
	}
}

func (c *Client) sendError(code, message string) {
	c.sendJSON(Envelope{
		Type: "ERROR",
		Payload: map[string]string{
			"code":    code,
			"message": message,
		},
	})
}
