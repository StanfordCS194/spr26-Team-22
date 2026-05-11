import Foundation

struct UserPreferences: Codable {
    var preferredActivities: [String]
    var relationshipHealthThreshold: Double
    var lookAheadDays: Int
    var enableNotifications: Bool
    var notificationTime: Date

    init(
        preferredActivities: [String] = Activity.allCases.map { $0.rawValue },
        relationshipHealthThreshold: Double = 7.0,
        lookAheadDays: Int = 90,
        enableNotifications: Bool = true,
        notificationTime: Date = {
            var components = DateComponents()
            components.hour = 10
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }()
    ) {
        self.preferredActivities = preferredActivities
        self.relationshipHealthThreshold = relationshipHealthThreshold
        self.lookAheadDays = lookAheadDays
        self.enableNotifications = enableNotifications
        self.notificationTime = notificationTime
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preferredActivities, forKey: .preferredActivities)
        try container.encode(relationshipHealthThreshold, forKey: .relationshipHealthThreshold)
        try container.encode(lookAheadDays, forKey: .lookAheadDays)
        try container.encode(enableNotifications, forKey: .enableNotifications)
        try container.encode(notificationTime.timeIntervalSince1970, forKey: .notificationTimeInterval)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredActivities = try container.decode([String].self, forKey: .preferredActivities)
        relationshipHealthThreshold = try container.decode(Double.self, forKey: .relationshipHealthThreshold)
        lookAheadDays = try container.decode(Int.self, forKey: .lookAheadDays)
        enableNotifications = try container.decode(Bool.self, forKey: .enableNotifications)
        let timeInterval = try container.decode(TimeInterval.self, forKey: .notificationTimeInterval)
        notificationTime = Date(timeIntervalSince1970: timeInterval)
    }

    enum CodingKeys: String, CodingKey {
        case preferredActivities
        case relationshipHealthThreshold
        case lookAheadDays
        case enableNotifications
        case notificationTimeInterval
    }
}
