import SwiftUI

/// Tutorial targets owned by MainTabView instead of a single tab view.
enum MainTutorialTarget: Hashable {
    case chatButton
}

/// Generic preference key that gathers anchor frames for tutorial targets.
struct TutorialTargetPreferenceKey<Target: Hashable>: PreferenceKey {
    static var defaultValue: [Target: Anchor<CGRect>] { [:] }

    /// Merges child target anchors into one lookup for the tutorial overlay.
    static func reduce(
        value: inout [Target: Anchor<CGRect>],
        nextValue: () -> [Target: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// Captures this view's bounds so a tutorial pointer can anchor to it.
    func tutorialTarget<Target: Hashable>(_ target: Target) -> some View {
        anchorPreference(key: TutorialTargetPreferenceKey<Target>.self, value: .bounds) { anchor in
            [target: anchor]
        }
    }
}
