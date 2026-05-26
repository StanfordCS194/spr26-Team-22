import SwiftUI

struct SettingsView: View {
    let viewModel: SettingsViewModel
    let onDismiss: () -> Void

    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                activitiesSection
                notificationsSection
                dataSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
            .confirmationDialog(
                "Clear all data?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) {
                    viewModel.clearAllData()
                    onDismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all friends, hangouts, goals, and insights. The app will re-seed with example data on next launch.")
            }
        }
    }

    // MARK: - Sections

    private var activitiesSection: some View {
        Section {
            ForEach(Activity.allCases) { activity in
                Toggle(activity.rawValue, isOn: Binding(
                    get: { viewModel.preferences.preferredActivities.contains(activity.rawValue) },
                    set: { isOn in
                        if isOn {
                            if !viewModel.preferences.preferredActivities.contains(activity.rawValue) {
                                viewModel.preferences.preferredActivities.append(activity.rawValue)
                            }
                        } else {
                            viewModel.preferences.preferredActivities.removeAll { $0 == activity.rawValue }
                        }
                    }
                ))
            }
        } header: {
            Text("Favorite Activities")
        } footer: {
            Text("Only selected activities will be suggested.")
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable Notifications", isOn: Binding(
                get: { viewModel.preferences.enableNotifications },
                set: { viewModel.preferences.enableNotifications = $0 }
            ))

            if viewModel.preferences.enableNotifications {
                DatePicker(
                    "Suggestion Time",
                    selection: Binding(
                        get: { viewModel.preferences.notificationTime },
                        set: { viewModel.preferences.notificationTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
        }
    }
}
