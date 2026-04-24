//
//  AnalyticsService.swift
//  Eta
//
//  Created on 4/23/26.
//

import Foundation
import SwiftData
import UIKit

/// Central service for logging analytics events during user testing.
/// Generates a unique session ID on each app launch and tracks all user interactions.
@Observable
final class AnalyticsService {
    private(set) var currentSessionID: String
    private let modelContext: ModelContext
    private var screenStartTimes: [String: Date] = [:]
    
    var sessionNotes: [String: String] = [:] {
        didSet { UserDefaults.standard.set(sessionNotes, forKey: "eta.sessionNotes") }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.currentSessionID = "Session_\(Self.generateSessionIdentifier())"
        self.sessionNotes = (UserDefaults.standard.dictionary(forKey: "eta.sessionNotes") as? [String: String]) ?? [:]
        
        // Log app launch
        logEvent(
            type: "AppLaunched",
            category: .lifecycle
        )
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        currentSessionID = "Session_\(Self.generateSessionIdentifier())"
        screenStartTimes.removeAll()
        
        logEvent(
            type: "NewSessionStarted",
            category: .lifecycle
        )
        
        print("📊 New session started: \(currentSessionID)")
    }
    
    private static func generateSessionIdentifier() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
    
    // MARK: - Event Logging
    
    func logEvent(
        type: String,
        category: AnalyticsEvent.Category,
        value: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        let event = AnalyticsEvent(
            sessionID: currentSessionID,
            eventType: type,
            category: category.rawValue,
            value: value,
            metadata: metadata
        )
        
        modelContext.insert(event)
        try? modelContext.save()
        
        // Also write to continuous backup file
        appendToBackupFile(event)
    }
    
    // MARK: - Permission Tracking
    
    func logPermissionRequested(type: String) {
        logEvent(
            type: "PermissionRequested",
            category: .permission,
            value: type
        )
    }
    
    func logPermissionGranted(type: String, timeElapsed: TimeInterval, additionalInfo: [String: Any]? = nil) {
        var metadata = additionalInfo ?? [:]
        metadata["timeElapsed"] = timeElapsed
        
        logEvent(
            type: "PermissionGranted",
            category: .permission,
            value: type,
            metadata: metadata
        )
    }
    
    func logPermissionDenied(type: String, timeElapsed: TimeInterval) {
        logEvent(
            type: "PermissionDenied",
            category: .permission,
            value: type,
            metadata: ["timeElapsed": timeElapsed]
        )
    }
    
    // MARK: - Screen Tracking
    
    func logScreenViewed(screen: String) {
        screenStartTimes[screen] = Date()
        
        logEvent(
            type: "ScreenViewed",
            category: .navigation,
            value: screen
        )
    }
    
    func logScreenExited(screen: String) {
        let duration: TimeInterval
        if let startTime = screenStartTimes[screen] {
            duration = Date().timeIntervalSince(startTime)
            screenStartTimes.removeValue(forKey: screen)
        } else {
            duration = 0
        }
        
        logEvent(
            type: "ScreenExited",
            category: .navigation,
            value: screen,
            metadata: ["duration": duration]
        )
    }
    
    // MARK: - Connection Tracking
    
    func logConnectionAdded(contactName: String?, totalContacts: Int, totalAvailable: Int, isInitialAdd: Bool = false) {
        logEvent(
            type: "ConnectionAdded",
            category: .connection,
            value: contactName,
            metadata: [
                "totalConnections": totalContacts,
                "totalAvailable": totalAvailable,
                "percentage": totalAvailable > 0 ? Double(totalContacts) / Double(totalAvailable) * 100 : 0,
                "isInitialAdd": isInitialAdd
            ]
        )
    }
    
    func logConnectionRemoved(contactName: String?, totalContacts: Int) {
        logEvent(
            type: "ConnectionRemoved",
            category: .connection,
            value: contactName,
            metadata: ["totalConnections": totalContacts]
        )
    }

    func logConnectionEdited(contactName: String?, field: String, oldValue: String?, newValue: String?) {
        logEvent(
            type: "ConnectionEdited",
            category: .connection,
            value: contactName,
            metadata: [
                "field": field,
                "oldValue": oldValue ?? "",
                "newValue": newValue ?? ""
            ]
        )
    }
    
