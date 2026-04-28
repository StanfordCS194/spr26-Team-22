import SwiftUI

/// Shared sheet for creating and editing a scheduled hangout.
///
/// All form state is local. The caller decides what to do with the
/// submitted values via `onSend` — add vs. edit behavior is handled at the call site.
struct HangoutFormSheet: View {
    let contacts: [TrackedContact]
    let displayName: (TrackedContact) -> String
    let editingHangout: ScheduledHangout?
    let onSend: (TrackedContact, Activity, DateInterval) -> Void

    @State private var selectedContact: TrackedContact?
    @State private var selectedActivity: Activity
    @State private var startDate: Date
    @State private var endDate: Date

    @Environment(\.dismiss) private var dismiss

    init(
        contacts: [TrackedContact],
        displayName: @escaping (TrackedContact) -> String,
        editingHangout: ScheduledHangout? = nil,
        onSend: @escaping (TrackedContact, Activity, DateInterval) -> Void
    ) {
        self.contacts = contacts
        self.displayName = displayName
        self.editingHangout = editingHangout
        self.onSend = onSend

        if let h = editingHangout {
            _selectedContact = State(initialValue: h.contact)
            _selectedActivity = State(initialValue: h.resolvedActivity ?? .coffee)
            _startDate = State(initialValue: h.startDate)
            _endDate = State(initialValue: h.endDate)
        } else {
            let defaultStart = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
            let defaultEnd = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now
            _selectedContact = State(initialValue: nil)
            _selectedActivity = State(initialValue: .coffee)
            _startDate = State(initialValue: defaultStart)
            _endDate = State(initialValue: defaultEnd)
        }
    }

    private var isValid: Bool {
        selectedContact != nil && endDate > startDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who") {
                    Picker("Contact", selection: $selectedContact) {
                        Text("Select a contact")
                            .foregroundStyle(.secondary)
                            .tag(Optional<TrackedContact>(nil))
                        ForEach(contacts) { contact in
                            Text(displayName(contact))
                                .tag(Optional(contact))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("Activity") {
                    Picker("Activity", selection: $selectedActivity) {
                        ForEach(Activity.allCases, id: \.self) { activity in
                            Text(activity.rawValue).tag(activity)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("When") {
                    DatePicker(
                        "Starts",
                        selection: $startDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    DatePicker(
                        "Ends",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle(editingHangout == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        guard let contact = selectedContact else { return }
                        onSend(contact, selectedActivity, DateInterval(start: startDate, end: endDate))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
