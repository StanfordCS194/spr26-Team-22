import Foundation

/// Updates goal progress and status by counting confirmed/pending hangouts
/// in the goal's current window from the ScheduledHangout history.
final class GoalTrackingService {
    private let goalRepository: GoalRepository
    private let hangoutRepository: ScheduledHangoutRepository

    init(goalRepository: GoalRepository, hangoutRepository: ScheduledHangoutRepository) {
        self.goalRepository = goalRepository
        self.hangoutRepository = hangoutRepository
    }

    func updateAllGoals() {
        let goals = (try? goalRepository.fetchAll()) ?? []
        let hangouts = (try? hangoutRepository.fetchAll()) ?? []
        for goal in goals {
            updateProgress(for: goal, using: hangouts)
        }
        try? goalRepository.save()
    }

    private func updateProgress(for goal: Goal, using hangouts: [ScheduledHangout]) {
        guard !goal.isPaused else { return }

        let relevantHangouts = hangouts.filter { hangout in
            guard hangout.inviteeResponse != .declined else { return false }
            let inWindow = hangout.startDate >= goal.windowStart && hangout.startDate <= goal.windowEnd
            guard inWindow else { return false }
            if goal.friendIDs.isEmpty { return true }
            guard let contactID = hangout.contact?.id else { return false }
            return goal.friendIDs.contains(contactID)
        }

        goal.progress = relevantHangouts.count
        goal.statusRaw = computedStatus(for: goal).rawValue
        goal.lastUpdated = .now
    }

    private func computedStatus(for goal: Goal) -> GoalStatus {
        if goal.progress >= goal.target { return .achieved }

        let now = Date()
        guard now <= goal.windowEnd else { return .behind }

        let totalDays = max(1, Calendar.current.dateComponents(
            [.day], from: goal.windowStart, to: goal.windowEnd).day ?? 1)
        let elapsedDays = max(0, Calendar.current.dateComponents(
            [.day], from: goal.windowStart, to: now).day ?? 0)

        let fraction = Double(elapsedDays) / Double(totalDays)
        let expectedProgress = Double(goal.target) * fraction

        if Double(goal.progress) >= expectedProgress { return .onTrack }
        if Double(goal.progress) >= expectedProgress * 0.5 { return .atRisk }
        return .behind
    }
}
