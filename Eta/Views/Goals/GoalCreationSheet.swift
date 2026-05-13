import SwiftUI

struct GoalCreationSheet: View {
    let contacts: [TrackedContact]
    let formatter: ContactFormatter
    var preselectedContact: TrackedContact? = nil
    var health: RelationshipHealth? = nil
    var likedActivities: [Activity] = []
    let onGoalCreated: (Goal) -> Void

    @Environment(\.dismiss) private var dismiss

    private let frequencyOptions: [(label: String, cadence: GoalCadence, target: Int)] = [
        ("Once a week",    .weekly,    1),
        ("Twice a month",  .monthly,   2),
        ("Once a month",   .monthly,   1),
        ("Once a quarter", .quarterly, 1),
    ]

    @State private var selectedFrequencyIndex: Int? = nil
    @State private var useCustomFrequency = false
    @State private var customCadence: GoalCadence = .monthly
    @State private var customTarget: Int = 2
    @State private var titleText: String = ""
    @State private var notesText: String = ""
    @State private var selectedFriendIDs: Set<UUID>

    init(
        contacts: [TrackedContact],
        formatter: ContactFormatter,
        preselectedContact: TrackedContact? = nil,
        health: RelationshipHealth? = nil,
        likedActivities: [Activity] = [],
        onGoalCreated: @escaping (Goal) -> Void
    ) {
        self.contacts = contacts
        self.formatter = formatter
        self.preselectedContact = preselectedContact
        self.health = health
        self.likedActivities = likedActivities
        self.onGoalCreated = onGoalCreated
        _selectedFriendIDs = State(initialValue: preselectedContact.map { [$0.id] } ?? [])
    }

    private var effectiveCadence: GoalCadence {
        if useCustomFrequency { return customCadence }
        guard let i = selectedFrequencyIndex else { return .monthly }
        return frequencyOptions[i].cadence
    }

    private var effectiveTarget: Int {
        if useCustomFrequency { return customTarget }
        guard let i = selectedFrequencyIndex else { return 1 }
        return frequencyOptions[i].target
    }

    private var friendName: String {
        if let pre = preselectedContact { return pre.givenName }
        if let firstID = selectedFriendIDs.first,
           let contact = contacts.first(where: { $0.id == firstID }) {
            return contact.givenName
        }
        return ""
    }

