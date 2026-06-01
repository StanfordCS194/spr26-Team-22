import SwiftUI

struct LogHangoutSheet: View {
    let contact: TrackedContact
    let displayName: String
    var isRemote: Bool = false
    let onLog: (String, Date) -> Void
    let onDismiss: () -> Void

    @State private var step = 1
    @State private var selectedActivity: Activity
    @State private var selectedDate: Date
    @State private var isOther: Bool
    @State private var otherText: String

    init(
        contact: TrackedContact,
        displayName: String,
        isRemote: Bool = false,
        initialActivity: String? = nil,
        initialDate: Date? = nil,
        onLog: @escaping (String, Date) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.contact = contact
        self.displayName = displayName
        self.isRemote = isRemote
        self.onLog = onLog
        self.onDismiss = onDismiss

        let date = initialDate ?? .now
        _selectedDate = State(initialValue: date)

        if let raw = initialActivity, let resolved = Activity(rawValue: raw) {
            _selectedActivity = State(initialValue: resolved)
            _isOther = State(initialValue: false)
            _otherText = State(initialValue: "")
        } else if let raw = initialActivity {
            _selectedActivity = State(initialValue: .coffee)
            _isOther = State(initialValue: true)
            _otherText = State(initialValue: raw)
        } else {
            _selectedActivity = State(initialValue: .coffee)
            _isOther = State(initialValue: false)
            _otherText = State(initialValue: "")
        }
    }

    private var maximumDate: Date { .now }

    var body: some View {
        NavigationStack {
            Group {
                if step == 1 { whenStep } else { whatStep }
            }
            .navigationTitle(step == 1 ? "When?" : (isRemote ? "How did you connect?" : "What did you do?"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(step == 1 ? "Next" : "Save") {
                        if step == 1 { step = 2 }
                        else {
                            let activityString = isOther ? otherText : selectedActivity.rawValue
                            onLog(activityString, selectedDate)
                        }
                    }
                    .disabled(step == 2 && isOther && otherText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var whenStep: some View {
        Form {
            Section(isRemote ? "When did you catch up?" : "When did you hang out?") {
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
            Section(isRemote ? "How did you connect?" : "What did you do?") {
                ForEach(Activity.allCases, id: \.rawValue) { (activity: Activity) in
                    Button {
                        selectedActivity = activity
                        isOther = false
                    } label: {
                        HStack {
                            Text(activity.pastTense)
                                .foregroundStyle(.primary)
                            Spacer()
                            if !isOther && selectedActivity == activity {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isOther = true
                } label: {
                    HStack {
                        Text("Something else")
                            .foregroundStyle(.primary)
                        Spacer()
                        if isOther {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)

                if isOther {
                    TextField("e.g. Went to a concert", text: $otherText)
                        .font(.subheadline)
                }
            }
        }
    }
}
