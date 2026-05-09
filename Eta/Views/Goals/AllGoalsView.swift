import SwiftUI

struct AllGoalsView: View {
    let viewModel: HomeViewModel

    @State private var showingCreation = false
    @State private var selectedGoal: Goal?
    @State private var showingGoalDetail = false
    @State private var filter: GoalFilter = .active

    private enum GoalFilter: String, CaseIterable {
        case active = "Active"
        case all = "All"
        case achieved = "Achieved"
    }

    var body: some View {
        NavigationStack {
            Group {
                let goals = filteredGoals
                if goals.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(goals) { goal in
                            Button {
                                selectedGoal = goal
                                showingGoalDetail = true
                            } label: {
                                GoalRow(
                                    goal: goal,
                                    friendNames: friendNames(for: goal)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Picker("Filter", selection: $filter) {
                        ForEach(GoalFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                }
            }
            .navigationDestination(isPresented: $showingGoalDetail) {
                if let goal = selectedGoal {
                    GoalDetailView(
                        goal: goal,
                        contacts: viewModel.contacts,
                        formatter: viewModel.formatter,
                        onSave: { viewModel.saveGoalEdits() },
                        onDelete: { viewModel.deleteGoal(goal) },
                        onPause: { viewModel.pauseGoal(goal) }
                    )
                }
            }
            .sheet(isPresented: $showingCreation) {
                GoalCreationSheet(
                    contacts: viewModel.contacts,
                    formatter: viewModel.formatter,
                    onGoalCreated: { goal in
                        viewModel.createGoal(goal)
                        showingCreation = false
                    }
                )
            }
        }
    }

    private var filteredGoals: [Goal] {
        let all = viewModel.allGoals()
        switch filter {
        case .active:   return all.filter { !$0.isPaused && $0.status != .achieved }
        case .all:      return all
        case .achieved: return all.filter { $0.status == .achieved }
        }
    }

    private func friendNames(for goal: Goal) -> [String] {
        goal.friendIDs.compactMap { id in
            viewModel.contacts.first(where: { $0.id == id })?.givenName
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(filter == .achieved ? "No achieved goals yet." : "No goals yet.")
                .font(.title3.weight(.semibold))
            Text("Tap + to set a goal and start tracking your friendships.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Set a goal") { showingCreation = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GoalRow: View {
    let goal: Goal
    let friendNames: [String]

    var body: some View {
        HStack(spacing: 14) {
            miniRing
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !friendNames.isEmpty {
                        Text(friendNames.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    statusPill
                }
            }
            Spacer()
            Text("\(goal.progress)/\(goal.target)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var miniRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: goal.progressFraction)
                .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 32, height: 32)
    }

    private var statusPill: some View {
        Text(statusLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch goal.status {
        case .onTrack:  return Color(red: 0.2, green: 0.7,  blue: 0.45)
        case .atRisk:   return Color(red: 0.9, green: 0.65, blue: 0.1)
        case .behind:   return Color(red: 0.85, green: 0.35, blue: 0.28)
        case .achieved: return Color(red: 0.3, green: 0.55, blue: 0.9)
        }
    }

    private var statusLabel: String {
        switch goal.status {
        case .onTrack:  return "On track"
        case .atRisk:   return "At risk"
        case .behind:   return "Behind"
        case .achieved: return "Achieved"
        }
    }
}
