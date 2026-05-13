//
//  AnalyticsSummary.swift
//  Eta
//

import Foundation

/// Computes the 5 study KPIs from raw analytics events.
///
/// All metrics are per-device (one user per device). To aggregate across N testers,
/// collect one export per device and average the KPI values across files.
struct AnalyticsSummary {

    // MARK: - KPI structs

    /// KPI 1: % of active weeks where the user created at least one plan.
    /// "Active week" = any ISO week containing an AppLaunched event.
    struct WeeklyPlanRate {
        let rate: Double            // 0–1
        let activeWeeks: Int
        let weeksWithPlan: Int
    }

    /// KPI 2: Median elapsed seconds from app open to first plan created in the same session.
    struct TimeToFirstPlan {
        let medianSeconds: Double
        let sampleSize: Int         // sessions that had a plan created
        let allSeconds: [Double]    // raw values for further analysis
    }

    /// KPI 3: % of created plans that resulted in a completed hangout.
    /// "Completed" = user submitted post-hangout feedback (HangoutCompleted).
    /// "Confirmed" (simulated acceptance) is tracked separately for reference.
    struct PlanToHangoutRate {
        let completionRate: Double  // HangoutCompleted / PlanCreated
        let confirmationRate: Double // HangoutConfirmed / PlanCreated
        let plansCreated: Int
        let hangoutsConfirmed: Int
        let hangoutsCompleted: Int
    }

    /// KPI 4: % of shown suggestions that the user accepted.
    struct SuggestionAcceptanceRate {
        let rate: Double            // 0–1
        let accepted: Int
        let dismissed: Int
        let generated: Int
    }

    /// KPI 5: % of tracked contacts the user hung out with in the past 14 days.
    struct ContactHangoutRate {
        let rate: Double            // 0–1
        let uniqueContactsHungOutWith: Int
        let totalContacts: Int
        let windowDays: Int         // always 14
    }

    let kpi1WeeklyPlanRate: WeeklyPlanRate
    let kpi2TimeToFirstPlan: TimeToFirstPlan
    let kpi3PlanToHangoutRate: PlanToHangoutRate
    let kpi4SuggestionAcceptance: SuggestionAcceptanceRate
    let kpi5ContactHangoutRate: ContactHangoutRate

    // MARK: - Generation

    static func generate(from events: [AnalyticsEvent], sessions: [String: [AnalyticsEvent]]) -> AnalyticsSummary {
        AnalyticsSummary(
            kpi1WeeklyPlanRate: computeWeeklyPlanRate(events),
            kpi2TimeToFirstPlan: computeTimeToFirstPlan(events),
            kpi3PlanToHangoutRate: computePlanToHangoutRate(events),
            kpi4SuggestionAcceptance: computeSuggestionAcceptance(events),
            kpi5ContactHangoutRate: computeContactHangoutRate(events)
        )
    }

    // MARK: - KPI 1

    private static func computeWeeklyPlanRate(_ events: [AnalyticsEvent]) -> WeeklyPlanRate {
        let launchWeeks = Set(events.filter { $0.eventType == "AppLaunched" }.map { isoWeek($0.timestamp) })
        let planWeeks   = Set(events.filter { $0.eventType == "PlanCreated"  }.map { isoWeek($0.timestamp) })

        let weeksWithPlan = launchWeeks.intersection(planWeeks).count
        let rate = launchWeeks.isEmpty ? 0 : Double(weeksWithPlan) / Double(launchWeeks.count)

        return WeeklyPlanRate(rate: rate, activeWeeks: launchWeeks.count, weeksWithPlan: weeksWithPlan)
    }

    // MARK: - KPI 2

    private static func computeTimeToFirstPlan(_ events: [AnalyticsEvent]) -> TimeToFirstPlan {
        let times = events
            .filter { $0.eventType == "PlanCreated" }
            .compactMap { $0.metadata?["secondsFromLaunch"] as? Double }
            .filter { $0 > 0 }

        return TimeToFirstPlan(
            medianSeconds: median(times),
            sampleSize: times.count,
            allSeconds: times
        )
    }

    // MARK: - KPI 3

    private static func computePlanToHangoutRate(_ events: [AnalyticsEvent]) -> PlanToHangoutRate {
        let plansCreated = events.filter { $0.eventType == "PlanCreated" }.count
        let confirmed    = events.filter { $0.eventType == "HangoutConfirmed" }.count
        let completed    = events.filter { $0.eventType == "HangoutCompleted" }.count

        return PlanToHangoutRate(
            completionRate:    plansCreated > 0 ? Double(completed)  / Double(plansCreated) : 0,
            confirmationRate:  plansCreated > 0 ? Double(confirmed)  / Double(plansCreated) : 0,
            plansCreated:      plansCreated,
            hangoutsConfirmed: confirmed,
            hangoutsCompleted: completed
        )
    }

