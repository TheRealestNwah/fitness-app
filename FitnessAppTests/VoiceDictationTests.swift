import XCTest
@testable import FitnessApp

final class VoiceDictationTests: XCTestCase {
    func testRecognitionFailureIsVisibleAndKeepsPartialTranscript() throws {
        var session = VoiceDictationSession()
        let id = try XCTUnwrap(session.prepare())
        session.ready(id: id)
        XCTAssertFalse(session.receive(id: id, text: "two eggs", finished: false, failed: false))
        XCTAssertEqual(session.status, .listening)

        XCTAssertTrue(session.receive(id: id, text: nil, finished: true, failed: true))
        XCTAssertEqual(session.status, .unavailable)
        XCTAssertEqual(session.transcript, "two eggs")
    }

    func testStopStillAcceptsTheFinalTranscript() throws {
        var session = VoiceDictationSession()
        let id = try XCTUnwrap(session.prepare())
        session.ready(id: id)
        _ = session.receive(id: id, text: "two", finished: false, failed: false)
        session.stop()
        XCTAssertEqual(session.status, .idle)

        XCTAssertTrue(session.receive(id: id, text: "two eggs and toast", finished: true, failed: false))
        XCTAssertEqual(session.transcript, "two eggs and toast")
        XCTAssertEqual(session.status, .idle)
    }

    func testErrorAfterUserStopsDoesNotReportARecordingFailure() throws {
        var session = VoiceDictationSession()
        let id = try XCTUnwrap(session.prepare())
        session.ready(id: id)
        session.stop()
        XCTAssertTrue(session.receive(id: id, text: nil, finished: true, failed: true))
        XCTAssertEqual(session.status, .idle)
    }

    func testPreviousRecordingCannotStopOrOverwriteTheNextOne() throws {
        var session = VoiceDictationSession()
        let oldID = try XCTUnwrap(session.prepare())
        session.ready(id: oldID)
        session.stop()
        let newID = try XCTUnwrap(session.prepare())
        session.ready(id: newID)
        _ = session.receive(id: newID, text: "a banana", finished: false, failed: false)

        XCTAssertFalse(session.receive(id: oldID, text: "old transcript", finished: true, failed: true))
        XCTAssertEqual(session.status, .listening)
        XCTAssertEqual(session.transcript, "a banana")
        XCTAssertEqual(session.id, newID)
    }

    func testStoppingWhileRequestingPermissionPreventsRecording() throws {
        var session = VoiceDictationSession()
        let id = try XCTUnwrap(session.prepare())
        XCTAssertNil(session.prepare(), "Repeated taps must not start multiple permission requests")
        session.stop()
        session.ready(id: id)
        session.fail(id: id, denied: true)
        XCTAssertEqual(session.status, .idle)
        XCTAssertNil(session.id)
    }

    func testDeniedPermissionCanBeRetried() throws {
        var session = VoiceDictationSession()
        let id = try XCTUnwrap(session.prepare())
        session.fail(id: id, denied: true)
        XCTAssertEqual(session.status, .denied)

        let retryID = try XCTUnwrap(session.prepare())
        session.ready(id: retryID)
        XCTAssertEqual(session.status, .listening)
    }
}
