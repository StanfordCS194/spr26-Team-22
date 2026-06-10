import SwiftUI

struct AddEditEventSheet: View {
    enum Mode {
        case add([TrackedContact])
        case edit(HangoutDisplayItem)
    }

    private enum ActivityInputMode: Hashable {
        case preset
        case custom
    }

    let mode: Mode
    let onSave: (TrackedContact, String, DateInterval) async -> Void
    let onSuggestActivity: (TrackedContact, DateInterval) async throws -> String?
    var conflictChecker: ((DateInterval) -> Bool)?

    @State private var selectedContactID: UUID?
    @State private var activityInputMode: ActivityInputMode = .preset
    @State private var selectedPreset: Activity = .coffee
    @State private var customText: String = ""
    @State private var isGeneratingAI: Bool = false
    @State private var aiGenerationFailed: Bool = false
    @State private var startDate: Date = .now
    @State private var durationHours: Double = 1.0

    @Environment(\.dismiss) private var dismiss

    private static let availableDurations: [Double] = [0.5, 1.0, 1.5, 2.0, 3.0]

    var body: some View {
        NavigationStack {
            Form {
                contactSection
                activitySection
                timeSection
            }
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave || hasConflict)
                }
            }
        }
        .onAppear { configure() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var contactSection: some View {
        Section("With") {
            switch mode {
            case .add(let contacts):
                if contacts.isEmpty {
                    Text("Add friends first to schedule events")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Friend", selection: $selectedContactID) {
                        Text("Select a friend").tag(nil as UUID?)
                        ForEach(contacts) { contact in
                            Text(contact.name).tag(contact.id as UUID?)
                        }
                    }
                }
            case .edit(let item):
                LabeledContent("Friend", value: item.contactName)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activitySection: some View {
        Section("Activity") {
            Picker("Type", selection: $activityInputMode) {
                Text("Preset").tag(ActivityInputMode.preset)
                Text("Custom").tag(ActivityInputMode.custom)
            }
            .pickerStyle(.segmented)

            if activityInputMode == .preset {
                Picker("Activity", selection: $selectedPreset) {
                    ForEach(Activity.allCases) { activity in
                        Text(activity.rawValue).tag(activity)
                    }
                }
                .pickerStyle(.menu)
            } else {
                HStack {
                    TextField("e.g. Go bouldering", text: $customText)
                    if isGeneratingAI {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.leading, 4)
                    } else {
                        Button {
                            generateAISuggestion()
                        } label: {
                            Image(systemName: "sparkles")
                                .foregroundColor(aiSuggestDisabled ? .secondary : .blue)
                        }
                        .buttonStyle(.borderless)
                        .disabled(aiSuggestDisabled)
                        .help("Suggest an activity with AI")
                    }
                }
                if aiGenerationFailed {
                    Text("AI suggestion unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var timeSection: some View {
        Section("When") {
            DatePicker(
                "Start",
                selection: $startDate,
                in: Date.now...,
                displayedComponents: [.date, .hourAndMinute]
            )
            Picker("Duration", selection: $durationHours) {
                Text("30 min").tag(0.5)
                Text("1 hour").tag(1.0)
                Text("1.5 hours").tag(1.5)
                Text("2 hours").tag(2.0)
                Text("3 hours").tag(3.0)
            }
            if hasConflict {
                Label("You already have an event at this time", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Computed helpers

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// The contact to use for AI suggestion generation.
    private var currentContact: TrackedContact? {
        switch mode {
        case .add(let contacts):
            guard let id = selectedContactID else { return nil }
            return contacts.first { $0.id == id }
        case .edit(let item):
            return item.hangout.contact
        }
    }

    private var aiSuggestDisabled: Bool {
        currentContact == nil || aiGenerationFailed
    }

    private var activityValue: String {
        switch activityInputMode {
        case .preset: return selectedPreset.rawValue
        case .custom: return customText.trimmingCharacters(in: .whitespaces)
        }
    }

    private var hasConflict: Bool {
        guard let checker = conflictChecker else { return false }
        return checker(DateInterval(start: startDate, duration: durationHours * 3600))
    }

    private var canSave: Bool {
        let activityValid: Bool = activityInputMode == .preset
            || !customText.trimmingCharacters(in: .whitespaces).isEmpty
        if case .add = mode { return selectedContactID != nil && activityValid }
        return activityValid
    }

    // MARK: - Actions

    private func generateAISuggestion() {
        guard let contact = currentContact else { return }
        let proposedTime = DateInterval(start: startDate, duration: durationHours * 3600)
        isGeneratingAI = true
        Task {
            do {
                let suggestion = try await onSuggestActivity(contact, proposedTime)
                if let suggestion, !suggestion.isEmpty {
                    customText = suggestion
                } else {
                    aiGenerationFailed = true
                }
            } catch {
                aiGenerationFailed = true
            }
            isGeneratingAI = false
        }
    }

    private func configure() {
        switch mode {
        case .add:
            startDate = nextRoundHour()
        case .edit(let item):
            if let preset = item.hangout.resolvedActivity {
                activityInputMode = .preset
                selectedPreset = preset
            } else {
                activityInputMode = .custom
                customText = item.hangout.activity
            }
            let eventStart = item.hangout.startDate
            startDate = eventStart > .now ? eventStart : nextRoundHour()
            let durationSeconds = item.hangout.endDate.timeIntervalSince(item.hangout.startDate)
            let hours = durationSeconds / 3600
            durationHours = Self.availableDurations.min(by: { abs($0 - hours) < abs($1 - hours) }) ?? 1.0
        }
    }

    private func nextRoundHour() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: .now)
        components.hour = (components.hour ?? 0) + 1
        components.minute = 0
        return Calendar.current.date(from: components) ?? .now.addingTimeInterval(3600)
    }

    private func save() {
        let interval = DateInterval(start: startDate, duration: durationHours * 3600)
        switch mode {
        case .add(let contacts):
            guard let id = selectedContactID,
                  let contact = contacts.first(where: { $0.id == id }) else { return }
            Task {
                await onSave(contact, activityValue, interval)
                dismiss()
            }
        case .edit(let item):
            guard let contact = item.hangout.contact else { return }
            dismiss()
            Task {
                await onSave(contact, activityValue, interval)
            }
        }
    }
}
