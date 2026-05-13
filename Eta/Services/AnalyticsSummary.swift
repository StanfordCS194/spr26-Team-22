//
//  AnalyticsSummary.swift
//  Eta
//
//  Created on 4/23/26.
//

import Foundation

/// Pre-computed summary statistics for all analytics data.
/// This is exported as summary_stats.json for easy insights without coding.
struct AnalyticsSummary {
    let totalSessions: Int
    let totalUsers: Int
    let dateRange: DateRange
    let permissions: PermissionStats
    let onboarding: OnboardingStats
    let connections: ConnectionStats
    let suggestions: SuggestionStats
    let invitations: InvitationStats
    let screenTime: [String: ScreenTimeStats]
    let navigationFlows: NavigationFlowStats
    
    struct DateRange {
        let start: Date
        let end: Date
    }
    
    struct PermissionStats {
        let contacts: PermissionDetail
        
        struct PermissionDetail {
            let requested: Int
            let granted: Int
            let denied: Int
            let grantRate: Double
            let avgTimeToGrant: Double
            let selectionType: [String: Int]? // For contacts: "all" vs "selected"
        }
    }
    
    struct OnboardingStats {
        let avgDuration: Double
        let completionRate: Double
    }
    
    struct ConnectionStats {
        let totalAdded: Int
        let totalRemoved: Int
        let avgPerUser: Double
        let avgContactsAvailable: Double
        let avgPercentageAdded: Double
        let edited: Int
        let editRate: Double
        let showSelectedClicks: Int
    }
    
    struct SuggestionStats {
        let totalGenerated: Int
        let avgPerSession: Double
        let viewed: Int
        let tapped: Int
        let dismissed: Int
        let tapRate: Double
        let dismissRate: Double
    }
    
    struct InvitationStats {
        let initiated: Int
        let completed: Int
        let abandoned: Int
        let completionRate: Double
        let avgTimeToSend: Double
        let responseBreakdown: [String: Int]
        let byTimeOfDay: [String: Int]
        let byActivity: [String: Int]
        let freeSlotSuggested: Int
        let freeSlotAccepted: Int
    }
    
    struct ScreenTimeStats {
        let totalTime: Double
        let avgTime: Double
        let views: Int
    }
    
    struct NavigationFlowStats {
        let mostCommonPath: [String]
        let avgStepsToInvite: Double
    }
    
    // MARK: - Generation
    
    static func generate(from events: [AnalyticsEvent], sessions: [String: [AnalyticsEvent]]) -> AnalyticsSummary {
        let dateRange = DateRange(
            start: events.first?.timestamp ?? Date(),
            end: events.last?.timestamp ?? Date()
        )
        
        return AnalyticsSummary(
            totalSessions: sessions.count,
            totalUsers: sessions.count,
            dateRange: dateRange,
            permissions: generatePermissionStats(events),
            onboarding: generateOnboardingStats(events, sessions: sessions),
            connections: generateConnectionStats(events),
            suggestions: generateSuggestionStats(events),
            invitations: generateInvitationStats(events),
            screenTime: generateScreenTimeStats(events),
            navigationFlows: generateNavigationFlowStats(events)
        )
    }
    
