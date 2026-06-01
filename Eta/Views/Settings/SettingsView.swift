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
                weeklyCheckInSection
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

    private var weeklyCheckInSection: some View {
        Section {
            Toggle("Enable Weekly Check-In", isOn: Binding(
                get: { viewModel.preferences.weeklyCheckInEnabled },
                set: { newValue in
                    viewModel.preferences.weeklyCheckInEnabled = newValue
                    Task { await viewModel.rescheduleWeeklyCheckIn() }
                }
            ))

            if viewModel.preferences.weeklyCheckInEnabled {
                Picker("Day", selection: Binding(
                    get: { viewModel.preferences.weeklyCheckInDay },
                    set: { newValue in
                        viewModel.preferences.weeklyCheckInDay = newValue
                        Task { await viewModel.rescheduleWeeklyCheckIn() }
                    }
                )) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Tuesday").tag(3)
                    Text("Wednesday").tag(4)
                    Text("Thursday").tag(5)
                    Text("Friday").tag(6)
                    Text("Saturday").tag(7)
                }

                DatePicker(
                    "Time",
                    selection: Binding(
                        get: { viewModel.preferences.weeklyCheckInTime },
                        set: { newValue in
                            viewModel.preferences.weeklyCheckInTime = newValue
                            Task { await viewModel.rescheduleWeeklyCheckIn() }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Text("Weekly Check-In")
        } footer: {
            Text("A notification reminds you to review your friendships and set a weekly priority.")
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
