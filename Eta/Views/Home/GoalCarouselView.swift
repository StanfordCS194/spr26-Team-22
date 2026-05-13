import SwiftUI

struct GoalCarouselView: View {
    let goals: [Goal]
    let contacts: [TrackedContact]
    let formatter: ContactFormatter
    let onGoalTapped: (Goal) -> Void
    let onAddGoal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Goals")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(action: onAddGoal) {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal)

            if goals.isEmpty {
                GoalCarouselEmptyState(onAddGoal: onAddGoal)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(goals) { goal in
                            Button {
                                onGoalTapped(goal)
                            } label: {
                                GoalCardView(
                                    goal: goal,
                                    friendNames: friendNames(for: goal)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func friendNames(for goal: Goal) -> [String] {
        goal.friendIDs.compactMap { id in
            guard let contact = contacts.first(where: { $0.id == id }) else { return nil }
            return contact.givenName
        }
    }
}

private struct GoalCarouselEmptyState: View {
    let onAddGoal: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "target")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("No goals yet.")
                    .font(.subheadline.weight(.medium))
                Text("Want help setting one?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Set a goal", action: onAddGoal)
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}
