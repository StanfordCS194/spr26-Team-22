//
//  AnalyticsService.swift
//  Eta
//

import Foundation
import SwiftData
import UIKit

/// Logs analytics events that feed the 5 study KPIs.
///
/// Each event is per-user (per device). When collecting data from N testers, export
/// one CSV per device and aggregate across files — every metric below is derivable
/// per-device and trivially averaged across users.
///
/// KPI mapping:
///   KPI 1 – weekly plan creation rate  → AppLaunched + PlanCreated (grouped by ISO week)
///   KPI 2 – median time to first plan  → PlanCreated.secondsFromLaunch
///   KPI 3 – plan → hangout rate        → PlanCreated + HangoutCompleted
///   KPI 4 – suggestion acceptance rate → SuggestionAccepted / (SuggestionAccepted + SuggestionDismissed)
///   KPI 5 – contact hangout rate       → PlanCreated.contactID (unique, last 14 days) / ConnectionAdded.totalConnections
@Observable
final class AnalyticsService {
    private(set) var currentSessionID: String
    private(set) var sessionStartTime: Date
    private let modelContext: ModelContext

    var sessionNotes: [String: String] = [:] {
        didSet { UserDefaults.standard.set(sessionNotes, forKey: "eta.sessionNotes") }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let now = Date()
        self.sessionStartTime = now
        self.currentSessionID = "Session_\(Self.formatDate(now))"
        self.sessionNotes = (UserDefaults.standard.dictionary(forKey: "eta.sessionNotes") as? [String: String]) ?? [:]

        logEvent(type: "AppLaunched", category: .lifecycle)
    }

    // MARK: - Session

    func startNewSession() {
        let now = Date()
        sessionStartTime = now
        currentSessionID = "Session_\(Self.formatDate(now))"
        logEvent(type: "AppLaunched", category: .lifecycle)
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f.string(from: date)
    }

    // MARK: - Core logging

    func logEvent(type: String, category: AnalyticsEvent.Category, value: String? = nil, metadata: [String: Any]? = nil) {
        let event = AnalyticsEvent(
            sessionID: currentSessionID,
            eventType: type,
            category: category.rawValue,
            value: value,
            metadata: metadata
        )
        modelContext.insert(event)
        try? modelContext.save()
        appendToBackupFile(event)
    }

    // MARK: - Lifecycle (KPI 1, 2)

    func logAppBackgrounded() {
        logEvent(type: "AppBackgrounded", category: .lifecycle)
    }

    func logAppForegrounded() {
        logEvent(type: "AppForegrounded", category: .lifecycle)
    }

    // MARK: - Navigation

    func logTabSwitched(to tab: String) {
        logEvent(type: "TabSwitched", category: .navigation, value: tab)
    }

    /// Log key non-semantic button taps — decisions not already captured by a semantic event.
    func logButtonTapped(screen: String, button: String) {
        logEvent(type: "ButtonTapped", category: .navigation, value: "\(screen).\(button)")
    }

    // MARK: - Connections (KPI 5 denominator)

