import Foundation

/// Manages the WebSocket connection to the Go sync service.
/// Uses native URLSessionWebSocketTask — no third-party dependencies.
nonisolated final class SyncClient: SyncClientProtocol, @unchecked Sendable {
    private var webSocket: (any WebSocketTask)?
    private let factory: WebSocketSessionFactory
    let reconnectDelay: TimeInterval
    private var shouldReconnect = false
    private var clientId: String = ""
    private var baseURL: String = ""

    init(factory: WebSocketSessionFactory = LiveWebSocketSessionFactory(), reconnectDelay: TimeInterval = 2.0) {
        self.factory = factory
        self.reconnectDelay = reconnectDelay
    }

    var onMessage: (@Sendable (SyncEnvelope) -> Void)?
    var onConnected: (@Sendable () -> Void)?
    var onDisconnected: (@Sendable () -> Void)?

    // MARK: - Connection

    func connect(baseURL: String, clientId: String) {
        self.baseURL = baseURL
        self.clientId = clientId
        shouldReconnect = true
        openSocket()
    }

    func disconnect() {
        shouldReconnect = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    private func openSocket() {
        // Build ws:// or wss:// URL from the HTTP base URL
        var urlString = baseURL.replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        urlString += "/ws?clientId=\(clientId)"

        guard let url = URL(string: urlString) else { return }

        let task = factory.makeTask(url: url)
        webSocket = task
        task.resume()

        // Send REGISTER once the socket is ready, then start listening
        sendRegister()
        receiveLoop()
    }

    private func sendRegister() {
        let envelope = SyncEnvelope(
            type: .register,
            clientId: clientId,
            payload: try? JSONEncoder().encode(RegisterPayload(clientType: "ios"))
                .jsonValue()
        )
        send(envelope)
    }

    // MARK: - Send

    func send(_ envelope: SyncEnvelope) {
        guard let data = try? JSONEncoder().encode(envelope),
              let string = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(string)) { error in
            if let error {
                print("[ws] send error: \(error.localizedDescription)")
            }
        }
    }

    func send(type: MessageType, payload: (any Encodable)? = nil) {
        let jsonPayload: JSON?
        if let payload {
            jsonPayload = try? JSONEncoder().encode(payload).jsonValue()
        } else {
            jsonPayload = .object([:])
        }
        let envelope = SyncEnvelope(type: type, clientId: clientId, payload: jsonPayload)
        send(envelope)
    }

    // MARK: - Receive

    private func receiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                // Mark connected on first successful receive
                DispatchQueue.main.async {
                    self.onConnected?()
                }
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let envelope = try? JSONDecoder().decode(SyncEnvelope.self, from: data) {
                        DispatchQueue.main.async {
                            self.onMessage?(envelope)
                        }
                    }
                case .data(let data):
                    if let envelope = try? JSONDecoder().decode(SyncEnvelope.self, from: data) {
                        DispatchQueue.main.async {
                            self.onMessage?(envelope)
                        }
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self.receiveLoop()

            case .failure:
                DispatchQueue.main.async {
                    self.onDisconnected?()
                }
                self.scheduleReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }
        webSocket = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self, self.shouldReconnect else { return }
            self.openSocket()
        }
    }
}

// MARK: - Data → JSON helper

private extension Data {
    nonisolated func jsonValue() throws -> JSON {
        try JSONDecoder().decode(JSON.self, from: self)
    }
}
