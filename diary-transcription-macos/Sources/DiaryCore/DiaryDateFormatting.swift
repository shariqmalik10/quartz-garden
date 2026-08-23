import Foundation

public struct DiaryDateFormatting: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func dateString(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            locale: Locale(identifier: "en_US_POSIX"),
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    public func timeString(for date: Date) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(
            format: "%02d:%02d",
            locale: Locale(identifier: "en_US_POSIX"),
            components.hour ?? 0,
            components.minute ?? 0
        )
    }

    public func fileName(for date: Date) -> String {
        "diary-log_\(dateString(for: date)).md"
    }
}
