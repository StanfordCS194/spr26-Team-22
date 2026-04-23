import Foundation

/// Determines how a single suggestion is selected from a list of relationship health scores.
///
/// Today: RulesSuggestionStrategy (sorts by score, picks top contact).
/// Tomorrow: on-device ML model.
/// Swap implementations in EtaApp.swift without touching SuggestionService.
protocol SuggestionStrategy {
    func suggest(from healthScores: [RelationshipHealth]) -> Suggestion?
}
