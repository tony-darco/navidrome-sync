import XCTest
@testable import navidrome_ios

// MARK: - Mock WebSocket task

/// Captures outbound messages and lets tests drive inbound messages/failures.
final class MockWebSocketTask: WebSocketTask {
    private(set) var resumeCallCount = 0
    private(set) var cancelCount = 0
    private(set) var cancelCloseCode: URLSessionWebSocketTask.CloseCode?
    private(set) var sentMessages: [URLSessionWebSocketTask.Message] = []

    // The receive callback registered by SyncClient's receiveLoop()
    private var receiveHandler: ((Result<URLSessionWebSocketTask.Message, Error>) -> Void)?

    func resume() { resumeCallCount += 1 }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        cancelCount += 1
        cancelCloseCode = closeCode
    }

    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void) {
        sentMessages.append(message)
        completionHandler(nil)
    }

    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        // Store latest handler; SyncClient re-registers after each message
        receiveHandler = completionHandler
    }

    /// Drive a successful incoming message.
    func simulateReceive(_ message: URLSessionWebSocketTask.Message) {
        receiveHandler?(.success(message))
    }

    /// Drive a connection failure.
    func simulateFailure(_ error: Error = URLError(.networkConnectionLost)) {
        receiveHandler?(.failure(error))
    }
}

// MARK: - Mock WebSocket factory

final class MockWebSocketSessionFactory: WebSocketSessionFactory, @unchecked Sendable {
    private(set) var taskCount = 0
    private(set) var lastTask: MockWebSocketTask?
    private(set) var lastURL: URL?
    var onTaskCreated: ((Int) -> Void)?

    func makeTask(url: URL) -> any WebSocketTask {
        lastURL = url
        taskCount += 1
        let task = MockWebSocketTask()
        lastTask = task
        onTaskCreated?(taskCount)
        return task
    }
}

// MARK: - SyncClientTests

final class SyncClientTests: XCTestCase {
    private var factory: MockWebSocketSessionFactory!

    override func setUp() {
        super.setUp()
        factory = MockWebSocketSessionFactory()
    }

    // MARK: - Connection tests

    func testConnectCreatesAndResumesWebSocketTask() {
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.connect(baseURL: "http://localhost:8080", clientId: "client-1")

        XCTAssertEqual(factory.taskCount, 1)
        XCTAssertEqual(factory.lastTask?.resumeCallCount, 1)
    }

    func testConnectBuildsCorrectWebSocketURL() {
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.connect(baseURL: "http://localhost:8080", clientId: "client-abc")

        XCTAssertEqual(factory.lastURL?.absoluteString, "ws://localhost:8080/ws?clientId=client-abc")
    }

    func testConnectConvertsHttpsToWss() {
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.connect(baseURL: "https://example.com", clientId: "c1")

        XCTAssertEqual(factory.lastURL?.scheme, "wss")
        XCTAssertEqual(factory.lastURL?.host, "example.com")
    }

