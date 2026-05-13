import SwiftUI

struct SuggestionDetailSheet: View {
    let displayName: String
    let reason: String
    let initialActivity: String
    let initialTime: Date
    let onConfirm: (String, Date) -> Void
    let onDismiss: () -> Void

    @State private var selectedActivity: String
    @State private var selectedTime: Date

    init(
        displayName: String,
        reason: String,
        initialActivity: String,
        initialTime: Date,
        onConfirm: @escaping (String, Date) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.displayName = displayName
        self.reason = reason
        self.initialActivity = initialActivity
        self.initialTime = initialTime
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        _selectedActivity = State(initialValue: initialActivity)
        _selectedTime = State(initialValue: initialTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("With \(displayName)")
                            .font(.headline)
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Activity") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(Activity.allCases) { activity in
                            ActivityChip(
                                label: activity.description,
                                isSelected: selectedActivity == activity.description
                            ) {
                                selectedActivity = activity.description
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("When") {
                    DatePicker(
                        "Date & time",
                        selection: $selectedTime,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onConfirm(selectedActivity, selectedTime)
                    }
                }
            }
            .onChange(of: initialActivity) { _, newActivity in
                selectedActivity = newActivity
            }
        }
    }
}

private struct ActivityChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color(.separator), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
