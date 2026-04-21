import Foundation
import UIKit

nonisolated protocol NavidromeClientProtocol: Sendable {
    func star(id: String) async throws
    func unstar(id: String) async throws
    func scrobble(songId: String) async throws
    func fetchCoverArt(id: String, size: Int) async -> UIImage?
    nonisolated func streamURL(songId: String) -> URL?
}

nonisolated protocol SyncClientProtocol: AnyObject, Sendable {
    var onMessage: (@Sendable (SyncEnvelope) -> Void)? { get set }
    var onConnected: (@Sendable () -> Void)? { get set }
    var onDisconnected: (@Sendable () -> Void)? { get set }

    func connect(baseURL: String, clientId: String)
    func disconnect()
    func send(_ envelope: SyncEnvelope)
    func send(type: MessageType, payload: (any Encodable)?)
}

// MARK: - WebSocket task abstraction (enables SyncClient unit testing)

nonisolated protocol WebSocketTask: AnyObject {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void)
    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void)
}

extension URLSessionWebSocketTask: WebSocketTask {}

nonisolated protocol WebSocketSessionFactory: AnyObject, Sendable {
    func makeTask(url: URL) -> any WebSocketTask
}

nonisolated final class LiveWebSocketSessionFactory: WebSocketSessionFactory {
    func makeTask(url: URL) -> any WebSocketTask {
        URLSession(configuration: .default).webSocketTask(with: url)
    }
}
