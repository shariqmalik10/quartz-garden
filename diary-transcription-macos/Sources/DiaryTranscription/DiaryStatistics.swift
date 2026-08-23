import Foundation

struct DiaryUsageStats: Codable, Equatable, Sendable {
  struct Day: Codable, Equatable, Sendable {
    var entries = 0
    var words = 0
    var audioSeconds: TimeInterval = 0
  }

  struct DaySnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let words: Int
    let entries: Int
  }

  private(set) var totalEntries = 0
  private(set) var voiceEntries = 0
  private(set) var totalWords = 0
  private(set) var audioSeconds: TimeInterval = 0
  private(set) var days: [String: Day] = [:]
  private var recordedEntryIDs: [String] = []

  mutating func record(
    entryID: String,
    text: String,
    audioDuration: TimeInterval?,
    date: Date,
    calendar: Calendar = .current
  ) {
    guard !recordedEntryIDs.contains(entryID) else { return }
    let words = Self.wordCount(text)
    let duration = max(0, audioDuration ?? 0)
    let key = Self.dayKey(date, calendar: calendar)
    var day = days[key] ?? Day()
    day.entries += 1
    day.words += words
    day.audioSeconds += duration
    days[key] = day
    totalEntries += 1
    totalWords += words
    audioSeconds += duration
    if audioDuration != nil { voiceEntries += 1 }
    recordedEntryIDs.append(entryID)
    if recordedEntryIDs.count > 1_000 {
      recordedEntryIDs.removeFirst(recordedEntryIDs.count - 1_000)
    }
  }

  func recentDays(
    endingAt date: Date = Date(),
    count: Int = 7,
    calendar: Calendar = .current
  ) -> [DaySnapshot] {
    guard count > 0 else { return [] }
    return (0..<count).reversed().compactMap { offset in
      guard let dayDate = calendar.date(byAdding: .day, value: -offset, to: date) else {
        return nil
      }
      let key = Self.dayKey(dayDate, calendar: calendar)
      let values = days[key] ?? Day()
      let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: dayDate) - 1]
      return DaySnapshot(
        id: key,
        label: String(weekday.prefix(1)).uppercased(),
        words: values.words,
        entries: values.entries
      )
    }
  }

  func currentStreak(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
    var streak = 0
    var cursor = referenceDate
    while days[Self.dayKey(cursor, calendar: calendar)]?.entries ?? 0 > 0 {
      streak += 1
      guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = previous
    }
    return streak
  }

  static func wordCount(_ text: String) -> Int {
    text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
  }

  private static func dayKey(_ date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
  }
}

@MainActor
struct DiaryUsageStatsStore {
  private let defaults: UserDefaults
  private let key = "DiaryTranscription.usageStats"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> DiaryUsageStats {
    guard let data = defaults.data(forKey: key),
      let value = try? JSONDecoder().decode(DiaryUsageStats.self, from: data)
    else {
      return DiaryUsageStats()
    }
    return value
  }

  func save(_ value: DiaryUsageStats) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    defaults.set(data, forKey: key)
  }
}
