//
//  SessionInfo.swift
//  Eta
//
//  Created on 4/23/26.
//

import Foundation

/// Information about a user session for display and export selection.
struct SessionInfo: Identifiable {
    let sessionID: String
    let startTime: Date
    let endTime: Date
    let eventCount: Int
    
    var id: String { sessionID }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)m \(seconds)s"
    }
}
