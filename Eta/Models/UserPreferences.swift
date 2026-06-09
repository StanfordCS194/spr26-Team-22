import Foundation

struct UserPreferences: Codable {
    var preferredActivities: [String]
    var relationshipHealthThreshold: Double
    var lookAheadDays: Int
    var enableNotifications: Bool
    var notificationTime: Date
    var checkInTemplate: String?
    var hasSetCheckInTemplate: Bool
    var userCity: String?
    var userLatitude: Double?
    var userLongitude: Double?
    /// Whether the weekly check-in notification is enabled. Independent of enableNotifications.
    var weeklyCheckInEnabled: Bool
    /// Weekday for the weekly check-in notification: 1 = Sunday … 7 = Saturday.
    var weeklyCheckInDay: Int
    /// Time of day for the weekly check-in notification. Only hour/minute components are used.
    var weeklyCheckInTime: Date

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
        }(),
        checkInTemplate: String? = nil,
        hasSetCheckInTemplate: Bool = false,
        userCity: String? = nil,
        userLatitude: Double? = nil,
        userLongitude: Double? = nil,
        weeklyCheckInEnabled: Bool = true,
        weeklyCheckInDay: Int = 1,
        weeklyCheckInTime: Date = {
            var components = DateComponents()
            components.hour = 18
            components.minute = 0
            return Calendar.current.date(from: components) ?? Date()
        }()
    ) {
        self.preferredActivities = preferredActivities
        self.relationshipHealthThreshold = relationshipHealthThreshold
        self.lookAheadDays = lookAheadDays
        self.enableNotifications = enableNotifications
        self.notificationTime = notificationTime
        self.checkInTemplate = checkInTemplate
        self.hasSetCheckInTemplate = hasSetCheckInTemplate
        self.userCity = userCity
        self.userLatitude = userLatitude
        self.userLongitude = userLongitude
        self.weeklyCheckInEnabled = weeklyCheckInEnabled
        self.weeklyCheckInDay = weeklyCheckInDay
        self.weeklyCheckInTime = weeklyCheckInTime
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preferredActivities, forKey: .preferredActivities)
        try container.encode(relationshipHealthThreshold, forKey: .relationshipHealthThreshold)
        try container.encode(lookAheadDays, forKey: .lookAheadDays)
        try container.encode(enableNotifications, forKey: .enableNotifications)
        try container.encode(notificationTime.timeIntervalSince1970, forKey: .notificationTimeInterval)
        try container.encodeIfPresent(checkInTemplate, forKey: .checkInTemplate)
        try container.encode(hasSetCheckInTemplate, forKey: .hasSetCheckInTemplate)
        try container.encodeIfPresent(userCity, forKey: .userCity)
        try container.encodeIfPresent(userLatitude, forKey: .userLatitude)
        try container.encodeIfPresent(userLongitude, forKey: .userLongitude)
        try container.encode(weeklyCheckInEnabled, forKey: .weeklyCheckInEnabled)
        try container.encode(weeklyCheckInDay, forKey: .weeklyCheckInDay)
        try container.encode(weeklyCheckInTime.timeIntervalSince1970, forKey: .weeklyCheckInTimeInterval)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredActivities = try container.decode([String].self, forKey: .preferredActivities)
        relationshipHealthThreshold = try container.decode(Double.self, forKey: .relationshipHealthThreshold)
        lookAheadDays = try container.decode(Int.self, forKey: .lookAheadDays)
        enableNotifications = try container.decode(Bool.self, forKey: .enableNotifications)
        let timeInterval = try container.decode(TimeInterval.self, forKey: .notificationTimeInterval)
        notificationTime = Date(timeIntervalSince1970: timeInterval)
        checkInTemplate = try container.decodeIfPresent(String.self, forKey: .checkInTemplate)
        hasSetCheckInTemplate = try container.decodeIfPresent(Bool.self, forKey: .hasSetCheckInTemplate) ?? false
        userCity = try container.decodeIfPresent(String.self, forKey: .userCity)
        userLatitude = try container.decodeIfPresent(Double.self, forKey: .userLatitude)
        userLongitude = try container.decodeIfPresent(Double.self, forKey: .userLongitude)
        weeklyCheckInEnabled = try container.decodeIfPresent(Bool.self, forKey: .weeklyCheckInEnabled) ?? true
        weeklyCheckInDay = try container.decodeIfPresent(Int.self, forKey: .weeklyCheckInDay) ?? 1
        let checkInTimeInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .weeklyCheckInTimeInterval)
        if let t = checkInTimeInterval {
            weeklyCheckInTime = Date(timeIntervalSince1970: t)
        } else {
            var c = DateComponents(); c.hour = 18; c.minute = 0
            weeklyCheckInTime = Calendar.current.date(from: c) ?? Date()
        }
    }

    enum CodingKeys: String, CodingKey {
        case preferredActivities
        case relationshipHealthThreshold
        case lookAheadDays
        case enableNotifications
        case notificationTimeInterval
        case checkInTemplate
        case hasSetCheckInTemplate
        case userCity
        case userLatitude
        case userLongitude
        case weeklyCheckInEnabled
        case weeklyCheckInDay
        case weeklyCheckInTimeInterval
    }
}
