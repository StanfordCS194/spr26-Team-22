import SwiftUI

enum TabWalkthroughs {

    static let availability = [
        WalkthroughStep(
            icon: "clock.badge.checkmark",
            iconColor: .blue,
            title: "Set Your Availability",
            description: "Tell Eta when you're free so it can suggest hangouts at the right times.",
            primaryButtonTitle: "Try it"
        ),
        WalkthroughStep(
            icon: "hand.draw",
            iconColor: .indigo,
            title: "Drag to Toggle Hours",
            description: "Drag your finger over an hour to mark it as free or busy. Your availability is saved automatically.",
            primaryButtonTitle: "Try it"
        ),
        WalkthroughStep(
            icon: "calendar.badge.clock",
            iconColor: .teal,
            title: "Plan Ahead",
            description: "Swipe between different days to set your availability for the week. You can also set recurring time blocks. The more you add the better your suggestions.",
            primaryButtonTitle: "Try it"
        ),
        WalkthroughStep(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "Availability Set!",
            description: "You're ready to get hangout suggestions!"
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
            icon: "ellipsis.circle",
            iconColor: .green,
            title: "Add Friends",
            description: "Tap the ••• button to add friends from your contacts and tag your relationships. Eta will track how often you hang out.",
            primaryButtonTitle: "Try it"
        ),
        WalkthroughStep(
            icon: "heart.text.clipboard",
            iconColor: .pink,
            title: "Relationship Goals",
            description: "Set relationship goals you want to meet. Each friend shows a health score based on how recently you've spent time together.",
            primaryButtonTitle: "Try it"
        ),
        WalkthroughStep(
            icon: "gearshape",
            iconColor: .white,
            title: "Preferences",
            description: "Set your own preferences in Settings!",
            primaryButtonTitle: "Try it"
        ),
        WalkthroughStep(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "All set!",
            description: "Let us know your availability and you can schedule some hangouts!",
            primaryButtonTitle: "Done"
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
            title: "Use the Chatbot",
            description: "You can use the chatbot to set goals, add preferences, and schedule hangouts with ease!",
            primaryButtonTitle: "Try it"
        ),
        WalkthroughStep(
            icon: "checklist",
            iconColor: .green,
            title: "Finished",
            description: "You're ready to use the app.",
            primaryButtonTitle: "Done"
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
            title: "Tap to Refresh",
            description: "Not feeling it? You can edit its details yourself or tap the refresh button for a new one.",
            primaryButtonTitle: "Try it"
        ),
        WalkthroughStep(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "Go to the Events tab to see your new event!",
            description: "",
            primaryButtonTitle: "Done"
        ),
    ]
}
