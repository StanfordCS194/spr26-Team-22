import SwiftUI

private let etaTeal = Color(red: 0.25, green: 0.48, blue: 0.46)

/// Content for one walkthrough slide.
struct WalkthroughStep {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let primaryButtonTitle: String?

    init(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        primaryButtonTitle: String? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.primaryButtonTitle = primaryButtonTitle
    }
}

/// Modal-style overlay that presents walkthrough slides.
struct WalkthroughOverlay: View {
    let steps: [WalkthroughStep]
    let onPrimaryAction: ((Int) -> Bool)?
    let secondaryButtonTitle: String?
    let onSecondaryAction: (() -> Void)?
    let showsBackButton: Bool
    let onBackAction: (() -> Void)?
    let onDismiss: () -> Void

    @State private var currentStep = 0
    @State private var appeared = false

    init(
        steps: [WalkthroughStep],
        onPrimaryAction: ((Int) -> Bool)? = nil,
        secondaryButtonTitle: String? = nil,
        onSecondaryAction: (() -> Void)? = nil,
        showsBackButton: Bool = false,
        onBackAction: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.steps = steps
        self.onPrimaryAction = onPrimaryAction
        self.secondaryButtonTitle = secondaryButtonTitle
        self.onSecondaryAction = onSecondaryAction
        self.showsBackButton = showsBackButton
        self.onBackAction = onBackAction
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentStep ? etaTeal : Color.white.opacity(0.3))
                            .frame(width: index == currentStep ? 24 : 8, height: 6)
                            .animation(.easeInOut(duration: 0.25), value: currentStep)
                    }
                }

                let step = steps[currentStep]

                ZStack {
                    Circle()
                        .fill(step.iconColor.opacity(0.15))
                        .frame(width: 72, height: 72)

                    Image(systemName: step.icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(step.iconColor)
                        .symbolEffect(.bounce, value: currentStep)
                }

                Text(step.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(step.description)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)

                HStack(spacing: 12) {
                    if currentStep > 0 || showsBackButton {
                        Button {
                            if currentStep > 0 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    currentStep -= 1
                                }
                            } else {
                                onBackAction?()
                            }
                        } label: {
                            Text("Back")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.15))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    Button {
                        if onPrimaryAction?(currentStep) == true {
                            return
                        }
                        if currentStep < steps.count - 1 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentStep += 1
                            }
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text(step.primaryButtonTitle ?? (currentStep < steps.count - 1 ? "Next" : "Got it!"))
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(etaTeal)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if let secondaryButtonTitle, let onSecondaryAction {
                        Button {
                            onSecondaryAction()
                        } label: {
                            Text(secondaryButtonTitle)
                                .font(.system(size: 15, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.15))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    /// Animates the walkthrough out, then notifies the owner.
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}
