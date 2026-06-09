import SwiftUI

enum TabWalkthroughs {

    static let availability = [
        WalkthroughStep(
            icon: "clock.badge.checkmark",
            iconColor: .blue,
            title: "Set Your Availability",
            description: "Tell Eta when you're free so it can suggest hangouts at the right times."
        ),
        WalkthroughStep(
            icon: "hand.tap",
            iconColor: .indigo,
            title: "Tap to Toggle Hours",
            description: "Tap any hour block to mark it as free or busy. Your availability is saved automatically."
        ),
        WalkthroughStep(
            icon: "calendar.badge.clock",
            iconColor: .teal,
            title: "Plan Ahead",
            description: "Swipe between days to set your availability for the week. The more you add, the better your suggestions."
        ),
    ]

    static let friends = [
        WalkthroughStep(
            icon: "person.2.fill",
            iconColor: .purple,
            title: "Your Friends",
            description: "This is where you manage the friends you want to stay connected with."
        ),
        WalkthroughStep(
            icon: "plus.circle.fill",
            iconColor: .green,
            title: "Add Friends",
            description: "Tap the + button to add friends from your contacts. Eta will track how often you hang out."
        ),
        WalkthroughStep(
            icon: "heart.text.clipboard",
            iconColor: .pink,
            title: "Relationship Health",
            description: "Each friend shows a health score based on how recently you've spent time together."
        ),
    ]

    static let events = [
        WalkthroughStep(
            icon: "cup.and.saucer",
            iconColor: .orange,
            title: "Upcoming Events",
            description: "See all your scheduled hangouts in one place. This is your social calendar."
        ),
        WalkthroughStep(
            icon: "camera.fill",
            iconColor: .mint,
            title: "Capture Memories",
            description: "After a hangout, tap the camera icon to snap a photo. It'll show up on future suggestions."
        ),
        WalkthroughStep(
            icon: "clock.arrow.circlepath",
            iconColor: .cyan,
            title: "Event History",
            description: "Scroll down to see past hangouts and track your social activity over time."
        ),
    ]

    static let suggestions = [
        WalkthroughStep(
            icon: "sparkles",
            iconColor: .orange,
            title: "Smart Suggestions",
            description: "Eta finds the perfect time and friend for a hangout based on your availability and relationship health."
        ),
        WalkthroughStep(
            icon: "paperplane.fill",
            iconColor: .pink,
            title: "Send an Invite",
            description: "Like a suggestion? Tap to send an iMessage invite with the activity and time pre-filled."
        ),
        WalkthroughStep(
            icon: "arrow.clockwise",
            iconColor: .teal,
            title: "Pull to Refresh",
            description: "Not feeling it? Pull down to get a new suggestion, or tap 'Maybe Later' to dismiss."
        ),
    ]
}
