import Foundation
import SwiftData

enum GoalCadence: String, Codable, CaseIterable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var displayName: String {
        switch self {
        case .weekly:    return "week"
        case .monthly:   return "month"
        case .quarterly: return "quarter"
        case .yearly:    return "year"
        }
    }

    var durationInDays: Int {
        switch self {
        case .weekly:    return 7
        case .monthly:   return 30
        case .quarterly: return 90
        case .yearly:    return 365
        }
    }
}

enum GoalStatus: String, Codable {
    case onTrack
    case atRisk
    case behind
    case achieved
}

enum GoalSource: String, Codable {
    case manual
    case aiSuggested
    case aiAccepted
}

@Model
final class Goal {
    var id: UUID
    var title: String
    /// Comma-separated TrackedContact.id UUID strings. Empty string = applies to all friends.
    var friendIDsCSV: String
    var cadenceRaw: String
    var target: Int
    var windowStart: Date
    var windowEnd: Date
    var progress: Int
    var statusRaw: String
    var createdAt: Date
    var sourceRaw: String
    var lastUpdated: Date
    var isPaused: Bool

    // MARK: - Typed accessors

    var cadence: GoalCadence { GoalCadence(rawValue: cadenceRaw) ?? .monthly }
    var status: GoalStatus { GoalStatus(rawValue: statusRaw) ?? .onTrack }
    var source: GoalSource { GoalSource(rawValue: sourceRaw) ?? .manual }

    var friendIDs: [UUID] {
        friendIDsCSV.isEmpty
            ? []
            : friendIDsCSV.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: windowEnd).day ?? 0)
    }

    var progressFraction: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(progress) / Double(target))
    }

    init(
        id: UUID = UUID(),
        title: String,
        friendIDs: [UUID] = [],
        cadence: GoalCadence = .monthly,
        target: Int = 2,
        windowStart: Date,
        windowEnd: Date,
        progress: Int = 0,
        status: GoalStatus = .onTrack,
        source: GoalSource = .manual,
        isPaused: Bool = false
    ) {
        self.id = id
        self.title = title
        self.friendIDsCSV = friendIDs.map { $0.uuidString }.joined(separator: ",")
        self.cadenceRaw = cadence.rawValue
        self.target = target
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.progress = progress
        self.statusRaw = status.rawValue
        self.createdAt = .now
        self.sourceRaw = source.rawValue
        self.lastUpdated = .now
        self.isPaused = isPaused
    }
}
