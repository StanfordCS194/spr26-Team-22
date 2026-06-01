import Foundation

@Observable
final class SettingsViewModel {
    private let preferencesService: PreferencesService
    private let onClearAll: () -> Void

    var preferences: UserPreferences {
        get { preferencesService.preferences }
        set { preferencesService.updatePreferences(newValue) }
    }

    init(preferencesService: PreferencesService, onClearAll: @escaping () -> Void) {
        self.preferencesService = preferencesService
        self.onClearAll = onClearAll
    }

    func updateUserCity(_ city: String?) {
        preferencesService.updateUserCity(city)
    }

    func updateUserCoordinates(_ latitude: Double, _ longitude: Double) {
        preferencesService.updateUserCoordinates(latitude, longitude)
    }

    func clearAllData() {
        onClearAll()
    }
}
