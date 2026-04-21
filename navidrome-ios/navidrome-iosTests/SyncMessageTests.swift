import Testing
import Foundation
@testable import navidrome_ios

// MARK: - MessageType

@Suite("MessageType Enum")
struct MessageTypeTests {

    @Test("All 16 message types decode from raw strings")
    func decodeAllTypes() throws {
        let cases: [(String, MessageType)] = [
            ("REGISTER", .register),
            ("NOW_PLAYING", .nowPlaying),
            ("POSITION_UPDATE", .positionUpdate),
            ("CLAIM", .claim),
            ("PLAY", .play),
            ("PAUSE", .pause),
            ("NEXT", .next),
            ("PREV", .prev),
            ("SEEK", .seek),
            ("PLAY_SONG", .playSong),
            ("LOAD_QUEUE", .loadQueue),
            ("SET_QUEUE", .setQueue),
            ("SET_PLAYBACK_OPTIONS", .setPlaybackOptions),
            ("PLAYLIST_CHANGED", .playlistChanged),
            ("STAR_CHANGED", .starChanged),
            ("STATE_SYNC", .stateSync),
            ("COMMAND", .command),
            ("ROLE_CHANGE", .roleChange),
            ("ERROR", .error),
            ("PLAYLIST_INVALIDATE", .playlistInvalidate),
            ("STAR_NOTIFY", .starNotify),
        ]
        for (raw, expected) in cases {
            let json = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(MessageType.self, from: json)
            #expect(decoded == expected, "Expected \(raw) to decode to \(expected)")
        }
    }

    @Test("MessageType encode → decode round-trip")
    func roundTrip() throws {
        for mt in [MessageType.stateSync, .command, .roleChange, .error, .register, .starChanged] {
            let data = try JSONEncoder().encode(mt)
            let decoded = try JSONDecoder().decode(MessageType.self, from: data)
            #expect(decoded == mt)
        }
    }
}

// MARK: - SyncEnvelope

@Suite("SyncEnvelope")
struct SyncEnvelopeTests {

    @Test("Decode STATE_SYNC envelope from fixture")
    func decodeStateSyncFixture() throws {
        let data = try loadFixtureData("sync_envelope_state_sync")
        let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: data)

        #expect(envelope.type == .stateSync)
        #expect(envelope.clientId == nil)
        #expect(envelope.payload != nil)
    }

    @Test("Decode COMMAND envelope from fixture")
    func decodeCommandFixture() throws {
        let data = try loadFixtureData("sync_envelope_command")
        let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: data)

        #expect(envelope.type == .command)
        let cmd = try #require(envelope.payload?.decode(CommandPayload.self))
        #expect(cmd.action == "SEEK")
        #expect(cmd.positionSecs == 120.5)
    }

    @Test("Decode NOW_PLAYING envelope with clientId from fixture")
    func decodeNowPlayingFixture() throws {
        let data = try loadFixtureData("sync_envelope_now_playing")
        let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: data)

        #expect(envelope.type == .nowPlaying)
        #expect(envelope.clientId == "client-abc")
        let np = try #require(envelope.payload?.decode(NowPlayingPayload.self))
        #expect(np.songId == "s-001")
        #expect(np.durationSecs == 245)
    }

    @Test("Envelope encode → decode round-trip")
    func roundTrip() throws {
        let original = SyncEnvelope(
            type: .register,
            clientId: "test-client",
            payload: .object(["clientType": .string("ios")])
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SyncEnvelope.self, from: data)

        #expect(decoded.type == original.type)
        #expect(decoded.clientId == original.clientId)
    }

    @Test("Envelope without payload decodes")
    func envelopeNoPayload() throws {
        let json = """
        {"type": "PAUSE"}
        """.data(using: .utf8)!
        let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: json)

        #expect(envelope.type == .pause)
        #expect(envelope.clientId == nil)
        #expect(envelope.payload == nil)
    }
}

// MARK: - StateSyncPayload

