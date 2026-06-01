import SwiftUI

struct FriendDetailView: View {
    let contact: TrackedContact
    let health: RelationshipHealth
    let displayName: String
    let homeViewModel: HomeViewModel
    var onAddGoal: (() -> Void)?

    @Environment(\.openURL) private var openURL
    @State private var showingGoalCreation = false
    @State private var showingLogHangout = false
    @State private var showingCheckIn = false
    @State private var showingFirstTimeCheckIn = false
    @State private var openCheckInAfterFirstTime = false
    @State private var editingHangout: ScheduledHangout? = nil
    @State private var editingNotes = false
    @State private var notesText = ""
    @State private var cityText = ""
    @State private var showingTagPicker = false
    @State private var editingTags: [ContactTag] = []

    private var profile: ContactProfile {
        _ = homeViewModel.profileVersion
        return homeViewModel.contactProfile(for: contact)
    }

    private var goals: [Goal] {
        homeViewModel.goals(for: contact)
    }

    private var recentHangouts: [ScheduledHangout] {
        homeViewModel.pastHangouts(for: contact)
    }

    private var upcomingHangouts: [ScheduledHangout] {
        homeViewModel.upcomingHangouts(for: contact)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                profileHeader
                insightSummary
                preferencesSection
                activeGoalsSection
                hangoutHistorySection
                ctaButtons
            }
            .padding()
            .padding(.bottom, 32)
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            notesText = profile.notes
            cityText = contact.city ?? ""
        }
        .onChange(of: showingTagPicker) { _, isShowing in
            if isShowing { editingTags = contact.contextTags }
        }
        .onChange(of: showingFirstTimeCheckIn) { _, isShowing in
            if !isShowing && openCheckInAfterFirstTime {
                openCheckInAfterFirstTime = false
                showingCheckIn = true
            }
        }
        .sheet(isPresented: $showingLogHangout) {
            LogHangoutSheet(
                contact: contact,
                displayName: displayName,
                isRemote: contact.isRemote,
                onLog: { activity, date in
                    homeViewModel.logPastHangout(contact: contact, activity: activity, date: date)
                    showingLogHangout = false
                },
                onDismiss: { showingLogHangout = false }
            )
        }
        .sheet(item: $editingHangout) { hangout in
            LogHangoutSheet(
                contact: contact,
                displayName: displayName,
                isRemote: contact.isRemote,
                initialActivity: hangout.activity,
                initialDate: hangout.startDate,
                onLog: { activity, date in
                    homeViewModel.updateHangout(hangout, activity: activity, date: date)
                    editingHangout = nil
                },
                onDismiss: { editingHangout = nil }
            )
        }
        .sheet(isPresented: $showingFirstTimeCheckIn) {
            FirstTimeCheckInSheet(
                displayName: displayName,
                phoneNumber: contact.phoneNumber ?? contact.emailAddress ?? "",
                onSave: { template in
                    homeViewModel.updateCheckInTemplate(template)
                    showingFirstTimeCheckIn = false
                },
                onSkip: {
                    homeViewModel.markCheckInTemplateSet()
                    openCheckInAfterFirstTime = true
                    showingFirstTimeCheckIn = false
                },
                onDismiss: { showingFirstTimeCheckIn = false }
            )
        }
        .sheet(isPresented: $showingCheckIn) {
            CheckInSheet(
                displayName: displayName,
                givenName: contact.givenName.isEmpty ? displayName : contact.givenName,
                phoneNumber: contact.phoneNumber ?? contact.emailAddress ?? "",
                initialTemplate: homeViewModel.checkInTemplate ?? "How have you been?",
                onSend: { message, saveAsDefault in
                    if saveAsDefault {
                        homeViewModel.updateCheckInTemplate(message)
                    }
                    showingCheckIn = false
                },
                onDismiss: { showingCheckIn = false }
            )
        }
        .sheet(isPresented: $showingTagPicker) {
            ContactTagPickerView(
                selectedTags: $editingTags,
                onDone: { homeViewModel.updateTags(editingTags, for: contact) },
                existingLabels: homeViewModel.existingCustomLabels
            )
        }
        .sheet(isPresented: $showingGoalCreation) {
            GoalCreationSheet(
                contacts: homeViewModel.contacts,
                formatter: homeViewModel.formatter,
                preselectedContact: contact,
                health: health,
                likedActivities: profile.likedActivities,
                onGoalCreated: { goal in
                    homeViewModel.createGoal(goal)
                }
            )
        }
    }

    // MARK: - Sections

    private var profileHeader: some View {
        HStack(spacing: 16) {
            Text(initials)
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(avatarColor, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.title2.weight(.semibold))

                if let days = health.daysSinceLastHangout {
                    Text("Last hung out \(days) day\(days == 1 ? "" : "s") ago")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if health.upcomingHangout != nil {
                    Text("Hangout coming up soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No hangouts recorded yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var insightSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Relationship snapshot")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                statPill(
                    value: health.hangoutCount > 0 ? "\(health.hangoutCount)" : "—",
                    label: "meetups (90d)"
                )

                if let days = health.daysSinceLastHangout {
                    statPill(value: "\(days)d", label: "since last")
                }

                statPill(
                    value: contact.isRemote ? "🌐" : "📍",
                    label: contact.isRemote ? "online" : "in person"
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Location
            VStack(alignment: .leading, spacing: 6) {
                    Text("Location")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    CitySearchField(city: $cityText,
                        onCommit: { _ in saveCity() },
                        onCoordinates: { homeViewModel.updateCityCoordinates($0, $1, for: contact) })
                }

            // Context tags
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Context")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !contact.contextTags.isEmpty {
                        Button("Edit") { showingTagPicker = true }
                            .font(.caption.weight(.semibold))
                    }
                }

                if contact.contextTags.isEmpty {
                    Button {
                        showingTagPicker = true
                    } label: {
                        Label("Where do you know them from?", systemImage: "tag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.secondary.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    FlexibleWrap {
                        ForEach(Array(contact.contextTags.prefix(2))) { tag in
                            Text(tag.displayName)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(tag.parentCategory.color.opacity(0.15), in: Capsule())
                                .foregroundStyle(tag.parentCategory.color)
                        }
                        if contact.contextTags.count > 2 {
                            Text("+\(contact.contextTags.count - 2)")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.secondary.opacity(0.10), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Pending inference prompt
            if let pending = profile.pendingInference {
                pendingInferenceCard(pending)
            }

            // Liked activities
            if !profile.likedActivities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Likes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    activityChipRow(activities: profile.likedActivities, sentiment: .like)
                }
            }

            // Disliked activities
            if !profile.dislikedActivities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Not a fit")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    activityChipRow(activities: profile.dislikedActivities, sentiment: .dislike)
                }
            }

            // Quick-add from remaining activities
            let remaining = Activity.allCases.filter {
                !profile.likedActivities.contains($0) && !profile.dislikedActivities.contains($0)
            }
            if !remaining.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Add preference")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    activityAddRow(activities: remaining)
                }
            }

            // Notes
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if editingNotes {
                    TextField("e.g. prefers mornings, she's vegan", text: $notesText, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(3...)
                        .padding(10)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        .onSubmit {
                            homeViewModel.updateNotes(notesText, for: contact)
                            editingNotes = false
                        }
                    HStack {
                        Spacer()
                        Button("Save") {
                            homeViewModel.updateNotes(notesText, for: contact)
                            editingNotes = false
                        }
                        .font(.caption.weight(.semibold))
                    }
                } else {
                    Button {
                        notesText = profile.notes
                        editingNotes = true
                    } label: {
                        Text(profile.notes.isEmpty ? "Add a note…" : profile.notes)
                            .font(.subheadline)
                            .foregroundStyle(profile.notes.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pendingInferenceCard(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Looks like you and \(contact.givenName) usually \(activity.rawValue.lowercased()) — add as a preference?")
                .font(.subheadline)
            HStack(spacing: 10) {
                Button("Yes, add it") {
                    homeViewModel.confirmPattern(for: contact)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Not really") {
                    homeViewModel.dismissPattern(for: contact)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor.opacity(0.25), lineWidth: 1))
    }

    private enum ChipSentiment { case like, dislike }

    private func activityChipRow(activities: [Activity], sentiment: ChipSentiment) -> some View {
        FlexibleWrap {
            ForEach(activities, id: \.self) { activity in
                HStack(spacing: 4) {
                    Text(sentiment == .like ? "👍" : "👎")
                        .font(.caption)
                    Text(activity.rawValue)
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    sentiment == .like
                        ? Color.green.opacity(0.12)
                        : Color.red.opacity(0.10),
                    in: Capsule()
                )
                .foregroundStyle(sentiment == .like ? Color.green : Color.red)
                .contextMenu {
                    if sentiment == .like {
                        Button("👎 Mark as not a fit") {
                            homeViewModel.recordDislike(activity, for: contact)
                        }
                    } else {
                        Button("👍 Mark as liked") {
                            homeViewModel.recordLike(activity, for: contact)
                        }
                    }
                    Button("Remove", role: .destructive) {
                        homeViewModel.removeSentiment(for: activity, contact: contact)
                    }
                }
            }
        }
    }

    private func activityAddRow(activities: [Activity]) -> some View {
        FlexibleWrap {
            ForEach(activities, id: \.self) { activity in
                Menu {
                    Button("👍 Like") { homeViewModel.recordLike(activity, for: contact) }
                    Button("👎 Not a fit") { homeViewModel.recordDislike(activity, for: contact) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.bold))
                        Text(activity.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active goals")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if goals.isEmpty {
                Text("No goals yet for \(contact.givenName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(goals) { goal in
                    HStack {
                        Circle()
                            .fill(statusColor(for: goal.status))
                            .frame(width: 8, height: 8)
                        Text(goal.title)
                            .font(.subheadline)
                        Spacer()
                        Text("\(goal.progress)/\(goal.target)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var hangoutHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Interaction history")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if !upcomingHangouts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Upcoming")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(upcomingHangouts) { hangout in
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 18)
                            Text(hangout.resolvedActivity?.rawValue ?? "Hangout")
                                .font(.subheadline)
                            Spacer()
                            Text(hangout.startDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if recentHangouts.isEmpty {
                Text("No hangouts recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if !upcomingHangouts.isEmpty {
                    Text("Past")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(recentHangouts.prefix(10)) { hangout in
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(hangout.resolvedActivity?.rawValue ?? hangout.activity)
                            .font(.subheadline)
                        Spacer()
                        Text(hangout.startDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button { editingHangout = hangout } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            homeViewModel.deleteHangout(hangout)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            let hasPhone = !(contact.phoneNumber ?? "").isEmpty || !(contact.emailAddress ?? "").isEmpty

            if contact.isRemote {
                if hasPhone { checkInButton(prominent: true) }
                Button {
                    showingLogHangout = true
                } label: {
                    Label("Log a hangout", systemImage: "phone").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    showingGoalCreation = true
                } label: {
                    Label("Add a goal", systemImage: "target").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    showingGoalCreation = true
                } label: {
                    Label("Add a goal", systemImage: "target").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if hasPhone { checkInButton(prominent: false) }

                Button {
                    showingLogHangout = true
                } label: {
                    Label("Log a hangout", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func saveCity() {
        let trimmed = cityText.trimmingCharacters(in: .whitespacesAndNewlines)
        homeViewModel.updateCity(trimmed.isEmpty ? nil : trimmed, for: contact)
    }

    @ViewBuilder
    private func checkInButton(prominent: Bool) -> some View {
        if prominent {
            Button {
                if homeViewModel.hasSetCheckInTemplate { showingCheckIn = true }
                else { showingFirstTimeCheckIn = true }
            } label: {
                Label("Send a check-in", systemImage: "message").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                if homeViewModel.hasSetCheckInTemplate { showingCheckIn = true }
                else { showingFirstTimeCheckIn = true }
            } label: {
                Label("Send a check-in", systemImage: "message").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Helpers

    private var initials: String {
        let first = contact.givenName.prefix(1)
        let last = contact.familyName.prefix(1)
        return "\(first)\(last)".uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        return colors[abs(contact.id.hashValue) % colors.count]
    }

    private func statusColor(for status: GoalStatus) -> Color {
        switch status {
        case .onTrack:  return Color(red: 0.2, green: 0.7,  blue: 0.45)
        case .atRisk:   return Color(red: 0.9, green: 0.65, blue: 0.1)
        case .behind:   return Color(red: 0.85, green: 0.35, blue: 0.28)
        case .achieved: return Color(red: 0.3, green: 0.55, blue: 0.9)
        }
    }
}

// MARK: - FlexibleWrap layout

/// Simple wrapping layout for activity chips.
private struct FlexibleWrap<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        // Use a LazyVGrid with adaptive columns for wrapping chip behaviour.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100), spacing: 6)],
            alignment: .leading,
            spacing: 6
        ) {
            content
        }
    }
}
