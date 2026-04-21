import Foundation
@testable import navidrome_ios

final class MockSyncClient: SyncClientProtocol, @unchecked Sendable {
    var onMessage: (@Sendable (SyncEnvelope) -> Void)?
    var onConnected: (@Sendable () -> Void)?
    var onDisconnected: (@Sendable () -> Void)?

    private(set) var connectCalls: [(baseURL: String, clientId: String)] = []
    private(set) var disconnectCallCount = 0
    private(set) var sentEnvelopes: [SyncEnvelope] = []

    func connect(baseURL: String, clientId: String) {
        connectCalls.append((baseURL: baseURL, clientId: clientId))
        onConnected?()
    }

    func disconnect() {
        disconnectCallCount += 1
        onDisconnected?()
    }

    func send(_ envelope: SyncEnvelope) {
        sentEnvelopes.append(envelope)
    }

    func send(type: MessageType, payload: (any Encodable)?) {
        let jsonPayload: JSON?
        if let payload {
            jsonPayload = try? JSONEncoder().encode(AnyEncodable(payload)).jsonValueForTests()
        } else {
            jsonPayload = .object([:])
        }
        sentEnvelopes.append(SyncEnvelope(type: type, clientId: nil, payload: jsonPayload))
    }

    func simulateIncoming(_ envelope: SyncEnvelope) {
        onMessage?(envelope)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        encodeBlock = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}

private extension Data {
    func jsonValueForTests() throws -> JSON {
        try JSONDecoder().decode(JSON.self, from: self)
    }
}
