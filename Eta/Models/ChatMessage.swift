import Foundation

struct ChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let content: String
    /// Set when the assistant's response contains a parsed function call.
    var functionCall: ChatFunctionCall? = nil
}

/// Tab the app should navigate to after a chat action completes.
/// MainTabView maps these to its internal TabChoice.
enum ChatNavigation {
    case events
    case suggestions
}

/// Structured actions the LLM can invoke once it has gathered enough context.
enum ChatFunctionCall: Equatable {
    case scheduleHangout(friendName: String, activity: String, proposedTime: String)
    case reflectOnTrends(period: String)
    case setGoal(friendName: String, goal: String)
    case provideFeedback(friendName: String, activity: String, sentiment: String)

    var displayLabel: String {
        switch self {
        case .scheduleHangout(let name, let activity, let time):
            return "Schedule \(activity) with \(name) · \(time)"
        case .reflectOnTrends(let period):
            return "Reflect on \(period)"
        case .setGoal(let name, let goal):
            return "Set goal for \(name): \(goal)"
        case .provideFeedback(let name, let activity, _):
            return "Log feedback for \(activity) with \(name)"
        }
    }

    var systemImageName: String {
        switch self {
        case .scheduleHangout:  return "calendar.badge.plus"
        case .reflectOnTrends:  return "chart.bar"
        case .setGoal:          return "target"
        case .provideFeedback:  return "hand.thumbsup"
        }
    }
}
