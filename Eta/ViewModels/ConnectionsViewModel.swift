import Foundation
import Contacts

/// A display-only projection of a CNContact for use in the contact picker.
///
/// Views receive this type instead of CNContact directly, so they never need
/// to import Contacts or touch CNContact properties.
struct ContactPickerItem: Identifiable {
    let id: String          // CNContact.identifier
    let displayName: String
}

/// Drives ConnectionsView and AddConnectionSheet.
///
/// Owns the CNContactStore instance used for contact loading and permission requests.
/// CNContact is an implementation detail — Views only ever see TrackedContact,
/// plain Strings, and ContactPickerItem.
@Observable
final class ConnectionsViewModel {
    private(set) var contacts: [TrackedContact] = []
    /// Filtered slice of the address book — updated synchronously as the search query changes.
    private(set) var searchResults: [ContactPickerItem] = []
    private(set) var isPermissionDenied: Bool = false
    /// True while the initial full-contact fetch is in flight.
    private(set) var isLoadingContacts: Bool = false
    /// Health scores keyed by TrackedContact.id for O(1) per-row lookup.
    private(set) var healthScores: [UUID: RelationshipHealth] = [:]

    /// Full address book minus already-tracked contacts. Source of truth for filtering.
    private var allCNContacts: [CNContact] = []
    /// Keyed by CNContact.identifier for O(1) lookup when committing selections.
    private var cnContactIndex: [String: CNContact] = [:]

    private let repository: ContactRepository
    private let formatter: ContactFormatter
    private let relationshipService: RelationshipService
    private let contactStore = CNContactStore()

    init(repository: ContactRepository, formatter: ContactFormatter, relationshipService: RelationshipService) {
        self.repository = repository
        self.formatter = formatter
        self.relationshipService = relationshipService
    }

    // MARK: - Display

    func displayName(for contact: TrackedContact) -> String {
        formatter.displayName(for: contact)
    }

    private func displayName(for cnContact: CNContact) -> String {
        CNContactFormatter.string(from: cnContact, style: .fullName)
            ?? [cnContact.givenName, cnContact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
    }

    private func pickerItem(for cnContact: CNContact) -> ContactPickerItem {
        ContactPickerItem(id: cnContact.identifier, displayName: displayName(for: cnContact))
    }

    // MARK: - Tracked contacts

    func loadContacts() {
        contacts = (try? repository.fetchAll()) ?? []
        if contacts.isEmpty {
            print("loadContacts failed...")
        } else {
            print("loadContacts found \(contacts.count) contacts!")
        }
    }

    func removeContact(_ contact: TrackedContact) {
        try? repository.remove(contact)
        loadContacts()
    }

    // MARK: - Relationship health

    /// Fetches health scores for all tracked contacts via RelationshipService.
    func loadHealthScores() async {
        let scores = await relationshipService.computeHealth()
        healthScores = Dictionary(uniqueKeysWithValues: scores.map { ($0.contact.id, $0) })
    }

    /// Returns a human-readable summary of when the user last hung out with this contact,
    /// or nil if health data hasn't been loaded yet.
    func healthLabel(for contact: TrackedContact) -> String? {
        guard let health = healthScores[contact.id] else { return nil }

        if let upcoming = health.upcomingHangout {
            let activity = upcoming.activity.prefix(1).lowercased() + upcoming.activity.dropFirst()
            let df = DateFormatter()
            df.dateFormat = "EEE, MMM d"
            return "Upcoming: \(activity) · \(df.string(from: upcoming.startDate))"
        }

        guard let days = health.daysSinceLastHangout else {
            return "No hangouts on record"
        }

        let titleSuffix: String
        if let title = health.lastHangoutTitle, !title.isEmpty {
            let downcased = title.prefix(1).lowercased() + title.dropFirst()
            titleSuffix = " at \(downcased)"
        } else {
            titleSuffix = ""
        }

        switch days {
        case 0:  return "Seen today\(titleSuffix)"
        case 1:  return "Seen yesterday\(titleSuffix)"
        default: return "Last seen \(days) days ago\(titleSuffix)"
        }
    }

    // MARK: - Contact picker (CNContactStore)

    /// Requests Contacts permission. Sets `isPermissionDenied` if refused.
    func requestContactsAccess() async {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized, .limited:
            isPermissionDenied = false
        case .denied, .restricted:
            isPermissionDenied = true
        case .notDetermined:
            do {
                let granted = try await contactStore.requestAccess(for: .contacts)
                isPermissionDenied = !granted
            } catch {
                isPermissionDenied = true
            }
        @unknown default:
            isPermissionDenied = true
        }
    }

    /// Fetches the full address book once, filters out already-tracked contacts,
    /// and populates `searchResults` with all remaining contacts as ContactPickerItems.
    ///
    /// Call this after `requestContactsAccess()` resolves with permission granted.
    func loadAllContacts() async {
        guard !isPermissionDenied else { return }

        isLoadingContacts = true
        defer { isLoadingContacts = false }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
        ]

        do {
            var fetched: [CNContact] = []
            // Enumerate across all containers to cover iCloud, local, Exchange, etc.
            let containers = try contactStore.containers(matching: nil)
            for container in containers {
                let predicate = CNContact.predicateForContactsInContainer(
                    withIdentifier: container.identifier
                )
                let batch = try contactStore.unifiedContacts(
                    matching: predicate,
                    keysToFetch: keysToFetch
                )
                fetched.append(contentsOf: batch)
            }

            // Remove duplicates that can appear across containers after unification.
            var seen = Set<String>()
            fetched = fetched.filter { seen.insert($0.identifier).inserted }

            // Filter out contacts already tracked, then sort alphabetically.
            let trackedIdentifiers = Set(contacts.map(\.cnContactIdentifier))
            allCNContacts = fetched
                .filter { !trackedIdentifiers.contains($0.identifier) }
                .sorted { displayName(for: $0) < displayName(for: $1) }

            cnContactIndex = Dictionary(uniqueKeysWithValues: allCNContacts.map { ($0.identifier, $0) })
            searchResults = allCNContacts.map(pickerItem)
        } catch {
            allCNContacts = []
            cnContactIndex = [:]
            searchResults = []
        }
    }

    /// Filters the address book by `query` and updates `searchResults` synchronously.
    /// Pass an empty string to show all contacts.
    func searchContacts(query: String) {
        if query.isEmpty {
            searchResults = allCNContacts.map(pickerItem)
        } else {
            let lower = query.lowercased()
            searchResults = allCNContacts
                .filter { displayName(for: $0).lowercased().contains(lower) }
                .map(pickerItem)
        }
    }

    /// Resolves the given picker items back to CNContacts, persists them as
    /// TrackedContacts, then removes them from the picker pool.
    func addContacts(_ items: [ContactPickerItem]) {
        let cnContacts = items.compactMap { cnContactIndex[$0.id] }

        for cnContact in cnContacts {
            let contact = TrackedContact(
                cnContactIdentifier: cnContact.identifier,
                name: displayName(for: cnContact),
                givenName: cnContact.givenName,
                familyName: cnContact.familyName,
                phoneNumber: cnContact.phoneNumbers.first?.value.stringValue,
                emailAddress: cnContact.emailAddresses.first?.value as String?
            )
            try? repository.add(contact)
        }

        loadContacts()

        let addedIds = Set(items.map(\.id))
        allCNContacts.removeAll { addedIds.contains($0.identifier) }
        cnContactIndex = cnContactIndex.filter { !addedIds.contains($0.key) }
        searchResults.removeAll { addedIds.contains($0.id) }
    }
}
