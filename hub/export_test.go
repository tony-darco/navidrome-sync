package hub

// These are exported solely for testing from other packages.

func (h *Hub) RegisterTestClient(c *Client) {
	h.register <- c
}

func (h *Hub) UnregisterTestClient(c *Client) {
	h.unregister <- c
}

func (h *Hub) SendTestIncoming(c *Client, msgType string, payload any) {
	h.incoming <- inboundMessage{
		client:   c,
		envelope: Envelope{Type: msgType, ClientID: c.ID, Payload: payload},
	}
}

func NewTestClient(id, role string, send chan []byte) *Client {
	return &Client{
		ID:         id,
		ClientType: "test",
		Role:       role,
		send:       send,
	}
}
