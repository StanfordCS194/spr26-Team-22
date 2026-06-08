import SwiftUI

struct AddEditEventSheet: View {
    enum Mode {
        case add([TrackedContact])
        case edit(HangoutDisplayItem)
    }

    let mode: Mode
    let onSave: (TrackedContact, String, DateInterval) async -> Void

    @State private var selectedContactID: UUID?
    @State private var selectedActivity: Activity = .coffee
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
                        .disabled(!canSave)
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
            Picker("Activity", selection: $selectedActivity) {
                ForEach(Activity.allCases) { activity in
                    Text(activity.rawValue).tag(activity)
                }
            }
            .pickerStyle(.menu)
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
        }
    }

    // MARK: - Helpers

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        if case .add = mode { return selectedContactID != nil }
        return true
    }

    private func configure() {
        switch mode {
        case .add:
            startDate = nextRoundHour()
        case .edit(let item):
            selectedActivity = item.hangout.resolvedActivity ?? .coffee
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
                await onSave(contact, selectedActivity.rawValue, interval)
                dismiss()
            }
        case .edit(let item):
            guard let contact = item.hangout.contact else { return }
            Task {
                await onSave(contact, selectedActivity.rawValue, interval)
                dismiss()
            }
        }
    }
}
