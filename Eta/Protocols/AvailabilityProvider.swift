//
//  AvailabilityProvider.swift
//  Eta
//
//  Created by Lauren Hamilton on 5/12/26.
//
import Foundation

/// Supplies user-entered availability blocks for scheduling suggestions.
protocol AvailabilityProvider {
    /// Returns availability blocks that fall on the requested date.
    func fetchAvailability(for date: Date) async throws -> [AvailabilityBlock]
}
