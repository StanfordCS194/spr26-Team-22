import SwiftUI

struct HomeView: View {
    let viewModel: HomeViewModel

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var showingGoalCreation = false
    @State private var selectedGoal: Goal?
    @State private var showingGoalDetail = false
    @State private var navigateToFriends = false
    @State private var dismissedWinIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.contacts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.contacts.isEmpty {
                    firstRunState
                } else {
                    mainContent
                }
            }
            .navigationTitle("For You")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await viewModel.refresh() }
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
            .sheet(isPresented: $showingGoalCreation) {
                GoalCreationSheet(
                    contacts: viewModel.contacts,
                    formatter: viewModel.formatter,
                    onGoalCreated: { goal in
                        viewModel.createGoal(goal)
                        // Sheet handles its own dismissal via dismiss() or Done button
                    }
                )
            }
        }
        .task { await viewModel.refresh() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { Task { await viewModel.refresh() } }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerSection
                    .padding(.horizontal)

                insightSection
                    .padding(.horizontal)

                GoalCarouselView(
                    goals: viewModel.activeGoals,
                    contacts: viewModel.contacts,
                    formatter: viewModel.formatter,
                    onGoalTapped: { goal in selectedGoal = goal; showingGoalDetail = true },
                    onAddGoal: { showingGoalCreation = true }
                )

                FriendSpotlightSection(
                    items: viewModel.friendSpotlights,
                    viewModel: viewModel,
                    onAddFriends: { navigateToFriends = true }
                )
                .padding(.horizontal)

                let visibleWins = viewModel.recentWins.filter { !dismissedWinIDs.contains($0.id) }
                if !visibleWins.isEmpty {
                    RecentWinsSection(wins: visibleWins) { win in
                        dismissedWinIDs.insert(win.id)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.greeting)
                .font(.largeTitle.weight(.bold))
            Text(viewModel.weekSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Insight

    private var insightSection: some View {
        Group {
            if let insight = viewModel.currentInsight {
                InsightCard(
                    insight: insight,
                    onAction: {
                        handleInsightAction(insight)
                    },
                    onDismiss: {
                        viewModel.dismissInsight()
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentInsight?.id)
            } else {
                InsightCardEmptyState(onAddFriends: { navigateToFriends = true })
            }
        }
    }

    // MARK: - First run

    private var firstRunState: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                Text("Hi — I'm Eta.")
                    .font(.title.weight(.bold))

                Text("I'll help you stay close to the people who matter. Start by adding a few friends you'd like to keep up with.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Action routing

    private func handleInsightAction(_ insight: PersonalRelationshipInsight) {
        switch insight.primaryAction {
        case .planActivity, .addGoal:
            showingGoalCreation = true
        case .sendCheckIn:
            guard let friendID = insight.friendID,
                  let contact = viewModel.contacts.first(where: { $0.id == friendID }),
                  let phone = contact.phoneNumber else { return }
            let name = contact.givenName.isEmpty ? contact.name : contact.givenName
            var components = URLComponents()
            components.scheme = "sms"
            components.path = phone
            components.queryItems = [URLQueryItem(name: "body", value: "Hey \(name)! How have you been?")]
            guard let url = components.url else { return }
            openURL(url)
        case .snooze:
            viewModel.snoozeInsight()
        case .reflect:
            viewModel.dismissInsight()
        }
    }
}

