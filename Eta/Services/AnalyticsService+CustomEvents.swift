//
//  AnalyticsService+CustomEvents.swift
//  Eta
//
//  Created on 4/23/26.
//

import Foundation

/// Extension point for adding custom analytics events.
///
/// How to add a new KPI:
/// 1. Add a new function here following the naming pattern log<EventName>
/// 2. Call logEvent() with appropriate type, category, value, and metadata
/// 3. Update AnalyticsSummary.swift to compute statistics for your new KPI
/// 4. Update Analytics/analyze.py to display your new KPI
///
/// Example:
/// ```
/// extension AnalyticsService {
///     func logProfileViewed(username: String, duration: TimeInterval) {
///         logEvent(
///             type: "ProfileViewed",
///             category: .navigation,
///             value: username,
///             metadata: ["duration": duration]
///         )
///     }
/// }
/// ```
///
/// Then in your view:
/// ```
/// analyticsService.logProfileViewed(username: "Alice", duration: 45.2)
/// ```

extension AnalyticsService {
    // MARK: - Custom Event Examples
    
    // Uncomment and modify these templates to add your own KPIs:
    
    /*
    func logCustomEvent(name: String, details: [String: Any]? = nil) {
        logEvent(
            type: name,
            category: .custom,  // Add this category to AnalyticsEvent.Category
            metadata: details
        )
    }
    */
    
    /*
    func logFeatureUsed(featureName: String, timeSpent: TimeInterval) {
        logEvent(
            type: "FeatureUsed",
            category: .engagement,  // Add this category
            value: featureName,
            metadata: ["timeSpent": timeSpent]
        )
    }
    */
}