    func logShowSelectedClicked() {
        logEvent(
            type: "ShowSelectedClicked",
            category: .connection
        )
    }
    
    // MARK: - Suggestion Tracking
    
    func logSuggestionsGenerated(count: Int, contactNames: [String]) {
        logEvent(
            type: "SuggestionsGenerated",
            category: .suggestion,
            metadata: [
                "count": count,
                "contacts": contactNames
            ]
        )
    }
    
    func logSuggestionViewed(contactName: String, daysSinceLastHangout: Int?) {
        logEvent(
            type: "SuggestionViewed",
            category: .suggestion,
            value: contactName,
            metadata: [
                "daysSinceLastHangout": daysSinceLastHangout ?? -1
            ]
        )
    }
    
    func logSuggestionTapped(contactName: String) {
        logEvent(
            type: "SuggestionTapped",
            category: .suggestion,
            value: contactName
        )
    }

    func logSuggestionDismissed(contactName: String) {
        logEvent(
            type: "SuggestionDismissed",
            category: .suggestion,
            value: contactName
        )
    }
    
    // MARK: - Invitation Tracking
    
    func logInvitationInitiated(contactName: String, activity: String?, timeOfDay: String?, isFreeSlotSuggested: Bool) {
        logEvent(
            type: "InvitationInitiated",
            category: .invitation,
            value: contactName,
            metadata: [
                "activity": activity ?? "",
                "timeOfDay": timeOfDay ?? "",
                "freeSlotSuggested": isFreeSlotSuggested
            ]
        )
    }
    
    func logFreeSlotAccepted(accepted: Bool, suggestedTime: String?, chosenTime: String?) {
        logEvent(
            type: "FreeSlotResponse",
            category: .invitation,
            metadata: [
                "accepted": accepted,
                "suggestedTime": suggestedTime ?? "",
                "chosenTime": chosenTime ?? ""
            ]
        )
    }
    
    func logInvitationCompleted(contactName: String, method: String, timeElapsed: TimeInterval) {
        logEvent(
            type: "InvitationCompleted",
            category: .invitation,
            value: contactName,
            metadata: [
                "method": method,
                "timeElapsed": timeElapsed
            ]
        )
    }
    
    func logInvitationAbandoned(contactName: String, timeElapsed: TimeInterval, reason: String?) {
        logEvent(
            type: "InvitationAbandoned",
            category: .invitation,
            value: contactName,
            metadata: [
                "timeElapsed": timeElapsed,
                "reason": reason ?? "unknown"
            ]
        )
    }
    
    func logInvitationResponse(contactName: String, response: String) {
        logEvent(
            type: "InvitationResponse",
            category: .invitation,
            value: contactName,
            metadata: ["response": response]
        )
    }
    
    // MARK: - Feedback Tracking
    
    func logFeedback(type: String, value: Any, context: [String: Any]? = nil) {
        var metadata = context ?? [:]
        metadata["feedbackValue"] = value
        
        logEvent(
            type: "FeedbackReceived",
            category: .feedback,
            value: type,
            metadata: metadata
        )
    }
    
    // MARK: - Navigation Flow Tracking
    
    func logButtonTapped(screen: String, button: String) {
        logEvent(
            type: "ButtonTapped",
            category: .navigation,
            value: "\(screen).\(button)"
        )
    }
    
    func logUserReset() {
        logEvent(type: "UserReset", category: .lifecycle)
    }

    func logAppBackgrounded() {
        logEvent(
            type: "AppBackgrounded",
            category: .lifecycle
        )
    }
    
    func logAppForegrounded() {
        logEvent(
            type: "AppForegrounded",
            category: .lifecycle
        )
    }
    
    // MARK: - Data Export


    func getAllSessions() -> [SessionInfo] {
        let events = fetchAllEvents()
        let grouped = Dictionary(grouping: events, by: { $0.sessionID })
        return grouped.compactMap { sessionID, sessionEvents in
            let sorted = sessionEvents.sorted { $0.timestamp < $1.timestamp }
            guard let first = sorted.first, let last = sorted.last else { return nil }
            return SessionInfo(
                sessionID: sessionID,
                startTime: first.timestamp,
                endTime: last.timestamp,
                eventCount: sessionEvents.count
            )
        }.sorted { $0.startTime > $1.startTime }
    }