    func testConnectSendsRegisterEnvelopeImmediately() throws {
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.connect(baseURL: "http://localhost:8080", clientId: "reg-test")

        // First sent message must be the REGISTER envelope
        guard let first = factory.lastTask?.sentMessages.first,
              case .string(let json) = first
        else {
            XCTFail("Expected string REGISTER message")
            return
        }
        let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: Data(json.utf8))
        XCTAssertEqual(envelope.type, .register)
        XCTAssertEqual(envelope.clientId, "reg-test")
    }

    // MARK: - Send tests

    func testSendEncodesEnvelopeAsValidJSON() throws {
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.connect(baseURL: "http://localhost:8080", clientId: "c1")

        let outbound = SyncEnvelope(type: .seek, clientId: "c1", payload: nil)
        client.send(outbound)

        // sentMessages[0] = REGISTER, sentMessages[1] = our envelope
        XCTAssertEqual(factory.lastTask?.sentMessages.count, 2)
        guard let second = factory.lastTask?.sentMessages[1],
              case .string(let json) = second
        else {
            XCTFail("Expected second string message")
            return
        }
        let decoded = try JSONDecoder().decode(SyncEnvelope.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.type, .seek)
        XCTAssertEqual(decoded.clientId, "c1")
    }

    func testSendTypeMethodEncodesEnvelope() throws {
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.connect(baseURL: "http://localhost:8080", clientId: "c2")

        client.send(type: .nowPlaying, payload: nil)

        guard let last = factory.lastTask?.sentMessages.last,
              case .string(let json) = last
        else {
            XCTFail("Expected string message from send(type:payload:)")
            return
        }
        let decoded = try JSONDecoder().decode(SyncEnvelope.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.type, .nowPlaying)
    }

    // MARK: - Receive tests

    func testReceiveSuccessFiresOnMessageCallback() {
        let exp = expectation(description: "onMessage called")
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.onMessage = { envelope in
            XCTAssertEqual(envelope.type, .roleChange)
            exp.fulfill()
        }
        client.connect(baseURL: "http://localhost:8080", clientId: "c1")

        let payload = SyncEnvelope(type: .roleChange, clientId: "server", payload: nil)
        let data = try! JSONEncoder().encode(payload)
        factory.lastTask?.simulateReceive(.string(String(data: data, encoding: .utf8)!))

        waitForExpectations(timeout: 1)
    }

    func testReceiveSuccessFiresOnConnectedCallback() {
        let exp = expectation(description: "onConnected called")
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.onConnected = { exp.fulfill() }
        client.connect(baseURL: "http://localhost:8080", clientId: "c1")

        let payload = SyncEnvelope(type: .roleChange, clientId: "server", payload: nil)
        let data = try! JSONEncoder().encode(payload)
        factory.lastTask?.simulateReceive(.string(String(data: data, encoding: .utf8)!))

        waitForExpectations(timeout: 1)
    }

    func testReceiveFailureFiresOnDisconnectedCallback() {
        let exp = expectation(description: "onDisconnected called")
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.onDisconnected = { exp.fulfill() }
        client.connect(baseURL: "http://localhost:8080", clientId: "c1")

        factory.lastTask?.simulateFailure()

        waitForExpectations(timeout: 1)
    }

    func testMalformedIncomingJSONDoesNotCrash() {
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        var messageCount = 0
        client.onMessage = { _ in messageCount += 1 }
        client.connect(baseURL: "http://localhost:8080", clientId: "c1")

        factory.lastTask?.simulateReceive(.string("not valid json {{{"))

        // Drain main queue
        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        waitForExpectations(timeout: 0.5)

        XCTAssertEqual(messageCount, 0, "Malformed JSON must not call onMessage")
    }

    // MARK: - Disconnect tests

    func testDisconnectCancelsTaskWithGoingAway() {
        let client = SyncClient(factory: factory, reconnectDelay: 0)
        client.connect(baseURL: "http://localhost:8080", clientId: "c1")
        client.disconnect()

        XCTAssertEqual(factory.lastTask?.cancelCount, 1)
        XCTAssertEqual(factory.lastTask?.cancelCloseCode, .goingAway)
    }

    func testDisconnectAfterConnectPreventsFurtherReconnects() {
        let client = SyncClient(factory: factory, reconnectDelay: 0.01)
        client.connect(baseURL: "http://localhost:8080", clientId: "c1")
        client.disconnect()

        // Simulate failure after explicit disconnect — should NOT trigger reconnect
        factory.lastTask?.simulateFailure()

        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        waitForExpectations(timeout: 0.5)

        XCTAssertEqual(factory.taskCount, 1, "No reconnect expected after explicit disconnect")
    }

    // MARK: - Reconnect tests

    func testAbnormalCloseTriggersReconnect() {
        let reconnectExp = expectation(description: "second task created")
        factory.onTaskCreated = { count in
            if count == 2 { reconnectExp.fulfill() }
        }

        let client = SyncClient(factory: factory, reconnectDelay: 0.01)
        client.connect(baseURL: "http://localhost:8080", clientId: "c1")

        // Simulate an unexpected network failure (not caused by our disconnect)
        factory.lastTask?.simulateFailure(URLError(.networkConnectionLost))

        waitForExpectations(timeout: 1)
        XCTAssertEqual(factory.taskCount, 2)
    }

    func testReconnectUsesOriginalBaseURLAndClientId() {
        let reconnectExp = expectation(description: "reconnected")
        factory.onTaskCreated = { count in
            if count == 2 { reconnectExp.fulfill() }
        }

        let client = SyncClient(factory: factory, reconnectDelay: 0.01)
        client.connect(baseURL: "http://localhost:8080", clientId: "persistent-id")
        factory.lastTask?.simulateFailure()

        waitForExpectations(timeout: 1)
        XCTAssertTrue(
            factory.lastURL?.absoluteString.contains("persistent-id") == true,
            "Reconnect must reuse the original clientId"
        )
    }

    // MARK: - Envelope serialization (format contract with Go server)

    func testSyncEnvelopeSerializesToExpectedJSONKeys() throws {
        // Verify the wire format matches what the Go server expects
        let envelope = SyncEnvelope(type: .register, clientId: "test-client", payload: nil)
        let data = try JSONEncoder().encode(envelope)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "REGISTER", "MessageType must serialize as SCREAMING_SNAKE_CASE")
        XCTAssertEqual(json?["clientId"] as? String, "test-client")
    }

    func testSyncEnvelopeRoundTripAllMessageTypes() throws {
        let typesToTest: [MessageType] = [
            .register, .nowPlaying, .positionUpdate, .claim, .play, .pause,
            .next, .prev, .seek, .playSong, .loadQueue, .setQueue,
            .setPlaybackOptions, .playlistChanged, .starChanged,
            .stateSync, .command, .roleChange, .error, .playlistInvalidate, .starNotify,
        ]
        for type in typesToTest {
            let envelope = SyncEnvelope(type: type, clientId: "c", payload: nil)
            let data = try JSONEncoder().encode(envelope)
            let decoded = try JSONDecoder().decode(SyncEnvelope.self, from: data)
            XCTAssertEqual(decoded.type, type, "Round-trip failed for \(type.rawValue)")
        }
    }

    func testSyncEnvelopeWithPayloadRoundTrips() throws {
        let payload = JSON.object(["foo": .string("bar"), "n": .number(42)])
        let envelope = SyncEnvelope(type: .stateSync, clientId: "c1", payload: payload)
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(SyncEnvelope.self, from: data)

        XCTAssertEqual(decoded.type, .stateSync)
        if case .object(let obj) = decoded.payload {
            XCTAssertEqual(obj["foo"], .string("bar"))
            XCTAssertEqual(obj["n"], .number(42))
        } else {
            XCTFail("Payload did not round-trip correctly")
        }
    }
}
