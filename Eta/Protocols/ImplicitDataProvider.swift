import Foundation

/// Supplies raw hangout events derived from an implicit data source.
///
/// Future examples could include social APIs or other on-device activity sources.
/// Add new sources by conforming to this protocol — no changes to RelationshipService needed.
protocol ImplicitDataProvider {
    /// Fetches events involving any of the given contacts on or after `since`.
    func fetchEvents(for contacts: [TrackedContact], since date: Date) async throws -> [HangoutEvent]

    /// Requests access to the underlying data source. Returns true if access was granted.
    func requestAccess() async -> Bool
}