    func createExportFiles(sessionIDs: Set<String>? = nil, notes: [String: String] = [:]) -> [URL] {
        sessionNotes.merge(notes) { _, new in new }

        let allEvents = fetchAllEvents()
        let events = sessionIDs.map { ids in allEvents.filter { ids.contains($0.sessionID) } } ?? allEvents
        let sessions = Dictionary(grouping: events, by: { $0.sessionID })

        let timestamp = Self.generateSessionIdentifier()
        let tempDir = FileManager.default.temporaryDirectory
        var files: [URL] = []

        var csv = "SessionID,Timestamp,EventType,Category,Value,Metadata\n"
        for event in events {
            let ts = ISO8601DateFormatter().string(from: event.timestamp)
            let value = csvQuote(event.value ?? "")
            let metadata = csvQuote(event.metadataJSON ?? "{}")
            csv += "\(event.sessionID),\(ts),\(event.eventType),\(event.category),\(value),\(metadata)\n"
        }
        let csvURL = tempDir.appendingPathComponent("eta_analytics_\(timestamp).csv")
        if let data = csv.data(using: .utf8) { try? data.write(to: csvURL); files.append(csvURL) }

        var export: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "totalSessions": sessions.count,
            "totalEvents": events.count
        ]
        var sessionArray: [[String: Any]] = []
        for (sessionID, sessionEvents) in sessions.sorted(by: { $0.key < $1.key }) {
            let sorted = sessionEvents.sorted { $0.timestamp < $1.timestamp }
            let sessionData: [String: Any] = [
                "sessionID": sessionID,
                "startTime": ISO8601DateFormatter().string(from: sorted.first?.timestamp ?? Date()),
                "endTime": ISO8601DateFormatter().string(from: sorted.last?.timestamp ?? Date()),
                "duration": (sorted.last?.timestamp ?? Date()).timeIntervalSince(sorted.first?.timestamp ?? Date()),
                "notes": notes[sessionID] ?? sessionNotes[sessionID] ?? "",
                "events": sorted.map { event in
                    ["timestamp": ISO8601DateFormatter().string(from: event.timestamp),
                     "eventType": event.eventType,
                     "category": event.category,
                     "value": event.value ?? "",
                     "metadata": event.metadata ?? [:]] as [String: Any]
                }
            ]
            sessionArray.append(sessionData)
        }
        export["sessions"] = sessionArray
        let jsonURL = tempDir.appendingPathComponent("eta_analytics_\(timestamp).json")
        if let data = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8),
           let strData = str.data(using: .utf8) {
            try? strData.write(to: jsonURL); files.append(jsonURL)
        }

        let summary = AnalyticsSummary.generate(from: events, sessions: sessions)
        let summaryURL = tempDir.appendingPathComponent("eta_summary_\(timestamp).json")
        if let data = try? JSONSerialization.data(withJSONObject: summary.toDictionary(), options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8),
           let strData = str.data(using: .utf8) {
            try? strData.write(to: summaryURL); files.append(summaryURL)
        }

        return files
    }
    
    // MARK: - Continuous Backup
    
    private var backupFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("analytics_backup.csv")
    }
    
    private func appendToBackupFile(_ event: AnalyticsEvent) {
        let timestamp = ISO8601DateFormatter().string(from: event.timestamp)
        let value = csvQuote(event.value ?? "")
        let metadata = csvQuote(event.metadataJSON ?? "{}")

        let csvLine = "\(event.sessionID),\(timestamp),\(event.eventType),\(event.category),\(value),\(metadata)\n"
        
        if let data = csvLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: backupFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: backupFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                let header = "SessionID,Timestamp,EventType,Category,Value,Metadata\n"
                try? (header + csvLine).write(to: backupFileURL, atomically: true, encoding: .utf8)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func csvQuote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func fetchAllEvents() -> [AnalyticsEvent] {
        let descriptor = FetchDescriptor<AnalyticsEvent>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
