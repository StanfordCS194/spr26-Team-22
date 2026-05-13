import Foundation

/// Stores the user's own contact identifier (phone or email) for remote invite routing.
final class PhoneSetupService {
    private let defaults = UserDefaults.standard
    private let key = "myContactIdentifier"

    var myIdentifier: String? {
        defaults.string(forKey: key)
    }

    func store(identifier: String) {
        defaults.set(identifier, forKey: key)
    }

    /// Strips non-digits; prepends "1" for 10-digit US numbers → "16505551234".
    /// Returns the original string unchanged if it looks like an email.
    static func normalized(_ raw: String) -> String {
        if raw.contains("@") { return raw.lowercased() }
        let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if digits.count == 10 { return "1" + digits }
        return digits
    }
}
