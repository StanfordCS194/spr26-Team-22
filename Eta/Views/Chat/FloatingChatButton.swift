import SwiftUI

/// Floating Action Button that presents the LLM chat interface as a sheet.
///
/// Pin this above the tab bar using `.overlay(alignment: .bottomTrailing)` on the TabView.
struct FloatingChatButton: View {
    let viewModel: ChatViewModel
    var onPresented: () -> Void = {}
    var onDismissed: () -> Void = {}
    var analyticsService: AnalyticsService?
    @State private var isPresented = false

    var body: some View {
        Button {
            analyticsService?.logChatOpened()
            isPresented = true
            onPresented()
        } label: {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .tutorialTarget(MainTutorialTarget.chatButton)
        .sheet(isPresented: $isPresented, onDismiss: {
            viewModel.reset()
            onDismissed()
        }) {
            ChatView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}
