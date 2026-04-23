import Contacts

/// Formats a TrackedContact's name using CNContactFormatter for locale-aware display.
///
/// This is the single place in the app that knows about CNContactFormatter.
/// ViewModels hold a ContactFormatter instance and expose plain Strings to Views —
/// no View should ever call CNContactFormatter directly.
///
/// To change name formatting app-wide, change this struct. To support a user-facing
/// display-name preference, add a `style` parameter to the initialiser.
struct ContactFormatter {
    var style: CNContactFormatterStyle = .fullName

    /// Returns a locale-aware formatted name, falling back to `contact.name` if formatting fails.
    func displayName(for contact: TrackedContact) -> String {
        let cnContact = CNMutableContact()
        cnContact.givenName = contact.givenName
        cnContact.familyName = contact.familyName
        return CNContactFormatter.string(from: cnContact, style: style) ?? contact.name
    }
}
