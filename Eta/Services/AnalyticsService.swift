import Foundation
import UIKit

@Observable
final class AnalyticsService {
    enum Category: String {
        case lifecycle  = "Lifecycle"
        case permission = "Permission"
        case navigation = "Navigation"
        case connection = "Connection"
        case suggestion = "Suggestion"
        case invitation = "Invitation"
        case feedback   = "Feedback"
        case error      = "Error"
    }
    private(set) var currentSessionID: String
    private let supabase: SupabaseService
    private var screenStartTimes: [String: Date] = [:]
    var userIdentifier: String?

    init(supabaseService: SupabaseService) {
        self.supabase = supabaseService
        self.currentSessionID = "Session_\(Self.makeSessionID())"
    }

    /// Call once the user's phone/email identifier is confirmed.
    /// This is the earliest point events mean anything — fires AppLaunched here.
    func start(identifier: String) {
        userIdentifier = identifier
        logEvent(type: "AppLaunched", category: .lifecycle)
    }

    private static func makeSessionID() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f.string(from: Date())
    }

    // MARK: - Core

    func logEvent(
        type: String,
        category: Category,
        value: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        let id = UUID().uuidString
        let ts = Date()
        let sessionID = currentSessionID
        let identifier = userIdentifier
        Task {
            await supabase.postAnalyticsEvent(
                id: id,
                sessionID: sessionID,
                eventType: type,
                category: category.rawValue,
                value: value,
                metadata: metadata,
                clientTimestamp: ts,
                userIdentifier: identifier
            )
        }
    }

    // MARK: - Permission

    func logPermissionRequested(type: String) {
        logEvent(type: "PermissionRequested", category: .permission, value: type)
    }

    func logPermissionGranted(type: String, timeElapsed: TimeInterval, additionalInfo: [String: Any]? = nil) {
        var meta = additionalInfo ?? [:]
        meta["timeElapsed"] = timeElapsed
        logEvent(type: "PermissionGranted", category: .permission, value: type, metadata: meta)
    }

    func logPermissionDenied(type: String, timeElapsed: TimeInterval) {
        logEvent(type: "PermissionDenied", category: .permission, value: type, metadata: ["timeElapsed": timeElapsed])
    }

    // MARK: - Screen

    func logScreenViewed(screen: String) {
        screenStartTimes[screen] = Date()
        logEvent(type: "ScreenViewed", category: .navigation, value: screen)
    }

    func logScreenExited(screen: String) {
        let duration: TimeInterval
        if let start = screenStartTimes[screen] {
            duration = Date().timeIntervalSince(start)
            screenStartTimes.removeValue(forKey: screen)
        } else {
            duration = 0
        }
        logEvent(type: "ScreenExited", category: .navigation, value: screen, metadata: ["duration": duration])
    }

    // MARK: - Connections

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
        logEvent(type: "ConnectionRemoved", category: .connection, value: contactName, metadata: ["totalConnections": totalContacts])
    }

    // MARK: - Suggestions

    func logSuggestionsGenerated(count: Int, contactNames: [String]) {
        logEvent(type: "SuggestionsGenerated", category: .suggestion, metadata: ["count": count, "contacts": contactNames])
    }

    func logSuggestionViewed(contactName: String, daysSinceLastHangout: Int?) {
        logEvent(type: "SuggestionViewed", category: .suggestion, value: contactName, metadata: ["daysSinceLastHangout": daysSinceLastHangout ?? -1])
    }

    func logSuggestionTapped(contactName: String) {
        logEvent(type: "SuggestionTapped", category: .suggestion, value: contactName)
    }

    func logSuggestionDismissed(contactName: String) {
        logEvent(type: "SuggestionDismissed", category: .suggestion, value: contactName)
    }

    // MARK: - Invitations

    // Fired when the user taps Schedule from the suggestion card.
    func logSuggestionAccepted(contactName: String, activity: String) {
        logEvent(type: "SuggestionAccepted", category: .invitation, value: contactName, metadata: ["activity": activity])
    }

    // Fired in InvitationManager.acceptSuggestion after the invite is sent.
    // source: "suggestion" | "chat" | "manual" | "edit"
    func logInvitationSent(contactName: String, activity: String, source: String) {
        logEvent(type: "InvitationSent", category: .invitation, value: contactName, metadata: ["activity": activity, "source": source])
    }

    // Fired when the receiver dismisses the invite sheet without responding (Answer Later or swipe).
    func logInviteDelayed(friendName: String, activity: String, isEdit: Bool) {
        logEvent(type: "InviteDelayed", category: .invitation, value: friendName, metadata: ["activity": activity, "isEdit": isEdit])
    }

    // Fired on receiver's device when the sender cancels a confirmed event.
    func logEventCanceledByFriend(friendName: String, activity: String) {
        logEvent(type: "EventCanceledByFriend", category: .invitation, value: friendName, metadata: ["activity": activity])
    }

    // Fired on receiver's device when they accept a received invitation.
    func logHangoutConfirmed(friendName: String, activity: String, isEdit: Bool = false, delayed: Bool = false) {
        logEvent(type: "HangoutConfirmed", category: .invitation, value: friendName, metadata: ["activity": activity, "isEdit": isEdit, "delayed": delayed])
    }

    // Fired on receiver's device when they decline a received invitation.
    func logHangoutDeclined(friendName: String, activity: String, isEdit: Bool = false, delayed: Bool = false) {
        logEvent(type: "HangoutDeclined", category: .invitation, value: friendName, metadata: ["activity": activity, "isEdit": isEdit, "delayed": delayed])
    }

    // MARK: - Navigation

    func logButtonTapped(screen: String, button: String) {
        logEvent(type: "ButtonTapped", category: .navigation, value: "\(screen).\(button)")
    }

    func logAppBackgrounded() {
        logEvent(type: "AppBackgrounded", category: .lifecycle)
    }

    func logAppForegrounded() {
        logEvent(type: "AppForegrounded", category: .lifecycle)
    }

    func logOnboardingCompleted() {
        logEvent(type: "OnboardingCompleted", category: .lifecycle)
    }

    // MARK: - Received invitations

    func logInvitationReceived(friendName: String, activity: String) {
        logEvent(type: "InvitationReceived", category: .invitation, value: friendName, metadata: ["activity": activity])
    }

    // MARK: - Nudge actions

    // action: "scheduleNow" | "viewSuggestions" | "maybeLater"
    func logNudgeAction(_ action: String, friendName: String?, activity: String) {
        logEvent(type: "NudgeAction", category: .suggestion, value: action, metadata: ["friendName": friendName ?? "", "activity": activity])
    }

    // MARK: - Manual event creation

    func logEventCreated(activity: String, isEdit: Bool) {
        logEvent(type: isEdit ? "EventEdited" : "EventCreated", category: .invitation, metadata: ["activity": activity])
    }

    func logEventDeleted(activity: String) {
        logEvent(type: "EventDeleted", category: .invitation, metadata: ["activity": activity])
    }

    // MARK: - Post-hangout feedback

    func logFeedbackSubmitted(friendRating: Int, wouldRepeatActivity: Bool, activity: String, skipped: Bool) {
        logEvent(type: "FeedbackSubmitted", category: .feedback, metadata: [
            "friendRating": friendRating,
            "wouldRepeatActivity": wouldRepeatActivity,
            "activity": activity,
            "skipped": skipped
        ])
    }

    // MARK: - Weekly check-in

    func logWeeklyCheckInCompleted(prioritySet: Bool) {
        logEvent(type: "WeeklyCheckInCompleted", category: .lifecycle, metadata: ["prioritySet": prioritySet])
    }

    // MARK: - Chat

    func logChatOpened() {
        logEvent(type: "ChatOpened", category: .navigation)
    }

    // action: "scheduleHangout" | "setGoal"
    func logChatActionConfirmed(action: String, friendName: String, detail: String) {
        logEvent(type: "ChatActionConfirmed", category: .invitation, value: action, metadata: ["friendName": friendName, "detail": detail])
    }

    func logChatSessionCompleted(messageCount: Int, actionTaken: Bool) {
        logEvent(type: "ChatSessionCompleted", category: .suggestion, metadata: ["messageCount": messageCount, "actionTaken": actionTaken])
    }

    // MARK: - Availability

    // Fired once when the user leaves the availability tab after making changes.
    // action: "added" | "removed" | "both"
    func logAvailabilitySessionCompleted(action: String, usedRecurring: Bool) {
        logEvent(type: "AvailabilitySessionCompleted", category: .lifecycle, metadata: [
            "action": action,
            "usedRecurring": usedRecurring
        ])
    }

    // MARK: - Goals

    func logGoalCreated(title: String, friendName: String?, cadence: String, target: Int, source: String) {
        logEvent(type: "GoalCreated", category: .connection, value: title, metadata: [
            "friendName": friendName ?? "",
            "cadence": cadence,
            "target": target,
            "source": source
        ])
    }

    func logGoalDeleted(title: String) {
        logEvent(type: "GoalDeleted", category: .connection, value: title)
    }

    // MARK: - Manual hangout log

    func logHangoutLoggedManually(friendName: String, activity: String) {
        logEvent(type: "HangoutLoggedManually", category: .invitation, value: friendName, metadata: ["activity": activity])
    }

    // MARK: - Check-in

    func logCheckInOpened(friendName: String) {
        logEvent(type: "CheckInOpened", category: .connection, value: friendName)
    }

    func logSendNudge(friendName: String) {
        logEvent(type: "SendNudge", category: .connection, value: friendName)
    }

    // MARK: - Photo capture

    func logPhotoSheetOpened(activity: String) {
        logEvent(type: "PhotoSheetOpened", category: .lifecycle, value: activity)
    }

    func logPhotoSaved(activity: String) {
        logEvent(type: "PhotoSaved", category: .lifecycle, value: activity)
    }

    // MARK: - Contact preferences

    func logContactTagged(friendName: String) {
        logEvent(type: "ContactTagged", category: .connection, value: friendName)
    }

    func logContactCitySet(friendName: String) {
        logEvent(type: "ContactCitySet", category: .connection, value: friendName)
    }

    func logUserLocationSet() {
        logEvent(type: "UserLocationSet", category: .lifecycle)
    }

}
