//
//  AnalyticsEvent.swift
//  Eta
//

import Foundation
import SwiftData

@Model
final class AnalyticsEvent {
    var id: UUID
    var sessionID: String
    var timestamp: Date
    var eventType: String
    var category: String
    var value: String?
    var metadataJSON: String?

    init(sessionID: String, eventType: String, category: String, value: String? = nil, metadata: [String: Any]? = nil) {
        self.id = UUID()
        self.sessionID = sessionID
        self.timestamp = Date()
        self.eventType = eventType
        self.category = category
        self.value = value
        self.metadataJSON = metadata?.toJSONString()
    }

    var metadata: [String: Any]? {
        guard let json = metadataJSON,
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
}

extension AnalyticsEvent {
    enum Category: String {
        case lifecycle   = "Lifecycle"
        case navigation  = "Navigation"
        case connection  = "Connection"
        case suggestion  = "Suggestion"
        case plan        = "Plan"
    }
}

extension Dictionary where Key == String, Value == Any {
    func toJSONString() -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: []),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}
