import Foundation

/// A type that can represent a hangout activity.
///
/// Conforming types must be Comparable and expose a plain-English description
/// suitable for embedding directly into UI text and LLM prompts.
///
/// Today: Activity enum (structured, hardcoded pool).
/// Tomorrow: String (LLM-generated, open-ended).
/// Both paths erase to description: String at the ActivityProposal boundary.
protocol ActivityRepresentable {
    var description: String { get }
}

extension String: ActivityRepresentable {}