    func logConnectionAdded(contactName: String?, totalContacts: Int) {
        logEvent(
            type: "ConnectionAdded",
            category: .connection,
            value: contactName,
            metadata: ["totalConnections": totalContacts]
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

    // MARK: - Suggestions (KPI 4)

    func logSuggestionGenerated(contactName: String, activity: String, daysSinceLastHangout: Int?) {
        logEvent(
            type: "SuggestionGenerated",
            category: .suggestion,
            value: contactName,
            metadata: [
                "activity": activity,
                "daysSinceLastHangout": daysSinceLastHangout ?? -1
            ]
        )
    }

    func logSuggestionAccepted(contactName: String, activity: String) {
        logEvent(
            type: "SuggestionAccepted",
            category: .suggestion,
            value: contactName,
            metadata: ["activity": activity]
        )
    }

    func logSuggestionDismissed(contactName: String) {
        logEvent(
            type: "SuggestionDismissed",
            category: .suggestion,
            value: contactName
        )
    }

    // MARK: - Plans (KPI 1, 2, 3, 5)

    /// Fired when a hangout is booked and the invitation is sent.
    ///
    /// - `secondsFromLaunch`: time elapsed since app launched this session (for KPI 2).
    func logPlanCreated(contactID: UUID, contactName: String, activity: String, secondsFromLaunch: TimeInterval) {
        logEvent(
            type: "PlanCreated",
            category: .plan,
            value: contactName,
            metadata: [
                "contactID": contactID.uuidString,
                "activity": activity,
                "secondsFromLaunch": secondsFromLaunch
            ]
        )
    }

    /// Fired when the simulated (or real) invitation response comes back confirmed.
    func logHangoutConfirmed(contactID: UUID?, contactName: String, hangoutID: UUID) {
        logEvent(
            type: "HangoutConfirmed",
            category: .plan,
            value: contactName,
            metadata: [
                "contactID": contactID?.uuidString ?? "",
                "hangoutID": hangoutID.uuidString
            ]
        )
    }

    /// Fired when the user submits post-hangout feedback — the clearest signal a hangout actually happened.
    func logHangoutCompleted(contactID: UUID?, contactName: String, hangoutID: UUID, friendRating: Int, activityRating: Int) {
        logEvent(
            type: "HangoutCompleted",
            category: .plan,
            value: contactName,
            metadata: [
                "contactID": contactID?.uuidString ?? "",
                "hangoutID": hangoutID.uuidString,
                "friendRating": friendRating,
                "activityRating": activityRating
            ]
        )
    }

    // MARK: - Export

    func getAllSessions() -> [SessionInfo] {
        let events = fetchAllEvents()
        let grouped = Dictionary(grouping: events, by: { $0.sessionID })
        return grouped.compactMap { sessionID, sessionEvents in
            let sorted = sessionEvents.sorted { $0.timestamp < $1.timestamp }
            guard let first = sorted.first, let last = sorted.last else { return nil }
            return SessionInfo(sessionID: sessionID, startTime: first.timestamp, endTime: last.timestamp, eventCount: sessionEvents.count)
        }.sorted { $0.startTime > $1.startTime }
    }

    func createExportFiles(sessionIDs: Set<String>? = nil, notes: [String: String] = [:]) -> [URL] {
        sessionNotes.merge(notes) { _, new in new }

        let allEvents = fetchAllEvents()
        let events = sessionIDs.map { ids in allEvents.filter { ids.contains($0.sessionID) } } ?? allEvents
        let sessions = Dictionary(grouping: events, by: { $0.sessionID })

        let timestamp = Self.formatDate(Date())
        let tempDir = FileManager.default.temporaryDirectory
        var files: [URL] = []

        // Raw CSV
        var csv = "SessionID,Timestamp,EventType,Category,Value,Metadata\n"
        for event in events {
            let ts = ISO8601DateFormatter().string(from: event.timestamp)
            csv += "\(event.sessionID),\(ts),\(event.eventType),\(event.category),\(csvQuote(event.value ?? "")),\(csvQuote(event.metadataJSON ?? "{}"))\n"
        }
        let csvURL = tempDir.appendingPathComponent("eta_analytics_\(timestamp).csv")
        if let data = csv.data(using: .utf8) { try? data.write(to: csvURL); files.append(csvURL) }

        // Structured JSON
        var export: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "totalSessions": sessions.count,
            "totalEvents": events.count
        ]
        var sessionArray: [[String: Any]] = []
        for (sessionID, sessionEvents) in sessions.sorted(by: { $0.key < $1.key }) {
            let sorted = sessionEvents.sorted { $0.timestamp < $1.timestamp }
            sessionArray.append([
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
            ])
        }
        export["sessions"] = sessionArray
        let jsonURL = tempDir.appendingPathComponent("eta_analytics_\(timestamp).json")
        if let data = try? JSONSerialization.data(withJSONObject: export, options: .prettyPrinted),
           let strData = String(data: data, encoding: .utf8)?.data(using: .utf8) {
            try? strData.write(to: jsonURL); files.append(jsonURL)
        }

        // KPI summary
        let summary = AnalyticsSummary.generate(from: events, sessions: sessions)
        let summaryURL = tempDir.appendingPathComponent("eta_kpis_\(timestamp).json")
        if let data = try? JSONSerialization.data(withJSONObject: summary.toDictionary(), options: .prettyPrinted),
           let strData = String(data: data, encoding: .utf8)?.data(using: .utf8) {
            try? strData.write(to: summaryURL); files.append(summaryURL)
        }

        return files
    }

    // MARK: - Continuous backup

    private var backupFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("analytics_backup.csv")
    }

    private func appendToBackupFile(_ event: AnalyticsEvent) {
        let ts = ISO8601DateFormatter().string(from: event.timestamp)
        let line = "\(event.sessionID),\(ts),\(event.eventType),\(event.category),\(csvQuote(event.value ?? "")),\(csvQuote(event.metadataJSON ?? "{}"))\n"
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: backupFileURL.path) {
            if let fh = try? FileHandle(forWritingTo: backupFileURL) {
                fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
            }
        } else {
            let header = "SessionID,Timestamp,EventType,Category,Value,Metadata\n"
            try? (header + line).write(to: backupFileURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Helpers

    private func csvQuote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func fetchAllEvents() -> [AnalyticsEvent] {
        let descriptor = FetchDescriptor<AnalyticsEvent>(sortBy: [SortDescriptor(\.timestamp)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
