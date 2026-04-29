//
//  OnboardingModels.swift
//  Eta
//

import Foundation
import SwiftUI

// MARK: - Activity Types

enum ActivityType: String, CaseIterable, Codable, Identifiable {
    case coffee    = "Coffee"
    case dinner    = "Dinner"
    case walks     = "Walks"
    case games     = "Game Night"
    case movies    = "Movies"
    case drinks    = "Drinks"
    case workouts  = "Workouts"
    case travel    = "Travel"
    case concerts  = "Concerts"
    case cooking   = "Cooking"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .coffee:   return "cup.and.saucer.fill"
        case .dinner:   return "fork.knife"
        case .walks:    return "figure.walk"
        case .games:    return "gamecontroller.fill"
        case .movies:   return "film.fill"
        case .drinks:   return "wineglass.fill"
        case .workouts: return "figure.run"
        case .travel:   return "airplane"
        case .concerts: return "music.note"
        case .cooking:  return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .coffee:   return .brown
        case .dinner:   return .orange
        case .walks:    return .green
        case .games:    return .purple
        case .movies:   return .red
        case .drinks:   return .pink
        case .workouts: return .blue
        case .travel:   return .teal
        case .concerts: return .indigo
        case .cooking:  return .yellow
        }
    }
}

// MARK: - Hangout Frequency

enum HangoutFrequency: String, CaseIterable, Codable, Identifiable {
    case weekly     = "Weekly"
    case biweekly   = "Every 2 Weeks"
    case monthly    = "Monthly"
    case quarterly  = "Quarterly"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .weekly:    return "calendar.circle.fill"
        case .biweekly:  return "calendar.badge.clock"
        case .monthly:   return "calendar"
        case .quarterly: return "calendar.badge.minus"
        }
    }

    var subtitle: String {
        switch self {
        case .weekly:    return "You like staying very close"
        case .biweekly:  return "Regular check-ins feel right"
        case .monthly:   return "Once a month keeps the bond strong"
        case .quarterly: return "Quality over quantity"
        }
    }

    var days: Int {
        switch self {
        case .weekly:    return 7
        case .biweekly:  return 14
        case .monthly:   return 30
        case .quarterly: return 90
        }
    }
}

// MARK: - Onboarding Preferences

struct OnboardingPreferences {
    var favoriteActivities: Set<ActivityType> = []
    var defaultFrequency: HangoutFrequency = .monthly
    var selectedContacts: [OnboardingContact] = []
}

struct OnboardingContact: Identifiable, Hashable {
    let id: String          // CNContact identifier
    let givenName: String
    let familyName: String
    let phoneNumber: String?
    var desiredFrequency: HangoutFrequency? // nil = use default

    var fullName: String { "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces) }
    var initials: String {
        let g = givenName.prefix(1)
        let f = familyName.prefix(1)
        return "\(g)\(f)".uppercased()
    }
}
