//
//  UserDefaultsAvailabilityRepository.swift
//  Eta
//
//  Created by Lauren Hamilton on 5/12/26.
//


import Foundation

/// Stores availability blocks locally in `UserDefaults`.
final class UserDefaultsAvailabilityRepository: AvailabilityRepository {

    private let key = "availability.blocks"

    /// Decodes all saved availability blocks, returning an empty array when none exist yet.
    func fetch() async throws -> [AvailabilityBlock] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }

        return try JSONDecoder().decode([AvailabilityBlock].self, from: data)
    }

    /// Encodes and persists the complete availability block collection.
    func save(_ blocks: [AvailabilityBlock]) async throws {
        let data = try JSONEncoder().encode(blocks)
        UserDefaults.standard.set(data, forKey: key)
    }
}
