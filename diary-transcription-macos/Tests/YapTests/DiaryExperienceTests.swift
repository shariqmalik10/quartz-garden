import Foundation
import XCTest

@testable import Yap

@MainActor
final class DiaryExperienceTests: XCTestCase {
  func testObsidianLinkOpensTheExactVaultFile() throws {
    let vault = URL(fileURLWithPath: "/Users/shariq/Documents/Obsidian Vault")
    let note = vault.appendingPathComponent("Writing/A long thought.md")

    let url = try ObsidianLink.openURL(vaultURL: vault, fileURL: note)
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

    XCTAssertEqual(components.scheme, "obsidian")
    XCTAssertEqual(components.host, "open")
    XCTAssertEqual(
      components.queryItems?.first(where: { $0.name == "path" })?.value,
      "/Users/shariq/Documents/Obsidian Vault/Writing/A long thought.md"
    )
  }

  func testObsidianLinkRejectsFilesOutsideVault() {
    let vault = URL(fileURLWithPath: "/Users/shariq/Documents/Obsidian Vault")
    let note = URL(fileURLWithPath: "/Users/shariq/Documents/another.md")

    XCTAssertThrowsError(try ObsidianLink.openURL(vaultURL: vault, fileURL: note)) { error in
      XCTAssertEqual(error as? ObsidianLinkError, .fileOutsideVault)
    }
  }

  func testUsageStatsDeduplicateRetriesAndBuildSevenDaySeries() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Riyadh"))
    let today = try XCTUnwrap(
      calendar.date(
        from: DateComponents(
          year: 2026, month: 8, day: 24, hour: 12
        )))
    let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
    var stats = DiaryUsageStats()

    stats.record(
      entryID: "voice-1",
      text: "One two three four",
      audioDuration: 42,
      date: yesterday,
      calendar: calendar
    )
    stats.record(
      entryID: "voice-1",
      text: "One two three four",
      audioDuration: 42,
      date: yesterday,
      calendar: calendar
    )
    stats.record(
      entryID: "manual-1",
      text: "Five six",
      audioDuration: nil,
      date: today,
      calendar: calendar
    )

    XCTAssertEqual(stats.totalEntries, 2)
    XCTAssertEqual(stats.voiceEntries, 1)
    XCTAssertEqual(stats.totalWords, 6)
    XCTAssertEqual(stats.audioSeconds, 42)
    XCTAssertEqual(stats.currentStreak(referenceDate: today, calendar: calendar), 2)
    let series = stats.recentDays(endingAt: today, count: 7, calendar: calendar)
    XCTAssertEqual(series.count, 7)
    XCTAssertEqual(series.suffix(2).map(\.words), [4, 2])
    XCTAssertEqual(series.suffix(2).map(\.audioSeconds), [42, 0])
  }

  func testMarkdownPathsResolveToTheExpectedWorkspace() {
    XCTAssertEqual(DiaryAppModel.workspace(forRelativePath: "Diary/today.md"), .diary)
    XCTAssertEqual(
      DiaryAppModel.workspace(forRelativePath: "Writing/Blogs/my-post.md"),
      .blog
    )
    XCTAssertEqual(
      DiaryAppModel.workspace(forRelativePath: "Writing/older-draft.md"),
      .blog
    )
    XCTAssertEqual(DiaryAppModel.workspace(forRelativePath: "Notes/postgres.md"), .notes)
    XCTAssertEqual(
      DiaryAppModel.workspace(forRelativePath: "Projects/garden.md"),
      .anyMarkdown
    )
  }

  func testWorkspaceRootsMatchTheQuartzAndPrivateFolderMap() {
    XCTAssertEqual(EntryWorkspace.diary.directoryRelativePath, "Diary")
    XCTAssertEqual(EntryWorkspace.blog.directoryRelativePath, "Writing/Blogs")
    XCTAssertEqual(EntryWorkspace.notes.directoryRelativePath, "Notes")
    XCTAssertEqual(EntryWorkspace.anyMarkdown.directoryRelativePath, "")
    XCTAssertTrue(EntryWorkspace.blog.accepts(relativePath: "Writing/legacy.md"))
    XCTAssertFalse(EntryWorkspace.blog.accepts(relativePath: "Notes/private.md"))
  }

  func testSelectingWritingFolderResolvesToActualObsidianVaultRoot() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("ObsidianRootTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let vault = root.appendingPathComponent("Obsidian Vault", isDirectory: true)
    let writing = vault.appendingPathComponent("Writing", isDirectory: true)
    try FileManager.default.createDirectory(
      at: vault.appendingPathComponent(".obsidian", isDirectory: true),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: writing, withIntermediateDirectories: true)

    XCTAssertEqual(
      DiaryAppModel.obsidianVaultRoot(containing: writing),
      vault.standardizedFileURL
    )
    XCTAssertNil(DiaryAppModel.obsidianVaultRoot(containing: root))
  }
}
