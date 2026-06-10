import SwiftUI

private let tutorialPointerGreen = Color(red: 0.08, green: 0.82, blue: 0.22)

/// Directions supported by tutorial pointer arrows.
enum TutorialPointerArrowType {
    case up
    case down
    case left
    case right
    case upperLeft
    case lowerLeft
    case upperRight
    case lowerRight
}

/// Anchors a short coaching callout to a target control during interactive tutorials.
struct TutorialPointer: View {
    let arrowType: TutorialPointerArrowType
    let targetFrame: CGRect
    let containerSize: CGSize
    let description: String

    @State private var isPulsing = false

    var body: some View {
        pointerContent
            .scaleEffect(isPulsing ? 1.03 : 0.98)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
            .position(calloutPosition)
    }

    /// Lays out the arrow between the target and the text box.
    @ViewBuilder
    private var pointerContent: some View {
        switch arrowType {
        case .up:
            VStack(spacing: 6) {
                arrowImage
                textBox
            }
        case .down:
            VStack(spacing: 6) {
                textBox
                arrowImage
            }
        case .left:
            HStack(spacing: 8) {
                arrowImage
                textBox
            }
        case .right:
            HStack(spacing: 8) {
                textBox
                arrowImage
            }
        case .upperLeft, .upperRight:
            VStack(spacing: 6) {
                arrowImage
                textBox
            }
        case .lowerLeft, .lowerRight:
            VStack(spacing: 6) {
                textBox
                arrowImage
            }
        }
    }

    /// Builds the bright green tutorial label.
    private var textBox: some View {
        Text(description)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 210)
            .background(tutorialPointerGreen, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    /// Builds the directional arrow icon for the pointer.
    private var arrowImage: some View {
        Image(systemName: arrowType.systemImageName)
            .font(.title2.weight(.bold))
            .foregroundStyle(tutorialPointerGreen)
    }

    /// Computes a clamped position for the pointer near its target.
    private var calloutPosition: CGPoint {
        let spacing: CGFloat = 70
        let proposed: CGPoint
        switch arrowType {
        case .up:
            proposed = CGPoint(x: targetFrame.midX, y: targetFrame.maxY + spacing)
        case .down:
            proposed = CGPoint(x: targetFrame.midX, y: targetFrame.minY - spacing)
        case .left:
            proposed = CGPoint(x: targetFrame.maxX + 130, y: targetFrame.midY)
        case .right:
            proposed = CGPoint(x: targetFrame.minX - 130, y: targetFrame.midY)
        case .upperLeft:
            proposed = CGPoint(x: targetFrame.maxX + 130, y: targetFrame.maxY + spacing)
        case .lowerLeft:
            proposed = CGPoint(x: targetFrame.maxX + 130, y: targetFrame.minY - spacing)
        case .upperRight:
            proposed = CGPoint(x: targetFrame.minX - 130, y: targetFrame.maxY + spacing)
        case .lowerRight:
            proposed = CGPoint(x: targetFrame.minX - 130, y: targetFrame.minY - spacing)
        }

        return CGPoint(
            x: min(max(proposed.x, 120), max(120, containerSize.width - 120)),
            y: min(max(proposed.y, 70), max(70, containerSize.height - 70))
        )
    }
}

private extension TutorialPointerArrowType {
    /// Maps semantic arrow directions to SF Symbol names.
    var systemImageName: String {
        switch self {
        case .up:
            return "arrow.up"
        case .down:
            return "arrow.down"
        case .left:
            return "arrow.left"
        case .right:
            return "arrow.right"
        case .upperLeft:
            return "arrow.up.left"
        case .lowerLeft:
            return "arrow.down.left"
        case .upperRight:
            return "arrow.up.right"
        case .lowerRight:
            return "arrow.down.right"
        }
    }
}
