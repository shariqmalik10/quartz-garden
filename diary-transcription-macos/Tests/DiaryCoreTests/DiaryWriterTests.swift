import Foundation
import XCTest
@testable import DiaryCore

final class DiaryWriterTests: XCTestCase {
    private var rootURL: URL!
    private var vaultURL: URL!
    private var calendar: Calendar!
    private var firstDate: Date!
    private var secondDate: Date!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        vaultURL = rootURL.appendingPathComponent("My Vault", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)

        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        firstDate = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 23, hour: 9, minute: 7
        )))
        secondDate = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 23, hour: 21, minute: 42
        )))
    }

    override func tearDownWithError() throws {
        if let rootURL {
            try? FileManager.default.removeItem(at: rootURL)
        }
    }

    func testConfigureCreatesDiaryDirectoryButNotDailyFile() async throws {
        let writer = DiaryWriter(calendar: calendar)
        let diaryURL = try await writer.configureVault(vaultURL)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: diaryURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: diaryURL.path), [])
    }

    func testFirstWriteCreatesExpectedMarkdown() async throws {
        let writer = DiaryWriter(calendar: calendar)
        try await writer.configureVault(vaultURL)

        let fileURL = try await writer.append("A clear first thought.", at: firstDate)

        XCTAssertEqual(fileURL.lastPathComponent, "diary-log_2026-08-23.md")
        XCTAssertEqual(
            try String(contentsOf: fileURL, encoding: .utf8),
            "# Diary Log — 2026-08-23\n\n## 09:07\nA clear first thought.\n"
        )
    }

    func testSubsequentWriteAppendsAnotherSection() async throws {
        let writer = DiaryWriter(calendar: calendar)
        try await writer.configureVault(vaultURL)

        let fileURL = try await writer.append("Morning", at: firstDate)
        _ = try await writer.append("Evening", at: secondDate)

        XCTAssertEqual(
            try String(contentsOf: fileURL, encoding: .utf8),
            "# Diary Log — 2026-08-23\n\n## 09:07\nMorning\n\n## 21:42\nEvening\n"
        )
    }

    func testAppendNeverOverwritesPreexistingContent() async throws {
        let writer = DiaryWriter(calendar: calendar)
        let diaryURL = try await writer.configureVault(vaultURL)
        let fileURL = diaryURL.appendingPathComponent("diary-log_2026-08-23.md")
        let original = "User-authored preface\n"
        try original.write(to: fileURL, atomically: true, encoding: .utf8)

        _ = try await writer.append("New entry", at: firstDate)
        let result = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(result.hasPrefix(original))
        XCTAssertTrue(result.contains("## 09:07\nNew entry\n"))
    }

    func testDateAndTimeFormattingUsesInjectedLocalCalendar() throws {
        let formatting = DiaryDateFormatting(calendar: calendar)

        XCTAssertEqual(formatting.dateString(for: firstDate), "2026-08-23")
        XCTAssertEqual(formatting.timeString(for: firstDate), "09:07")
        XCTAssertEqual(formatting.fileName(for: firstDate), "diary-log_2026-08-23.md")
    }

    func testUnconfiguredVaultFailsWithoutCreatingFiles() async {
        let writer = DiaryWriter(calendar: calendar)

        do {
            _ = try await writer.append("Should not save", at: firstDate)
            XCTFail("Expected an unconfigured-vault error")
        } catch {
            XCTAssertEqual(error as? DiaryError, .vaultNotConfigured)
        }
    }

    func testInvalidVaultIsRejected() async {
        let missingURL = rootURL.appendingPathComponent("Missing")
        let writer = DiaryWriter(calendar: calendar)

        do {
            _ = try await writer.configureVault(missingURL)
            XCTFail("Expected invalid vault")
        } catch {
            XCTAssertEqual(error as? DiaryError, .invalidVault(missingURL.standardizedFileURL))
        }
    }

    func testEmptyEntryDoesNotCreateDailyFile() async throws {
        let writer = DiaryWriter(calendar: calendar)
        let diaryURL = try await writer.configureVault(vaultURL)

        do {
            _ = try await writer.append("  \n", at: firstDate)
            XCTFail("Expected empty entry")
        } catch {
            XCTAssertEqual(error as? DiaryError, .emptyEntry)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: diaryURL.path), [])
    }

    func testConcurrentAppendsAreSerializedAndAllPreserved() async throws {
        let writer = DiaryWriter(calendar: calendar)
        try await writer.configureVault(vaultURL)
        let entryCount = 40
        let appendDate = try XCTUnwrap(firstDate)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<entryCount {
                group.addTask {
                    _ = try await writer.append("Concurrent entry \(index)", at: appendDate)
                }
            }
            try await group.waitForAll()
        }

        let fileURL = vaultURL
            .appendingPathComponent("Diary")
            .appendingPathComponent("diary-log_2026-08-23.md")
        let result = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(result.components(separatedBy: "# Diary Log —").count - 1, 1)
        XCTAssertEqual(result.components(separatedBy: "## 09:07").count - 1, entryCount)
        for index in 0..<entryCount {
            XCTAssertEqual(
                result.components(separatedBy: "Concurrent entry \(index)\n").count - 1,
                1
            )
        }
    }
}