    // MARK: - KPI 4

    private static func computeSuggestionAcceptance(_ events: [AnalyticsEvent]) -> SuggestionAcceptanceRate {
        let accepted   = events.filter { $0.eventType == "SuggestionAccepted"  }.count
        let dismissed  = events.filter { $0.eventType == "SuggestionDismissed" }.count
        let generated  = events.filter { $0.eventType == "SuggestionGenerated" }.count
        let interacted = accepted + dismissed

        return SuggestionAcceptanceRate(
            rate:      interacted > 0 ? Double(accepted) / Double(interacted) : 0,
            accepted:  accepted,
            dismissed: dismissed,
            generated: generated
        )
    }

    // MARK: - KPI 5

    private static func computeContactHangoutRate(_ events: [AnalyticsEvent]) -> ContactHangoutRate {
        let windowDays = 14
        let cutoff = (events.last?.timestamp ?? Date()).addingTimeInterval(-Double(windowDays) * 24 * 3600)

        let recentContactIDs = Set(
            events
                .filter { $0.eventType == "PlanCreated" && $0.timestamp >= cutoff }
                .compactMap { $0.metadata?["contactID"] as? String }
                .filter { !$0.isEmpty }
        )

        // Total contacts = most recent totalConnections value logged
        let totalContacts = events
            .filter { $0.eventType == "ConnectionAdded" }
            .sorted { $0.timestamp < $1.timestamp }
            .last
            .flatMap { $0.metadata?["totalConnections"] as? Int } ?? 0

        let rate = totalContacts > 0 ? Double(recentContactIDs.count) / Double(totalContacts) : 0

        return ContactHangoutRate(
            rate: rate,
            uniqueContactsHungOutWith: recentContactIDs.count,
            totalContacts: totalContacts,
            windowDays: windowDays
        )
    }

    // MARK: - Serialization

    func toDictionary() -> [String: Any] {
        [
            "note": "All rates are 0–1. Multiply by 100 for percentages. Metrics are per-device; average across users to aggregate.",
            "kpi1_weeklyPlanCreationRate": [
                "description": "% of active weeks where user created at least 1 plan (target ≥ 0.40)",
                "value": kpi1WeeklyPlanRate.rate,
                "activeWeeks": kpi1WeeklyPlanRate.activeWeeks,
                "weeksWithPlan": kpi1WeeklyPlanRate.weeksWithPlan
            ],
            "kpi2_medianTimeToFirstPlanSeconds": [
                "description": "Median seconds from app open to plan created (target < 300s / 5 min)",
                "value": kpi2TimeToFirstPlan.medianSeconds,
                "sampleSize": kpi2TimeToFirstPlan.sampleSize,
                "allValuesSecs": kpi2TimeToFirstPlan.allSeconds
            ],
            "kpi3_planToHangoutRate": [
                "description": "% of plans that resulted in a completed hangout (target ≥ 0.50)",
                "completionRate": kpi3PlanToHangoutRate.completionRate,
                "confirmationRate": kpi3PlanToHangoutRate.confirmationRate,
                "plansCreated": kpi3PlanToHangoutRate.plansCreated,
                "hangoutsConfirmed": kpi3PlanToHangoutRate.hangoutsConfirmed,
                "hangoutsCompleted": kpi3PlanToHangoutRate.hangoutsCompleted
            ],
            "kpi4_suggestionAcceptanceRate": [
                "description": "% of suggestions accepted (target ≥ 0.40)",
                "value": kpi4SuggestionAcceptance.rate,
                "accepted": kpi4SuggestionAcceptance.accepted,
                "dismissed": kpi4SuggestionAcceptance.dismissed,
                "generated": kpi4SuggestionAcceptance.generated
            ],
            "kpi5_contactHangoutRate": [
                "description": "% of tracked contacts hung out with in the past 14 days (target ≥ 0.25)",
                "value": kpi5ContactHangoutRate.rate,
                "uniqueContactsHungOutWith": kpi5ContactHangoutRate.uniqueContactsHungOutWith,
                "totalContacts": kpi5ContactHangoutRate.totalContacts,
                "windowDays": kpi5ContactHangoutRate.windowDays
            ]
        ]
    }

    // MARK: - Helpers

    private static func isoWeek(_ date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(c.yearForWeekOfYear ?? 0)-W\(String(format: "%02d", c.weekOfYear ?? 0))"
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
    }
}
