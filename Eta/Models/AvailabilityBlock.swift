//  Created by Lauren Hamilton on 5/12/26.
//

import Foundation

/// A user-entered span of time when the user is free to schedule hangouts.
struct AvailabilityBlock: Identifiable, Codable, Equatable {

    /// Stable identifier used by SwiftUI lists and removal actions.
    let id: UUID
    /// The beginning of the free-time window.
    var startTime: Date
    /// The end of the free-time window.
    var endTime: Date

    /// Creates a free-time block, defaulting to a new identifier for newly entered availability.
    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }
}