    private var canSave: Bool {
        !titleText.trimmingCharacters(in: .whitespaces).isEmpty &&
        (selectedFrequencyIndex != nil || useCustomFrequency)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let contact = preselectedContact {
                        friendChip(contact: contact)
                    }

                    frequencySection

                    titleSection

                    notesSection
                }
                .padding()
                .padding(.bottom, 100)
            }
            .overlay(alignment: .bottom) {
                saveButton
            }
            .navigationTitle("Set a Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { applyDefaults() }
        }
    }

    // MARK: - Friend chip

    private func friendChip(contact: TrackedContact) -> some View {
        HStack(spacing: 8) {
            let initials = "\(contact.givenName.prefix(1))\(contact.familyName.prefix(1))".uppercased()
            Text(initials)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(avatarColor(for: contact), in: Circle())
            Text(formatter.displayName(for: contact))
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1), in: Capsule())
    }

    // MARK: - Frequency

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How often?")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(frequencyOptions.indices, id: \.self) { i in
                    let option = frequencyOptions[i]
                    let isSelected = selectedFrequencyIndex == i && !useCustomFrequency
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedFrequencyIndex = i
                            useCustomFrequency = false
                        }
                        if titleText.isEmpty {
                            titleText = suggestTitle(cadence: option.cadence, target: option.target)
                        }
                    } label: {
                        frequencyRow(label: option.label, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        useCustomFrequency = true
                        selectedFrequencyIndex = nil
                    }
                } label: {
                    frequencyRow(label: "Custom", isSelected: useCustomFrequency)
                }
                .buttonStyle(.plain)

                if useCustomFrequency {
                    customFrequencyControls
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func frequencyRow(label: String, isSelected: Bool) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
        }
        .padding(14)
        .background(
            isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var customFrequencyControls: some View {
        VStack(spacing: 12) {
            Picker("Cadence", selection: $customCadence) {
                ForEach(GoalCadence.allCases, id: \.self) { c in
                    Text(c.rawValue.capitalized).tag(c)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Times per \(customCadence.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper("\(customTarget)", value: $customTarget, in: 1...20)
                    .labelsHidden()
                Text("\(customTarget)×")
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 28, alignment: .trailing)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal title")
                .font(.headline)

            TextField(
                suggestTitle(cadence: effectiveCadence, target: effectiveTarget),
                text: $titleText
            )
            .textFieldStyle(.plain)
            .font(.subheadline)
            .padding(14)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            // Liked activity chips — tap one to rewrite the title using that activity
            if !likedActivities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Based on their preferences:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(likedActivities, id: \.self) { activity in
                                Button {
                                    let timesStr = effectiveTarget == 1 ? "once" : "\(effectiveTarget) times"
                                    if friendName.isEmpty {
                                        titleText = "\(activity.rawValue) \(timesStr) a \(effectiveCadence.displayName)"
                                    } else {
                                        titleText = "\(activity.rawValue) with \(friendName) \(timesStr) a \(effectiveCadence.displayName)"
                                    }
                                } label: {
                                    Text(activity.rawValue)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.accentColor.opacity(0.09), in: Capsule())
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.headline)
            TextField(
                "Why is this goal important to you? (optional)",
                text: $notesText,
                axis: .vertical
            )
            .lineLimit(3...)
            .textFieldStyle(.plain)
            .font(.subheadline)
            .padding(14)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button {
            let title = titleText.trimmingCharacters(in: .whitespaces).isEmpty
                ? suggestTitle(cadence: effectiveCadence, target: effectiveTarget)
                : titleText.trimmingCharacters(in: .whitespaces)
            let goal = buildGoal(
                title: title,
                friendIDs: Array(selectedFriendIDs),
                cadence: effectiveCadence,
                target: effectiveTarget
            )
            onGoalCreated(goal)
            dismiss()
        } label: {
            Text("Save Goal")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    canSave ? Color.accentColor : Color.secondary.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
        }
        .disabled(!canSave)
        .padding(.horizontal)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
    }

    // MARK: - Default selection on appear

    private func applyDefaults() {
        guard let health else { return }
        let index = suggestFrequencyIndex(for: health)
        selectedFrequencyIndex = index
        if let i = index {
            let option = frequencyOptions[i]
            titleText = suggestTitle(cadence: option.cadence, target: option.target)
        }
    }

    private func suggestFrequencyIndex(for health: RelationshipHealth) -> Int? {
        let count = health.hangoutCount
        if count >= 8 { return 0 } // Once a week  (~weekly over 90 days)
        if count >= 4 { return 1 } // Twice a month
        if count >= 2 { return 2 } // Once a month
        if count == 1 { return 3 } // Once a quarter
        return nil                 // No history — let the user choose
    }

    // MARK: - Helpers

    private func suggestTitle(cadence: GoalCadence, target: Int) -> String {
        let timesStr = target == 1 ? "once" : "\(target) times"
        if let topActivity = likedActivities.first {
            if friendName.isEmpty {
                return "\(topActivity.rawValue) \(timesStr) a \(cadence.displayName)"
            }
            return "\(topActivity.rawValue) with \(friendName) \(timesStr) a \(cadence.displayName)"
        }
        if friendName.isEmpty {
            return "Hang out \(timesStr) a \(cadence.displayName)"
        }
        return "See \(friendName) \(timesStr) a \(cadence.displayName)"
    }

    private func avatarColor(for contact: TrackedContact) -> Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        return colors[abs(contact.id.hashValue) % colors.count]
    }

    // MARK: - Goal builder

    private func buildGoal(title: String, friendIDs: [UUID], cadence: GoalCadence, target: Int) -> Goal {
        let cal = Calendar.current
        let now = Date()
        let windowStart = now
        let windowEnd: Date

        switch cadence {
        case .weekly:
            windowEnd = cal.date(byAdding: .weekOfYear, value: 1, to: windowStart) ?? now
        case .monthly:
            windowEnd = cal.date(byAdding: .month, value: 1, to: windowStart) ?? now
        case .quarterly:
            windowEnd = cal.date(byAdding: .month, value: 3, to: windowStart) ?? now
        }

        return Goal(
            title: title,
            friendIDs: friendIDs,
            cadence: cadence,
            target: target,
            windowStart: windowStart,
            windowEnd: windowEnd,
            source: .manual
        )
    }
}
