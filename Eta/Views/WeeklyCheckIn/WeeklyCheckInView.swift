import SwiftUI

struct WeeklyCheckInView: View {
    let connectionsViewModel: ConnectionsViewModel
    let homeViewModel: HomeViewModel
    let onDismiss: () -> Void
    let onViewSuggestions: () -> Void

    @State private var goalContactID: UUID?
    @State private var checkInSheetContact: TrackedContact?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    statsSection
                    if !upcomingThisWeek.isEmpty { upcomingSection }
                    insightsSection
                    if !homeViewModel.activeGoals.isEmpty { goalsSection }
                    if let warning = homeViewModel.networkConcentrationWarning { networkNudgeSection(warning) }
                    prioritySection
                }
                .padding(20)
            }
            .navigationTitle("Weekly Check-In")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveGoal()
                        homeViewModel.markCheckInCompleted()
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            connectionsViewModel.loadContacts()
            await connectionsViewModel.loadHealthScores()
            await homeViewModel.refresh()
            goalContactID = homeViewModel.weeklyPriorityContactID
        }
        .sheet(item: $checkInSheetContact) { contact in
            CheckInSheet(
                displayName: homeViewModel.displayName(for: contact),
                givenName: contact.givenName,
                phoneNumber: contact.phoneNumber ?? "",
                initialTemplate: homeViewModel.checkInTemplate ?? "How have you been?",
                onSend: { message, saveAsDefault in
                    if saveAsDefault { homeViewModel.updateCheckInTemplate(message) }
                },
                onDismiss: { checkInSheetContact = nil }
            )
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

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Planned this week")
                .font(.headline)
            ForEach(upcomingThisWeek, id: \.id) { hangout in
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundStyle(.green)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hangout.contact?.givenName ?? hangout.activity)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(hangout.activity) · \(hangout.startDate.formatted(.dateTime.weekday(.wide).hour().minute()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
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

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your goals")
                .font(.headline)
            ForEach(homeViewModel.activeGoals) { goal in
                CheckInGoalRow(
                    goal: goal,
                    friendNames: homeViewModel.friendNames(for: goal)
                )
            }
        }
    }

    private func networkNudgeSection(_ warning: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3")
                .foregroundStyle(.purple)
                .font(.title3)
            Text(warning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week's priority")
                .font(.headline)
            Text("Who will you reach out to?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if connectionsViewModel.contacts.isEmpty {
                Text("Add friends in the Friends tab to set a priority.")
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

                if let selectedID = goalContactID,
                   let contact = connectionsViewModel.contacts.first(where: { $0.id == selectedID }) {
                    priorityActions(for: contact)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func priorityActions(for contact: TrackedContact) -> some View {
        HStack(spacing: 10) {
            Button {
                saveGoal()
                homeViewModel.markCheckInCompleted()
                onViewSuggestions()
            } label: {
                Label("View suggestions", systemImage: "sparkles")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if contact.phoneNumber != nil {
                Button {
                    checkInSheetContact = contact
                } label: {
                    Label("Send check-in", systemImage: "message")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
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

    private var upcomingThisWeek: [ScheduledHangout] {
        homeViewModel.upcomingHangoutsThisWeek
    }

    // MARK: - Goal persistence

    private func saveGoal() {
        homeViewModel.saveWeeklyGoal(contactID: goalContactID)
    }
}

// MARK: - Friend insight row

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

// MARK: - Goal row (full-width, reuses Goal model data)

private struct CheckInGoalRow: View {
    let goal: Goal
    let friendNames: [String]

    var body: some View {
        HStack(spacing: 14) {
            progressRing
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if !friendNames.isEmpty {
                    Text(friendNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(goal.progress) of \(goal.target) this \(goal.cadence.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: goal.progressFraction)
                .stroke(statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: goal.progressFraction)
            Text("\(goal.progress)/\(goal.target)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 38, height: 38)
    }

    private var statusColor: Color {
        switch goal.status {
        case .onTrack:  return Color(red: 0.2,  green: 0.7,  blue: 0.45)
        case .atRisk:   return Color(red: 0.9,  green: 0.65, blue: 0.1)
        case .behind:   return Color(red: 0.85, green: 0.35, blue: 0.28)
        case .achieved: return Color(red: 0.3,  green: 0.55, blue: 0.9)
        }
    }

    private var statusLabel: String {
        switch goal.status {
        case .onTrack:  return "On track"
        case .atRisk:   return "At risk"
        case .behind:   return "Behind"
        case .achieved: return "Achieved"
        }
    }
}