    private static func generatePermissionStats(_ events: [AnalyticsEvent]) -> PermissionStats {
        let contactsRequested = events.filter { $0.eventType == "PermissionRequested" && $0.value == "Contacts" }.count
        let contactsGranted = events.filter { $0.eventType == "PermissionGranted" && $0.value == "Contacts" }.count
        let contactsDenied = events.filter { $0.eventType == "PermissionDenied" && $0.value == "Contacts" }.count
        
        let contactsGrantTimes = events
            .filter { $0.eventType == "PermissionGranted" && $0.value == "Contacts" }
            .compactMap { $0.metadata?["timeElapsed"] as? Double }
        let avgContactsTime = contactsGrantTimes.isEmpty ? 0 : contactsGrantTimes.reduce(0, +) / Double(contactsGrantTimes.count)
        
        // Parse selection type for contacts
        var selectionTypes: [String: Int] = ["all": 0, "selected": 0]
        for event in events where event.eventType == "PermissionGranted" && event.value == "Contacts" {
            if let type = event.metadata?["type"] as? String {
                selectionTypes[type, default: 0] += 1
            }
        }
        
        return PermissionStats(
            contacts: PermissionStats.PermissionDetail(
                requested: contactsRequested,
                granted: contactsGranted,
                denied: contactsDenied,
                grantRate: contactsRequested > 0 ? Double(contactsGranted) / Double(contactsRequested) * 100 : 0,
                avgTimeToGrant: avgContactsTime,
                selectionType: selectionTypes
            )
        )
    }
    