@Suite("StateSyncPayload")
struct StateSyncPayloadTests {

    @Test("Decode STATE_SYNC payload from fixture via JSON.decode()")
    func decodeViaJSON() throws {
        let data = try loadFixtureData("sync_envelope_state_sync")
        let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: data)
        let payload = try #require(envelope.payload?.decode(StateSyncPayload.self))

        #expect(payload.activeClientId == "client-abc")
        #expect(payload.clients.count == 2)
        #expect(payload.shuffle == false)
        #expect(payload.repeatMode == "off")

        let song = try #require(payload.song)
        #expect(song.songId == "s-001")
        #expect(song.positionSecs == 42.5)

        let queue = try #require(payload.queue)
        #expect(queue.count == 2)
        #expect(queue[0].songId == "s-001")
        #expect(queue[1].songId == "s-002")
    }
}

// MARK: - QueueItemPayload

@Suite("QueueItemPayload")
struct QueueItemPayloadTests {

    @Test("toNowPlayingSong() converts correctly")
    func toNowPlayingSong() {
        let item = QueueItemPayload(
            songId: "s-1", title: "Test", artist: "Art",
            album: "Alb", albumId: "al-1", artistId: "ar-1",
            coverArtId: "ca-1", durationSecs: 200
        )
        let nps = item.toNowPlayingSong()

        #expect(nps.songId == "s-1")
        #expect(nps.title == "Test")
        #expect(nps.durationSecs == 200)
        #expect(nps.positionSecs == 0)
    }
}

// MARK: - JSON Enum

@Suite("JSON Recursive Enum")
struct JSONTests {

    // --- Basic type round-trips ---

    @Test("String round-trip")
    func stringRoundTrip() throws {
        let json = JSON.string("hello")
        let data = try JSONEncoder().encode(json)
        let decoded = try JSONDecoder().decode(JSON.self, from: data)

        if case .string(let s) = decoded {
            #expect(s == "hello")
        } else {
            Issue.record("Expected .string, got \(decoded)")
        }
    }

    @Test("Number round-trip")
    func numberRoundTrip() throws {
        let json = JSON.number(42.5)
        let data = try JSONEncoder().encode(json)
        let decoded = try JSONDecoder().decode(JSON.self, from: data)

        if case .number(let n) = decoded {
            #expect(n == 42.5)
        } else {
            Issue.record("Expected .number, got \(decoded)")
        }
    }

    @Test("Bool round-trip")
    func boolRoundTrip() throws {
        for val in [true, false] {
            let json = JSON.bool(val)
            let data = try JSONEncoder().encode(json)
            let decoded = try JSONDecoder().decode(JSON.self, from: data)

            if case .bool(let b) = decoded {
                #expect(b == val)
            } else {
                Issue.record("Expected .bool(\(val)), got \(decoded)")
            }
        }
    }

    @Test("Null round-trip")
    func nullRoundTrip() throws {
        let json = JSON.null
        let data = try JSONEncoder().encode(json)
        let decoded = try JSONDecoder().decode(JSON.self, from: data)

        if case .null = decoded {
            // OK
        } else {
            Issue.record("Expected .null, got \(decoded)")
        }
    }

    // --- Edge cases ---

    @Test("Deeply nested object (5+ levels)")
    func deepNesting() throws {
        let level5 = JSON.object(["value": .string("deep")])
        let level4 = JSON.object(["l5": level5])
        let level3 = JSON.object(["l4": level4])
        let level2 = JSON.object(["l3": level3])
        let level1 = JSON.object(["l2": level2])
        let root = JSON.object(["l1": level1])

        let data = try JSONEncoder().encode(root)
        let decoded = try JSONDecoder().decode(JSON.self, from: data)

        // Navigate to the deepest value
        guard case .object(let d1) = decoded,
              case .object(let d2) = d1["l1"],
              case .object(let d3) = d2["l2"],
              case .object(let d4) = d3["l3"],
              case .object(let d5) = d4["l4"],
              case .object(let d6) = d5["l5"],
              case .string(let val) = d6["value"] else {
            Issue.record("Deep nesting navigation failed")
            return
        }
        #expect(val == "deep")
    }

