import SwiftUI

struct SettingsView: View {
    let viewModel: SettingsViewModel
    let onDismiss: () -> Void
    let analyticsService: AnalyticsService

    @State private var showingClearConfirmation = false
    @State private var cityText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                activitiesSection
                notificationsSection
                weeklyCheckInSection
                dataSection
            }
            .onAppear {
                cityText = viewModel.preferences.userCity ?? ""
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
        .trackScreen("SettingsView", analytics: analyticsService)
    }

    // MARK: - Sections

    private var locationSection: some View {
        Section {
            CitySearchField(city: $cityText,
                onCommit: { viewModel.updateUserCity($0) },
                onCoordinates: { viewModel.updateUserCoordinates($0, $1) })
        } header: {
            Text("Your Location")
        } footer: {
            Text("Contacts in the same city are shown as in-person. Others are shown as online.")
        }
    }

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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Nudge frequency")
                        Spacer()
                        Text(nudgeFrequencyLabel(viewModel.preferences.nudgeFrequencyDays))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.preferences.nudgeFrequencyDays) },
                            set: { viewModel.preferences.nudgeFrequencyDays = Int($0.rounded()) }
                        ),
                        in: 1...7,
                        step: 1
                    )
                }
            }
        }
    }

    private func nudgeFrequencyLabel(_ days: Int) -> String {
        switch days {
        case 1: return "Daily"
        case 7: return "Weekly"
        default: return "Every \(days) days"
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
