import Foundation
import SwiftData

@Model
final class TrackedContact {
    var id: UUID
    var cnContactIdentifier: String
    /// Pre-formatted display name — fast fallback when CNContactFormatter is unavailable.
    var name: String
    /// Raw name components — used by ContactFormatter for locale-aware display.
    var givenName: String
    var familyName: String
    var phoneNumber: String?
    var emailAddress: String?
    var isActive: Bool
    var addedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ScheduledHangout.contact)
    var hangouts: [ScheduledHangout] = []

    init(
        id: UUID = UUID(),
        cnContactIdentifier: String,
        name: String,
        givenName: String,
        familyName: String,
        phoneNumber: String? = nil,
        emailAddress: String? = nil,
        isActive: Bool = true,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.cnContactIdentifier = cnContactIdentifier
        self.name = name
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumber = phoneNumber
        self.emailAddress = emailAddress
        self.isActive = isActive
        self.addedAt = addedAt
    }
}
