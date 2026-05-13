//
//  LocalAvailabilityProvider.swift
//  Eta
//
//  Created by Lauren Hamilton on 5/12/26.
//
import Foundation

/// Simple availability provider that reads saved blocks without scheduling-specific trimming.
final class LocalAvailabilityProvider: AvailabilityProvider {
    private let repository: AvailabilityRepository

    /// Creates a provider backed by the supplied availability repository.
    init(repository: AvailabilityRepository) {
        self.repository = repository
    }

    /// Returns saved free-time blocks that start on the requested date.
    func fetchAvailability(for date: Date) async throws -> [AvailabilityBlock] {
        let all = try await repository.fetch()

        return all.filter {
            Calendar.current.isDate($0.startTime, inSameDayAs: date)
        }
    }
}
