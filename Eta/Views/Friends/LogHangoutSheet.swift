import SwiftUI

struct LogHangoutSheet: View {
    let contact: TrackedContact
    let displayName: String
    var isRemote: Bool = false
    let onLog: (String, Date) -> Void
    let onDismiss: () -> Void

    @State private var step = 1
    @State private var selectedActivity: Activity = .coffee
    @State private var selectedDate: Date = .now
    @State private var isOther = false
    @State private var otherText = ""

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