    @Test("Array of mixed types")
    func mixedArray() throws {
        let json = JSON.array([
            .number(1),
            .string("two"),
            .bool(true),
            .null
        ])
        let data = try JSONEncoder().encode(json)
        let decoded = try JSONDecoder().decode(JSON.self, from: data)

        guard case .array(let arr) = decoded else {
            Issue.record("Expected .array, got \(decoded)")
            return
        }
        #expect(arr.count == 4)

        if case .number(let n) = arr[0] { #expect(n == 1.0) }
        else { Issue.record("arr[0] should be number") }

        if case .string(let s) = arr[1] { #expect(s == "two") }
        else { Issue.record("arr[1] should be string") }

        if case .bool(let b) = arr[2] { #expect(b == true) }
        else { Issue.record("arr[2] should be bool") }

        if case .null = arr[3] { /* OK */ }
        else { Issue.record("arr[3] should be null") }
    }

    @Test("Large 64-bit integer preserves precision")
    func largeInteger() throws {
        // 2^53 - 1 is the max safe integer for Double
        let maxSafe: Double = 9007199254740991
        let json = JSON.number(maxSafe)
        let data = try JSONEncoder().encode(json)
        let decoded = try JSONDecoder().decode(JSON.self, from: data)

        if case .number(let n) = decoded {
            #expect(n == maxSafe)
        } else {
            Issue.record("Expected .number, got \(decoded)")
        }
    }

    @Test("Empty object and empty array")
    func emptyContainers() throws {
        let emptyObj = JSON.object([:])
        let emptyArr = JSON.array([])

        let objData = try JSONEncoder().encode(emptyObj)
        let arrData = try JSONEncoder().encode(emptyArr)

        let decodedObj = try JSONDecoder().decode(JSON.self, from: objData)
        let decodedArr = try JSONDecoder().decode(JSON.self, from: arrData)

        if case .object(let o) = decodedObj { #expect(o.isEmpty) }
        else { Issue.record("Expected empty object") }

        if case .array(let a) = decodedArr { #expect(a.isEmpty) }
        else { Issue.record("Expected empty array") }
    }

    // --- JSON.decode<T>() ---

    @Test("decode() into concrete Codable type succeeds")
    func decodeToConcreteType() throws {
        let json = JSON.object([
            "clientType": .string("ios")
        ])
        let payload = json.decode(RegisterPayload.self)

        let result = try #require(payload)
        #expect(result.clientType == "ios")
    }

    @Test("decode() with mismatched type returns nil")
    func decodeToWrongType() {
        let json = JSON.string("not an object")
        let result = json.decode(RegisterPayload.self)
        #expect(result == nil)
    }

    @Test("decode() CommandPayload from JSON object")
    func decodeCommandPayload() throws {
        let json = JSON.object([
            "action": .string("SEEK"),
            "positionSecs": .number(99.5)
        ])
        let cmd = try #require(json.decode(CommandPayload.self))
        #expect(cmd.action == "SEEK")
        #expect(cmd.positionSecs == 99.5)
    }
}

// MARK: - Fixture helper (shared)

private func loadFixtureData(_ name: String) throws -> Data {
    let fileName = name.hasSuffix(".json") ? String(name.dropLast(5)) : name
    if let url = Bundle(for: _FixtureBundleAnchor.self).url(forResource: fileName, withExtension: "json", subdirectory: "TestFixtures") {
        return try Data(contentsOf: url)
    }
    let thisFile = URL(fileURLWithPath: #filePath)
    let fixtureURL = thisFile
        .deletingLastPathComponent()
        .appendingPathComponent("TestFixtures")
        .appendingPathComponent("\(fileName).json")
    return try Data(contentsOf: fixtureURL)
}

private final class _FixtureBundleAnchor {}
