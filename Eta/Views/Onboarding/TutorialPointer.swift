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
    var showsArrow = true

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if showsArrow {
                arrowImage
                    .position(clamped(arrowPosition, horizontalMargin: 24, verticalMargin: 24))
            }

            textBox
                .scaleEffect(isPulsing ? 1.03 : 0.98)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
                .position(clamped(textPosition, horizontalMargin: 118, verticalMargin: 40))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { isPulsing = true }
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

    /// Places the arrow directly beside the target edge it points at.
    private var arrowPosition: CGPoint {
        let edgeSpacing: CGFloat = 18
        switch arrowType {
        case .up:
            return CGPoint(x: targetFrame.midX, y: targetFrame.maxY + edgeSpacing)
        case .down:
            return CGPoint(x: targetFrame.midX, y: targetFrame.minY - edgeSpacing)
        case .left:
            return CGPoint(x: targetFrame.maxX + edgeSpacing, y: targetFrame.midY)
        case .right:
            return CGPoint(x: targetFrame.minX - edgeSpacing, y: targetFrame.midY)
        case .upperLeft:
            return CGPoint(x: targetFrame.maxX + edgeSpacing, y: targetFrame.maxY + edgeSpacing)
        case .lowerLeft:
            return CGPoint(x: targetFrame.maxX + edgeSpacing, y: targetFrame.minY - edgeSpacing)
        case .upperRight:
            return CGPoint(x: targetFrame.minX - edgeSpacing, y: targetFrame.maxY + edgeSpacing)
        case .lowerRight:
            return CGPoint(x: targetFrame.minX - edgeSpacing, y: targetFrame.minY - edgeSpacing)
        }
    }

    /// Places the text box on the opposite side of the arrow from the target.
    private var textPosition: CGPoint {
        let horizontalSpacing: CGFloat = 138
        let verticalSpacing: CGFloat = 56
        switch arrowType {
        case .up:
            return CGPoint(x: arrowPosition.x, y: arrowPosition.y + verticalSpacing)
        case .down:
            return CGPoint(x: arrowPosition.x, y: arrowPosition.y - verticalSpacing)
        case .left:
            return CGPoint(x: arrowPosition.x + horizontalSpacing, y: arrowPosition.y)
        case .right:
            return CGPoint(x: arrowPosition.x - horizontalSpacing, y: arrowPosition.y)
        case .upperLeft:
            return CGPoint(x: arrowPosition.x + horizontalSpacing, y: arrowPosition.y + verticalSpacing)
        case .lowerLeft:
            return CGPoint(x: arrowPosition.x + horizontalSpacing, y: arrowPosition.y - verticalSpacing)
        case .upperRight:
            return CGPoint(x: arrowPosition.x - horizontalSpacing, y: arrowPosition.y + verticalSpacing)
        case .lowerRight:
            return CGPoint(x: arrowPosition.x - horizontalSpacing, y: arrowPosition.y - verticalSpacing)
        }
    }

    /// Keeps pointer content inside the visible overlay area.
    private func clamped(
        _ point: CGPoint,
        horizontalMargin: CGFloat,
        verticalMargin: CGFloat
    ) -> CGPoint {
        return CGPoint(
            x: min(max(point.x, horizontalMargin), max(horizontalMargin, containerSize.width - horizontalMargin)),
            y: min(max(point.y, verticalMargin), max(verticalMargin, containerSize.height - verticalMargin))
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
