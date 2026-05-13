import SwiftUI

/// Full chat UI — message list, typing indicator, text input, and action confirmation banner.
struct ChatView: View {
    let viewModel: ChatViewModel
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                    .animation(.default, value: viewModel.messages.count)
                    .animation(.default, value: viewModel.isSending)

                if let call = viewModel.pendingFunctionCall {
                    actionBanner(call)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35), value: viewModel.pendingFunctionCall != nil)
                }

                inputBar
            }
            .navigationTitle("Eta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.reset()
                        dismiss()
                    }
                }
            }
            .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
                if shouldDismiss {
                    viewModel.reset()
                    dismiss()
                }
            }
        }
    }

    // MARK: — Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isSending {
                        TypingIndicator()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in scrollToBottom(proxy: proxy) }
            .onChange(of: viewModel.isSending)      { _, _ in scrollToBottom(proxy: proxy) }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            if viewModel.isSending {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: — Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("What can I help with?")
                    .font(.headline)
                Text("Schedule a hangout, reflect on trends,\nset a goal, or log feedback.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: — Action banner

    private func actionBanner(_ call: ChatFunctionCall) -> some View {
        HStack(spacing: 12) {
            // Icon on accent background — force dark scheme so .primary resolves to light.
            Image(systemName: call.systemImageName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: Circle())
                .environment(\.colorScheme, .dark)

            Text(call.displayLabel)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            Spacer()

            Button("Confirm") {
                viewModel.invokeAction(call)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: — Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)
                .onSubmit { sendIfNeeded() }
                .disabled(viewModel.isSending)

            Button {
                sendIfNeeded()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Color.accentColor : Color.secondary)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSending
    }

    private func sendIfNeeded() {
        guard canSend else { return }
        let text = inputText
        inputText = ""
        Task { await viewModel.send(text) }
    }
}

// MARK: — MessageBubble

private struct MessageBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            bubble
            if !isUser { Spacer(minLength: 60) }
        }
    }

    /// Separate branches so that `.environment(\.colorScheme, .dark)` is applied only
    /// to user bubbles — assistant bubbles adapt to the system color scheme naturally.
    @ViewBuilder
    private var bubble: some View {
        if isUser {
            Text(message.content)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(.primary)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18))
                // Force dark scheme inside the accent-colored bubble so .primary
                // resolves to its light (accessible) variant.
                .environment(\.colorScheme, .dark)
        } else {
            Text(message.content)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(.primary)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}

// MARK: — TypingIndicator

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .frame(width: 7, height: 7)
                        .foregroundStyle(.secondary)
                        .scaleEffect(animating ? 1.0 : 0.6)
                        .opacity(animating ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}
