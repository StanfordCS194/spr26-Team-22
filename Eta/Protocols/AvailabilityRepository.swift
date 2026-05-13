//  Created by Lauren Hamilton on 5/12/26.
//


import Foundation

/// Persistence boundary for user-entered availability blocks.
protocol AvailabilityRepository {
    /// Loads every saved availability block.
    func fetch() async throws -> [AvailabilityBlock]
    /// Replaces the saved availability block collection.
    func save(_ blocks: [AvailabilityBlock]) async throws
}
