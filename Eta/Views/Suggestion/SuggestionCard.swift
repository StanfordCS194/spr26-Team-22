import SwiftUI

/// Displays a single opportunity-driven hangout suggestion.
///
/// Receives pre-formatted strings from SuggestionViewModel — no ViewModel
/// reference needed here. The "Yes" button is intentionally disabled in PR 4;
/// it will be wired to InviteService in PR 5.
struct SuggestionCard: View {
    let displayName: String
    let timeLabel: String
    let suggestion: Suggestion
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("You have time \(timeLabel) —")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("want to \(activityPhrase) with \(displayName)?")
                    .font(.title)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(suggestion.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            VStack(spacing: 12) {
                Button("Yes, let's do it!") { }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(true) // wired in PR 5

                Button("Maybe Later", action: onDismiss)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Lowercases the first character of the activity rawValue so it reads as
    /// natural prose: "want to grab coffee" not "want to Grab coffee".
    private var activityPhrase: String {
        let raw = suggestion.activity.rawValue
        return raw.prefix(1).lowercased() + raw.dropFirst()
    }
}
