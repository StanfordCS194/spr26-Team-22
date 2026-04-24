import SwiftUI

struct SuggestionCard: View {
    let displayName: String
    let timeLabel: String
    let suggestion: Suggestion
    let onDismiss: () -> Void
    let onSchedule: () -> Void

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
                Button("Yes, let's do it!", action: onSchedule)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                Button("Maybe Later", action: onDismiss)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var activityPhrase: String {
        let raw = suggestion.activity.rawValue
        return raw.prefix(1).lowercased() + raw.dropFirst()
    }
}
