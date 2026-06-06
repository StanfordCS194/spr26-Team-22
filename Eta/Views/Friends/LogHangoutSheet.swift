import SwiftUI

struct LogHangoutSheet: View {
    let contact: TrackedContact
    let displayName: String
    let onLog: (Activity, Date) -> Void
    let onDismiss: () -> Void

    @State private var step = 1
    @State private var selectedActivity: Activity = .coffee
    @State private var selectedDate: Date = .now

    private var maximumDate: Date { .now }

    var body: some View {
        NavigationStack {
            Group {
                if step == 1 { whenStep } else { whatStep }
            }
            .navigationTitle(step == 1 ? "When?" : "What did you do?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(step == 1 ? "Next" : "Save") {
                        if step == 1 { step = 2 }
                        else { onLog(selectedActivity, selectedDate) }
                    }
                }
            }
        }
    }

    private var whenStep: some View {
        Form {
            Section("When did you hang out?") {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: ...maximumDate,
                    displayedComponents: .date
                )
            }
        }
    }

    private var whatStep: some View {
        Form {
            Section("What did you do?") {
                Picker("Activity", selection: $selectedActivity) {
                    ForEach(Activity.allCases) { activity in
                        Text(activity.rawValue).tag(activity)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }
}
