import AppKit
import Foundation
import XCTest
@testable import DiaryTranscription

@MainActor
final class RecoveryAndShortcutTests: XCTestCase {
    func testShortcutRequiresTwoModifiersAndRejectsEditingCommands() {
        XCTAssertFalse(ShortcutRecorderNSView.isSafeBinding(keyCode: 0, flags: [.shift]))
        XCTAssertFalse(ShortcutRecorderNSView.isSafeBinding(keyCode: 8, flags: [.command, .shift]))
        XCTAssertTrue(ShortcutRecorderNSView.isSafeBinding(keyCode: 2, flags: [.control, .option]))
    }

    func testPendingSidecarCannotRedirectWritesAndCorruptMetadataIsQuarantined() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DiarySidecarTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let audioURL = root.appendingPathComponent("recording.m4a")
        try Data("audio".utf8).write(to: audioURL)
        let sidecarURL = audioURL.deletingPathExtension().appendingPathExtension("pending.json")
        let redirected = PendingTranscription(
            audioPath: "/tmp/not-the-captured-audio.m4a",
            capturedAt: Date(),
            transcript: "kept"
        )
        try JSONEncoder().encode(redirected).write(to: sidecarURL)
        let store = PendingTranscriptionStore()

        XCTAssertNil(try store.load(for: audioURL))
        XCTAssertFalse(FileManager.default.fileExists(atPath: sidecarURL.path))
        let quarantined = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.contains("invalid-") }
        XCTAssertEqual(quarantined.count, 1)
        XCTAssertThrowsError(try store.save(redirected, for: audioURL))

        let trusted = PendingTranscription(
            audioPath: audioURL.path,
            capturedAt: Date(),
            transcript: "safe"
        )
        try store.save(trusted, for: audioURL)
        XCTAssertEqual(try store.load(for: audioURL)?.transcript, "safe")
    }
}
