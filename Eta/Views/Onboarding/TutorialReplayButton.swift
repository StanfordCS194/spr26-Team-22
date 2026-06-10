import SwiftUI

private let tutorialReplayTeal = Color(red: 0.25, green: 0.48, blue: 0.46)

/// Bottom-left help button used to restart an interactive tab tutorial.
struct TutorialReplayButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    /// Builds the tappable circular replay control.
    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tutorialReplayTeal)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
        .contentShape(Circle())
        .zIndex(10)
    }
}
