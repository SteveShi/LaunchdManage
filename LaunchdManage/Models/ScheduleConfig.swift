import Foundation

/// 日历间隔调度配置（对应 StartCalendarInterval）
struct CalendarInterval: Sendable, Equatable, Codable, Identifiable {
    let id = UUID()
    var minute: Int?
    var hour: Int?
    var day: Int?
    var weekday: Int?
    var month: Int?
    
    /// 从 plist 字典解析
    init(from dict: [String: Any]) {
        self.minute = dict["Minute"] as? Int
        self.hour = dict["Hour"] as? Int
        self.day = dict["Day"] as? Int
        self.weekday = dict["Weekday"] as? Int
        self.month = dict["Month"] as? Int
    }
    
    init(minute: Int? = nil, hour: Int? = nil, day: Int? = nil, weekday: Int? = nil, month: Int? = nil) {
        self.minute = minute
        self.hour = hour
        self.day = day
        self.weekday = weekday
        self.month = month
    }
    
    /// 转换为 plist 字典
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let minute { dict["Minute"] = minute }
        if let hour { dict["Hour"] = hour }
        if let day { dict["Day"] = day }
        if let weekday { dict["Weekday"] = weekday }
        if let month { dict["Month"] = month }
        return dict
    }
    
    /// 人类可读的描述
    var displayDescription: String {
        var parts: [String] = []
        if let month { parts.append(String(localized: "Month \(month)")) }
        if let day { parts.append(String(localized: "Day \(day)")) }
        if let weekday { parts.append(weekdayName(weekday)) }
        if let hour, let minute {
            parts.append(String(format: "%02d:%02d", hour, minute))
        } else if let hour {
            parts.append(String(format: "%02d:00", hour))
        } else if let minute {
            parts.append(String(localized: "Minute \(minute)"))
        }
        return parts.isEmpty ? String(localized: "Every minute") : parts.joined(separator: " ")
    }
    
    private func weekdayName(_ day: Int) -> String {
        let names = [
            0: String(localized: "Sunday"),
            1: String(localized: "Monday"),
            2: String(localized: "Tuesday"),
            3: String(localized: "Wednesday"),
            4: String(localized: "Thursday"),
            5: String(localized: "Friday"),
            6: String(localized: "Saturday"),
            7: String(localized: "Sunday")
        ]
        return names[day] ?? String(localized: "Unknown")
    }
    
    // Custom Codable to exclude `id` from serialization
    enum CodingKeys: String, CodingKey {
        case minute, hour, day, weekday, month
    }
}
