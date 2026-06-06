import Foundation

@Observable
final class SettingsViewModel {
    private let preferencesService: PreferencesService
    private let weeklyCheckInService: WeeklyCheckInService
    private let onClearAll: () -> Void

    var preferences: UserPreferences {
        get { preferencesService.preferences }
        set { preferencesService.updatePreferences(newValue) }
    }

    init(
        preferencesService: PreferencesService,
        weeklyCheckInService: WeeklyCheckInService,
        onClearAll: @escaping () -> Void
    ) {
        self.preferencesService = preferencesService
        self.weeklyCheckInService = weeklyCheckInService
        self.onClearAll = onClearAll
    }

    func rescheduleWeeklyCheckIn() async {
        await weeklyCheckInService.reschedule()
    }

    func clearAllData() {
        preferencesService.clearWeeklyData()
        onClearAll()
    }
}
