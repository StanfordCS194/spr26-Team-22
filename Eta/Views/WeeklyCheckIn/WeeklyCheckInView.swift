import SwiftUI

struct WeeklyCheckInView: View {
    let connectionsViewModel: ConnectionsViewModel
    let onDismiss: () -> Void

    @State private var goalContactID: UUID? = WeeklyCheckInView.loadSavedGoal()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    statsSection
                    insightsSection
                    goalSection
                    // Placeholder for features not yet merged (e.g. suggested activities, mood tracking)
                    placeholderSection
                }
                .padding(20)
            }
            .navigationTitle("Weekly Check-In")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveGoal()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            connectionsViewModel.loadContacts()
            await connectionsViewModel.loadHealthScores()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(weekRangeLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("How are your friendships doing?")
                .font(.title3)
                .fontWeight(.medium)
        }
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                value: "\(seenThisWeek.count)",
                label: "friends seen\nthis week",
                color: seenThisWeek.isEmpty ? .secondary : .green
            )
            statCard(
                value: "\(overdueFriends.count)",
                label: "friends\noverdue",
                color: overdueFriends.isEmpty ? .secondary : .orange
            )
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who needs your attention?")
                .font(.headline)

            if overdueFriends.isEmpty {
                Text("You're all caught up! Great week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(overdueFriends.prefix(5), id: \.contact.id) { health in
                    FriendInsightRow(
                        health: health,
                        displayName: connectionsViewModel.displayName(for: health.contact)
                    )
                }
            }
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week's priority")
                .font(.headline)
            Text("Who will you reach out to?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if connectionsViewModel.contacts.isEmpty {
                Text("Add friends in the Friends tab to set a goal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(goalCandidates.prefix(6), id: \.contact.id) { health in
                        let name = connectionsViewModel.displayName(for: health.contact)
                        let isSelected = goalContactID == health.contact.id
                        Button {
                            goalContactID = isSelected ? nil : health.contact.id
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundStyle(isSelected ? .white : .primary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    private var placeholderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("More insights coming soon")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Suggested activities, shared memories, and mood tracking will appear here as features roll out.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var weekRangeLabel: String {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: .now) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let end = cal.date(byAdding: .day, value: 6, to: interval.start) ?? interval.start
        return "Week of \(fmt.string(from: interval.start)) – \(fmt.string(from: end))"
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }

    private var seenThisWeek: [TrackedContact] {
        connectionsViewModel.contacts.filter { contact in
            guard let last = connectionsViewModel.healthScores[contact.id]?.lastHangoutDate else { return false }
            return last >= weekStart
        }
    }

    private var overdueFriends: [RelationshipHealth] {
        connectionsViewModel.healthScores.values
            .filter { health in
                guard health.upcomingHangout?.status != .confirmed else { return false }
                guard let last = health.lastHangoutDate else { return true }
                return last < weekStart
            }
            .sorted { $0.score > $1.score }
    }

    private var goalCandidates: [RelationshipHealth] {
        connectionsViewModel.healthScores.values.sorted { $0.score > $1.score }
    }

    // MARK: - Goal persistence

    private func saveGoal() {
        guard let id = goalContactID else {
            UserDefaults.standard.removeObject(forKey: "weeklyGoalContactID")
            return
        }
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start.timeIntervalSince1970 ?? 0
        UserDefaults.standard.set(id.uuidString, forKey: "weeklyGoalContactID")
        UserDefaults.standard.set(weekStart, forKey: "weeklyGoalWeekStart")
    }

    static func loadSavedGoal() -> UUID? {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start.timeIntervalSince1970 ?? 0
        let saved = UserDefaults.standard.double(forKey: "weeklyGoalWeekStart")
        guard abs(weekStart - saved) < 1 else { return nil }
        return UserDefaults.standard.string(forKey: "weeklyGoalContactID").flatMap { UUID(uuidString: $0) }
    }
}

// MARK: - Friend row

private struct FriendInsightRow: View {
    let health: RelationshipHealth
    let displayName: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var subtitle: String {
        if let days = health.daysSinceLastHangout {
            return days == 0 ? "Seen today" : "Last seen \(days) day\(days == 1 ? "" : "s") ago"
        }
        return "No hangouts on record"
    }

    private var dotColor: Color {
        guard let days = health.daysSinceLastHangout else { return .gray }
        if days <= 14 { return .green }
        if days <= 30 { return .yellow }
        return .red
    }
}