    private static func generateOnboardingStats(_ events: [AnalyticsEvent], sessions: [String: [AnalyticsEvent]]) -> OnboardingStats {
        var durations: [Double] = []
        var completedCount = 0

        for (_, sessionEvents) in sessions {
            let sorted = sessionEvents.sorted { $0.timestamp < $1.timestamp }
            guard let firstAdd = sorted.first(where: {
                $0.eventType == "ConnectionAdded" && $0.metadata?["isInitialAdd"] as? Bool == true
            }) else { continue }

            completedCount += 1
            if let launch = sorted.first(where: { $0.eventType == "AppLaunched" }) {
                durations.append(firstAdd.timestamp.timeIntervalSince(launch.timestamp))
            }
        }

        return OnboardingStats(
            avgDuration: durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count),
            completionRate: sessions.isEmpty ? 0 : Double(completedCount) / Double(sessions.count) * 100
        )
    }
    
    private static func generateConnectionStats(_ events: [AnalyticsEvent]) -> ConnectionStats {
        let addedEvents = events.filter { $0.eventType == "ConnectionAdded" }
        let totalAdded = addedEvents.count

        // Use the last ConnectionAdded event per session to get the final percentage reached
        let bySession = Dictionary(grouping: addedEvents, by: { $0.sessionID })
        let finalPerSessionPercentages = bySession.compactMap { _, sessionAdds -> Double? in
            sessionAdds.sorted { $0.timestamp < $1.timestamp }.last?.metadata?["percentage"] as? Double
        }
        let avgPercentage = finalPerSessionPercentages.isEmpty ? 0 : finalPerSessionPercentages.reduce(0, +) / Double(finalPerSessionPercentages.count)

        let availableCounts = addedEvents.compactMap { $0.metadata?["totalAvailable"] as? Int }
        let avgAvailable = availableCounts.isEmpty ? 0 : Double(availableCounts.reduce(0, +)) / Double(availableCounts.count)
        
        let editedCount = events.filter { $0.eventType == "ConnectionEdited" }.count
        let showSelectedClicks = events.filter { $0.eventType == "ShowSelectedClicked" }.count
        
        // Count unique sessions that added connections
        let sessionsWithConnections = Set(addedEvents.map { $0.sessionID }).count
        let avgPerUser = sessionsWithConnections > 0 ? Double(totalAdded) / Double(sessionsWithConnections) : 0
        
        let totalRemoved = events.filter { $0.eventType == "ConnectionRemoved" }.count

        return ConnectionStats(
            totalAdded: totalAdded,
            totalRemoved: totalRemoved,
            avgPerUser: avgPerUser,
            avgContactsAvailable: avgAvailable,
            avgPercentageAdded: avgPercentage,
            edited: editedCount,
            editRate: totalAdded > 0 ? Double(editedCount) / Double(totalAdded) * 100 : 0,
            showSelectedClicks: showSelectedClicks
        )
    }
    
    private static func generateSuggestionStats(_ events: [AnalyticsEvent]) -> SuggestionStats {
        let generatedEvents = events.filter { $0.eventType == "SuggestionsGenerated" }
        let totalGenerated = generatedEvents.compactMap { $0.metadata?["count"] as? Int }.reduce(0, +)
        
        let viewed = events.filter { $0.eventType == "SuggestionViewed" }.count
        let tapped = events.filter { $0.eventType == "SuggestionTapped" }.count
        let dismissed = events.filter { $0.eventType == "SuggestionDismissed" }.count

        let sessionsWithSuggestions = Set(generatedEvents.map { $0.sessionID }).count
        let avgPerSession = sessionsWithSuggestions > 0 ? Double(totalGenerated) / Double(sessionsWithSuggestions) : 0
        let interactions = tapped + dismissed

        return SuggestionStats(
            totalGenerated: totalGenerated,
            avgPerSession: avgPerSession,
            viewed: viewed,
            tapped: tapped,
            dismissed: dismissed,
            tapRate: interactions > 0 ? Double(tapped) / Double(interactions) * 100 : 0,
            dismissRate: interactions > 0 ? Double(dismissed) / Double(interactions) * 100 : 0
        )
    }
    
    private static func generateInvitationStats(_ events: [AnalyticsEvent]) -> InvitationStats {
        let initiated = events.filter { $0.eventType == "InvitationInitiated" }
        let completed = events.filter { $0.eventType == "InvitationCompleted" }
        let abandoned = events.filter { $0.eventType == "InvitationAbandoned" }
        
        let completionTimes = completed.compactMap { $0.metadata?["timeElapsed"] as? Double }
        let avgTime = completionTimes.isEmpty ? 0 : completionTimes.reduce(0, +) / Double(completionTimes.count)
        
        let responses = events.filter { $0.eventType == "InvitationResponse" }
        var responseBreakdown: [String: Int] = ["yes": 0, "maybe": 0, "no": 0]
        for event in responses {
            if let response = event.metadata?["response"] as? String {
                responseBreakdown[response, default: 0] += 1
            }
        }
        
        var timeOfDay: [String: Int] = ["morning": 0, "afternoon": 0, "evening": 0]
        var activities: [String: Int] = [:]
        var freeSlotSuggested = 0
        
        for event in initiated {
            if let tod = event.metadata?["timeOfDay"] as? String {
                timeOfDay[tod, default: 0] += 1
            }
            if let activity = event.metadata?["activity"] as? String, !activity.isEmpty {
                activities[activity, default: 0] += 1
            }
            if let suggested = event.metadata?["freeSlotSuggested"] as? Bool, suggested {
                freeSlotSuggested += 1
            }
        }
        
        let freeSlotAccepted = events.filter { $0.eventType == "FreeSlotResponse" && $0.metadata?["accepted"] as? Bool == true }.count
        
        return InvitationStats(
            initiated: initiated.count,
            completed: completed.count,
            abandoned: abandoned.count,
            completionRate: initiated.count > 0 ? Double(completed.count) / Double(initiated.count) * 100 : 0,
            avgTimeToSend: avgTime,
            responseBreakdown: responseBreakdown,
            byTimeOfDay: timeOfDay,
            byActivity: activities,
            freeSlotSuggested: freeSlotSuggested,
            freeSlotAccepted: freeSlotAccepted
        )
    }
    
    private static func generateScreenTimeStats(_ events: [AnalyticsEvent]) -> [String: ScreenTimeStats] {
        let exitEvents = events.filter { $0.eventType == "ScreenExited" }
        let grouped = Dictionary(grouping: exitEvents, by: { $0.value ?? "Unknown" })
        
        var stats: [String: ScreenTimeStats] = [:]
        
        for (screen, screenEvents) in grouped {
            let durations = screenEvents.compactMap { $0.metadata?["duration"] as? Double }
            let totalTime = durations.reduce(0, +)
            let avgTime = durations.isEmpty ? 0 : totalTime / Double(durations.count)
            
            stats[screen] = ScreenTimeStats(
                totalTime: totalTime,
                avgTime: avgTime,
                views: screenEvents.count
            )
        }
        
        return stats
    }
    
    private static func generateNavigationFlowStats(_ events: [AnalyticsEvent]) -> NavigationFlowStats {
        // Find the most common path to invitation
        // For simplicity, just track average number of screen views before invitation
        let sessions = Dictionary(grouping: events, by: { $0.sessionID })
        
        var pathsToInvite: [[String]] = []
        
        for (_, sessionEvents) in sessions {
            if let inviteIndex = sessionEvents.firstIndex(where: { $0.eventType == "InvitationInitiated" }) {
                let path = sessionEvents[..<inviteIndex]
                    .filter { $0.eventType == "ScreenViewed" }
                    .compactMap { $0.value }
                pathsToInvite.append(path)
            }
        }
        
        let avgSteps = pathsToInvite.isEmpty ? 0 : Double(pathsToInvite.map { $0.count }.reduce(0, +)) / Double(pathsToInvite.count)
        
        // Find most common path (simplified - just the first path if any)
        let mostCommon = pathsToInvite.first ?? []
        
        return NavigationFlowStats(
            mostCommonPath: mostCommon,
            avgStepsToInvite: avgSteps
        )
    }
    
    // MARK: - Serialization
    
    func toDictionary() -> [String: Any] {
        return [
            "summary": [
                "totalSessions": totalSessions,
                "totalUsers": totalUsers,
                "dateRange": [
                    "start": ISO8601DateFormatter().string(from: dateRange.start),
                    "end": ISO8601DateFormatter().string(from: dateRange.end)
                ]
            ],
            "permissions": [
                "contacts": [
                    "requested": permissions.contacts.requested,
                    "granted": permissions.contacts.granted,
                    "denied": permissions.contacts.denied,
                    "grantRate": permissions.contacts.grantRate,
                    "avgTimeToGrant": permissions.contacts.avgTimeToGrant,
                    "selectionType": permissions.contacts.selectionType ?? [:]
                ]
            ],
            "onboarding": [
                "avgDuration": onboarding.avgDuration,
                "completionRate": onboarding.completionRate
            ],
            "connections": [
                "totalAdded": connections.totalAdded,
                "totalRemoved": connections.totalRemoved,
                "avgPerUser": connections.avgPerUser,
                "avgContactsAvailable": connections.avgContactsAvailable,
                "avgPercentageAdded": connections.avgPercentageAdded,
                "edited": connections.edited,
                "editRate": connections.editRate,
                "showSelectedClicks": connections.showSelectedClicks
            ],
            "suggestions": [
                "totalGenerated": suggestions.totalGenerated,
                "avgPerSession": suggestions.avgPerSession,
                "viewed": suggestions.viewed,
                "tapped": suggestions.tapped,
                "dismissed": suggestions.dismissed,
                "tapRate": suggestions.tapRate,
                "dismissRate": suggestions.dismissRate
            ],
            "invitations": [
                "initiated": invitations.initiated,
                "completed": invitations.completed,
                "abandoned": invitations.abandoned,
                "completionRate": invitations.completionRate,
                "avgTimeToSend": invitations.avgTimeToSend,
                "responseBreakdown": invitations.responseBreakdown,
                "byTimeOfDay": invitations.byTimeOfDay,
                "byActivity": invitations.byActivity,
                "freeSlotSuggested": invitations.freeSlotSuggested,
                "freeSlotAccepted": invitations.freeSlotAccepted
            ],
            "screenTime": screenTime.mapValues { [
                "totalTime": $0.totalTime,
                "avgTime": $0.avgTime,
                "views": $0.views
            ]},
            "navigationFlows": [
                "mostCommonPath": navigationFlows.mostCommonPath,
                "avgStepsToInvite": navigationFlows.avgStepsToInvite
            ]
        ]
    }
}
