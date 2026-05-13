import Foundation
import SwiftData

enum InsightType: String, Codable, CaseIterable {
    case drift
    case pattern
    case opportunity
    case milestone
    case reflection
    case network
}

enum InsightAction: String, Codable {
    case planActivity
    case sendCheckIn
    case addGoal
    case snooze
    case reflect
}

@Model
final class PersonalRelationshipInsight {
    var id: UUID
    var typeRaw: String
    /// TrackedContact.id — nil means this is an overall/network insight.
    var friendIDString: String?
    /// Goal.id — nil means insight is not tied to a specific goal.
    var goalIDString: String?
    var headline: String
    var actionRaw: String
    var generatedAt: Date
    var dismissedAt: Date?
    /// How many consecutive same-type insights the user has dismissed.
    var consecutiveDismissals: Int

    // MARK: - Typed accessors

    var type: InsightType { InsightType(rawValue: typeRaw) ?? .drift }
    var primaryAction: InsightAction { InsightAction(rawValue: actionRaw) ?? .snooze }
    var friendID: UUID? {
        guard let str = friendIDString else { return nil }
        return UUID(uuidString: str)
    }
    var goalID: UUID? {
        guard let str = goalIDString else { return nil }
        return UUID(uuidString: str)
    }

    var isDismissed: Bool { dismissedAt != nil }

    init(
        id: UUID = UUID(),
        type: InsightType,
        friendID: UUID? = nil,
        goalID: UUID? = nil,
        headline: String,
        primaryAction: InsightAction,
        generatedAt: Date = .now
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.friendIDString = friendID?.uuidString
        self.goalIDString = goalID?.uuidString
        self.headline = headline
        self.actionRaw = primaryAction.rawValue
        self.generatedAt = generatedAt
        self.dismissedAt = nil
        self.consecutiveDismissals = 0
    }
}
