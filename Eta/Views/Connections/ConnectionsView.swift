import SwiftUI

/// Friends tab for managing contacts, relationship tags, and friend health.
struct ConnectionsView: View {
    let viewModel: ConnectionsViewModel
    let homeViewModel: HomeViewModel
    let settingsViewModel: SettingsViewModel
    let analyticsService: AnalyticsService
    let weeklyCheckInState: WeeklyCheckInState
    let onShowSettings: () -> Void
    let isTutorialActive: Bool
    let tutorialRequestID: Int
    let settingsDismissCount: Int
    let onTutorialDone: () -> Void
    let onTutorialNext: () -> Void

    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var isSelecting = false
    @State private var selectedContactIDs: Set<UUID> = []
    @State private var showingBulkTagPicker = false
    @State private var bulkEditingTags: [ContactTag] = []
    @State private var showingDeleteConfirmation = false
    @State private var tutorialPhase: FriendsTutorialPhase = .none
    @State private var tutorialContactCount = 0
    @State private var startedTutorialRequestID: Int?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isSearching) private var isSearching

    private var displayedContacts: [TrackedContact] {
        guard !searchText.isEmpty else { return viewModel.filteredContacts }
        return viewModel.filteredContacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var selectedContacts: [TrackedContact] {
        displayedContacts.filter { selectedContactIDs.contains($0.id) }
    }

    private var existingCustomLabels: [TagSubcategory: [String]] {
        var result: [TagSubcategory: [String]] = [:]
        for contact in viewModel.contacts {
            for tag in contact.contextTags {
                guard let label = tag.customLabel, !label.isEmpty else { continue }
                result[tag.subcategory, default: []].append(label)
            }
        }
        for key in result.keys { result[key] = Array(Set(result[key]!)).sorted() }
        return result
    }

    private var deleteDialogTitle: String {
        let n = selectedContactIDs.count
        return "Delete \(n) friend\(n == 1 ? "" : "s")?"
    }

    /// Refreshes friendship data when the app returns to the foreground.
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        Task {
            await viewModel.loadHealthScores()
            await homeViewModel.refresh()
        }
    }

    @ViewBuilder
    private var forYouSection: some View {
        if shouldShowForYouSection {
            Section {
                ForEach(homeViewModel.friendSpotlights) { item in
                    NavigationLink {
                        FriendDetailView(
                            contact: item.contact,
                            health: item.health,
                            displayName: homeViewModel.displayName(for: item.contact),
                            homeViewModel: homeViewModel,
                            onTutorialProfileOpened: handleTutorialProfileOpened,
                            onTutorialProfileDismissed: handleTutorialProfileDismissed,
                            onTutorialGoalCreated: handleTutorialGoalCreated
                        )
                    } label: {
                        FriendSpotlightCard(
                            item: item,
                            displayName: homeViewModel.displayName(for: item.contact)
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                if settingsViewModel.preferences.weeklyCheckInEnabled {
                    Button {
                        weeklyCheckInState.trigger()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.circle")
                                .font(.title3)
                                .foregroundStyle(homeViewModel.hasCompletedCheckInThisWeek ? Color.accentColor : .orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(weeklyCheckInCaptionText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(weeklyCheckInStatusText)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.04), radius: 5, y: 1)
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            } header: {
                Text("For You")
                    .font(.title3.weight(.semibold))
                    .textCase(nil)
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }
        }
    }

    private var shouldShowForYouSection: Bool {
        !isSelecting
            && searchText.isEmpty
            && (!homeViewModel.friendSpotlights.isEmpty || settingsViewModel.preferences.weeklyCheckInEnabled)
    }

    @ViewBuilder
    private var allFriendsSection: some View {
        Section {
            ForEach(displayedContacts) { contact in
                if isSelecting {
                    Button {
                        if selectedContactIDs.contains(contact.id) {
                            selectedContactIDs.remove(contact.id)
                        } else {
                            selectedContactIDs.insert(contact.id)
                        }
                    } label: {
                        ContactRow(
                            contact: contact,
                            viewModel: viewModel,
                            isSelecting: true,
                            isSelected: selectedContactIDs.contains(contact.id),
                            activeFilter: viewModel.selectedTagFilter
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                } else {
                    NavigationLink {
                        FriendDetailView(
                            contact: contact,
                            health: viewModel.healthScores[contact.id] ?? RelationshipHealth(
                                contact: contact,
                                lastHangoutDate: nil,
                                lastHangoutTitle: nil,
                                hangoutCount: 0,
                                score: 0,
                                upcomingHangout: nil
                            ),
                            displayName: viewModel.displayName(for: contact),
                            homeViewModel: homeViewModel,
                            onTutorialProfileOpened: handleTutorialProfileOpened,
                            onTutorialProfileDismissed: handleTutorialProfileDismissed,
                            onTutorialGoalCreated: handleTutorialGoalCreated
                        )
                    } label: {
                        ContactRow(contact: contact, viewModel: viewModel, activeFilter: viewModel.selectedTagFilter)
                            .tutorialTarget(FriendsTutorialTarget.friendRow)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                }
            }
            .onDelete { indexSet in
                guard !isSelecting else { return }
                for index in indexSet {
                    let contact = displayedContacts[index]
                    analyticsService.logConnectionRemoved(
                        contactName: contact.name,
                        totalContacts: viewModel.contacts.count - 1
                    )
                    viewModel.removeContact(contact)
                }
                Task { await homeViewModel.refresh() }
            }
        } header: {
            Text("All Friends")
                .font(.title3.weight(.semibold))
                .textCase(nil)
                .foregroundStyle(.primary)
                .padding(.top, 4)
        }
    }

    private var contactList: some View {
        List {
            if !isSearching {
                Section {} header: { filterBar }
            }
            forYouSection
            allFriendsSection
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.contacts.isEmpty {
                    ContentUnavailableView(
                        "No Friends Yet",
                        systemImage: "person.2",
                        description: Text("Tap + to add friends you want to keep up with.")
                    )
                } else if isSearching && searchText.isEmpty {
                    Color.clear
                } else {
                    contactList
                }
            }
            .navigationTitle("Friends")
            .searchable(text: $searchText, prompt: "Search friends")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelecting {
                        Button("Cancel") {
                            isSelecting = false
                            selectedContactIDs = []
                        }
                    } else {
                        Button { onShowSettings() } label: {
                            Image(systemName: "gearshape")
                        }
                        .tutorialTarget(FriendsTutorialTarget.settingsButton)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelecting {
                        Button(selectedContactIDs.count == displayedContacts.count ? "Deselect All" : "Select All") {
                            if selectedContactIDs.count == displayedContacts.count {
                                selectedContactIDs = []
                            } else {
                                selectedContactIDs = Set(displayedContacts.map(\.id))
                            }
                        }
                    } else {
                        Menu {
                            Button {
                                analyticsService.logButtonTapped(screen: "ConnectionsView", button: "AddConnection")
                                showingAddSheet = true
                            } label: {
                                Label("Add Contact", systemImage: "person.badge.plus")
                            }
                            Button {
                                isSelecting = true
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .tutorialTarget(FriendsTutorialTarget.moreButton)
                    }
                }
            }
            .toolbar(isSelecting ? .hidden : .visible, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    HStack {
                        Button {
                            bulkEditingTags = []
                            showingBulkTagPicker = true
                        } label: {
                            Label(
                                selectedContactIDs.isEmpty ? "Tag" : "Tag (\(selectedContactIDs.count))",
                                systemImage: "tag"
                            )
                        }
                        .disabled(selectedContactIDs.isEmpty)

                        Spacer()

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(
                                selectedContactIDs.isEmpty ? "Delete" : "Delete (\(selectedContactIDs.count))",
                                systemImage: "trash"
                            )
                        }
                        .disabled(selectedContactIDs.isEmpty)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddConnectionSheet(
                    viewModel: viewModel,
                    analyticsService: analyticsService
                )
            }
            .sheet(isPresented: $showingBulkTagPicker) {
                ContactTagPickerView(
                    selectedTags: $bulkEditingTags,
                    onDone: {
                        for contact in selectedContacts {
                            homeViewModel.updateTags(bulkEditingTags, for: contact)
                        }
                        isSelecting = false
                        selectedContactIDs = []
                    },
                    existingLabels: existingCustomLabels
                )
            }
            .confirmationDialog(
                deleteDialogTitle,
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    for contact in selectedContacts {
                        analyticsService.logConnectionRemoved(
                            contactName: contact.name,
                            totalContacts: viewModel.contacts.count - selectedContactIDs.count
                        )
                        viewModel.removeContact(contact)
                    }
                    isSelecting = false
                    selectedContactIDs = []
                    Task { await homeViewModel.refresh() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                viewModel.loadContacts()
                await viewModel.loadHealthScores()
                await homeViewModel.refresh()
                await homeViewModel.geocodeMissingCities()
                startFriendsTutorialIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in handleScenePhaseChange(newPhase) }
            .onChange(of: isTutorialActive) { _, isActive in
                if !isActive {
                    tutorialPhase = .none
                    startedTutorialRequestID = nil
                } else {
                    startFriendsTutorialIfNeeded()
                }
            }
            .onChange(of: tutorialRequestID) { _, _ in
                startFriendsTutorialIfNeeded()
            }
            .onChange(of: viewModel.contacts.count) { _, count in
                // The add-friend pointer stays up until the contact list actually grows.
                guard tutorialPhase == .addPointer, count > tutorialContactCount else { return }
                tutorialPhase = .healthSlide
            }
            .onChange(of: settingsDismissCount) { _, _ in
                // Settings lives in MainTabView, so this counter lets the tab know the sheet closed.
                guard tutorialPhase == .settingsPointer else { return }
                tutorialPhase = .completeSlide
            }
            .overlayPreferenceValue(TutorialTargetPreferenceKey<FriendsTutorialTarget>.self) { targets in
                GeometryReader { proxy in
                    friendsTutorialOverlay(targets: targets, proxy: proxy)
                }
                .allowsHitTesting(tutorialPhase != .none)
            }
            .trackScreen("ConnectionsView", analytics: analyticsService)
        }
    }

    /// Renders the Friends tutorial slides and target pointers.
    @ViewBuilder
    private func friendsTutorialOverlay(
        targets: [FriendsTutorialTarget: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        ZStack {
            friendsTutorialPointers(targets: targets, proxy: proxy)
                .allowsHitTesting(false)

            if let step = tutorialPhase.walkthroughStep {
                WalkthroughOverlay(
                    steps: [step],
                    onPrimaryAction: { _ in
                        handleFriendsTutorialPrimaryAction()
                        return true
                    },
                    primaryButtonTitleOverride: tutorialPhase == .completeSlide ? "Next Step" : nil,
                    secondaryButtonTitle: tutorialPhase == .completeSlide ? "Done" : nil,
                    onSecondaryAction: tutorialPhase == .completeSlide ? {
                        finishFriendsTutorial()
                    } : nil,
                    showsBackButton: tutorialPhase.hasPreviousSlide,
                    onBackAction: {
                        goBackInFriendsTutorial()
                    },
                    onDismiss: {
                        finishFriendsTutorial()
                    }
                )
            }
        }
    }

    /// Shows the current Friends tutorial pointer for the active interaction phase.
    @ViewBuilder
    private func friendsTutorialPointers(
        targets: [FriendsTutorialTarget: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        switch tutorialPhase {
        case .addPointer:
            friendsPointer(
                target: .moreButton,
                in: targets,
                proxy: proxy,
                arrowType: .upperRight,
                description: "Add friends."
            )
        case .settingsPointer:
            friendsPointer(
                target: .settingsButton,
                in: targets,
                proxy: proxy,
                arrowType: .upperLeft,
                description: "Indicate your preferences."
            )
        case .goalListPointer:
            friendsPointer(
                target: .friendRow,
                in: targets,
                proxy: proxy,
                arrowType: .down,
                description: "Tap here and add a goal!",
                showsArrow: false
            )
        case .goalButtonPointer:
            friendsPointer(
                target: .addGoalButton,
                in: targets,
                proxy: proxy,
                arrowType: .down,
                description: "Set a relationship goal."
            )
        case .none, .introSlide, .addSlide, .healthSlide, .preferencesSlide, .completeSlide:
            EmptyView()
        }
    }

    /// Anchors a Friends tutorial pointer to a toolbar target when available.
    @ViewBuilder
    private func friendsPointer(
        target: FriendsTutorialTarget,
        in targets: [FriendsTutorialTarget: Anchor<CGRect>],
        proxy: GeometryProxy,
        arrowType: TutorialPointerArrowType,
        description: String,
        showsArrow: Bool = true
    ) -> some View {
        if let anchor = targets[target] {
            TutorialPointer(
                arrowType: arrowType,
                targetFrame: proxy[anchor],
                containerSize: proxy.size,
                description: description,
                showsArrow: showsArrow
            )
        }
    }

    /// Resets tracking and starts the Friends tutorial at its first slide.
    private func startFriendsTutorial() {
        tutorialContactCount = viewModel.contacts.count
        tutorialPhase = .introSlide
    }

    /// Starts the Friends tutorial once for the active parent request.
    private func startFriendsTutorialIfNeeded() {
        guard isTutorialActive, tutorialRequestID > 0 else { return }
        guard startedTutorialRequestID != tutorialRequestID else { return }
        startedTutorialRequestID = tutorialRequestID
        startFriendsTutorial()
    }

    /// Marks the Friends tutorial complete and notifies the parent tab coordinator.
    private func finishFriendsTutorial() {
        UserDefaults.standard.set(true, forKey: "walkthrough_friends")
        tutorialPhase = .none
        startedTutorialRequestID = nil
        onTutorialDone()
    }

    /// Advances after the user opens a friend profile from the relationship-goals pointer.
    private func handleTutorialProfileOpened() {
        guard tutorialPhase == .goalListPointer else { return }
        tutorialPhase = .goalButtonPointer
    }

    /// Advances if the user leaves the profile before creating a goal.
    private func handleTutorialProfileDismissed() {
        guard tutorialPhase == .goalButtonPointer else { return }
        tutorialPhase = .preferencesSlide
    }

    /// Advances after the user creates a relationship goal.
    private func handleTutorialGoalCreated() {
        guard tutorialPhase == .goalButtonPointer else { return }
        tutorialPhase = .preferencesSlide
    }

    /// Advances the Friends tutorial through slides and interactive pointer phases.
    private func handleFriendsTutorialPrimaryAction() {
        switch tutorialPhase {
        case .introSlide:
            tutorialPhase = .addSlide
        case .addSlide:
            tutorialContactCount = viewModel.contacts.count
            tutorialPhase = .addPointer
        case .healthSlide:
            tutorialPhase = .goalListPointer
        case .preferencesSlide:
            tutorialPhase = .settingsPointer
        case .completeSlide:
            finishFriendsTutorial()
            onTutorialNext()
        case .none, .addPointer, .goalListPointer, .goalButtonPointer, .settingsPointer:
            break
        }
    }

    /// Moves the Friends tutorial back to the previous slide phase.
    private func goBackInFriendsTutorial() {
        switch tutorialPhase {
        case .addSlide:
            tutorialPhase = .introSlide
        case .healthSlide:
            tutorialPhase = .addSlide
        case .preferencesSlide:
            tutorialPhase = .healthSlide
        case .completeSlide:
            tutorialPhase = .preferencesSlide
        case .none, .introSlide, .addPointer, .goalListPointer, .goalButtonPointer, .settingsPointer:
            break
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", icon: nil, filter: nil)
                ForEach(TagCategory.allCases) { category in
                    filterChip(label: category.rawValue, icon: category.icon, filter: category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(UIColor.systemBackground))
        Divider()
    }

    /// Builds a selectable tag filter chip for the Friends list.
    private func filterChip(label: String, icon: String?, filter: TagCategory?) -> some View {
        let isSelected = viewModel.selectedTagFilter == filter
        return Button {
            viewModel.selectedTagFilter = filter
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(label)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Helpers

extension ConnectionsView {
    fileprivate var weeklyCheckInCaptionText: String {
        guard homeViewModel.hasCompletedCheckInThisWeek else { return "Weekly Check-In" }
        return "This week's priority"
    }

    fileprivate var weeklyCheckInStatusText: String {
        guard homeViewModel.hasCompletedCheckInThisWeek else {
            return "Do your weekly check-in"
        }
        if let contact = homeViewModel.weeklyPriorityContact {
            return homeViewModel.displayName(for: contact)
        }
        return "No priority set this week"
    }
}

// MARK: - Contact row

private let tagCategoryPriority: [TagCategory] = [.family, .friends, .school, .work, .community]

/// Chooses the most relevant tag to show for a contact row.
private func primaryTag(for contact: TrackedContact, filter: TagCategory?) -> ContactTag? {
    let tags = contact.contextTags
    guard !tags.isEmpty else { return nil }
    if let filter, let match = tags.first(where: { $0.parentCategory == filter }) { return match }
    for category in tagCategoryPriority {
        if let match = tags.first(where: { $0.parentCategory == category }) { return match }
    }
    return tags.first
}

/// Row showing one tracked friend and their relationship health summary.
private struct ContactRow: View {
    let contact: TrackedContact
    let viewModel: ConnectionsViewModel
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var activeFilter: TagCategory? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.displayName(for: contact))
                        .font(.body)

                    if let label = viewModel.healthLabel(for: contact) {
                        let tag = primaryTag(for: contact, filter: activeFilter)
                        Text((tag.map { "\($0.displayName) · " } ?? "") + label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)

            WarmthBar(days: viewModel.healthScores[contact.id]?.daysSinceLastHangout)
        }
    }
}

/// Thin color bar that visualizes recency of the last hangout.
private struct WarmthBar: View {
    let days: Int?

    /// Converts days since last hangout into a normalized warmth value.
    private func warmth(_ d: Int) -> Double {
        max(0, min(1, 1 - log10(Double(d) + 1) / 3))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color(white: 0.22))

            if let d = days {
                let w = warmth(d)
                let hue = (150.0 + (1.0 - w) * 28.0) / 360.0
                Rectangle()
                    .fill(Color(hue: hue, saturation: 0.62, brightness: 0.52))
                    .scaleEffect(x: max(0.02, w), anchor: .leading)
            }
        }
        .frame(height: 2)
        .frame(maxWidth: .infinity)
    }
}

/// Controls in FriendsView that can receive tutorial pointers.
enum FriendsTutorialTarget: Hashable {
    case moreButton
    case settingsButton
    case friendRow
    case addGoalButton
}

/// Step state for the Friends tab's interactive tutorial.
private enum FriendsTutorialPhase: Equatable {
    case none
    case introSlide
    case addSlide
    case addPointer
    case healthSlide
    case goalListPointer
    case goalButtonPointer
    case preferencesSlide
    case settingsPointer
    case completeSlide

    var walkthroughStep: WalkthroughStep? {
        switch self {
        case .introSlide:
            return TabWalkthroughs.friends[0]
        case .addSlide:
            return TabWalkthroughs.friends[1]
        case .healthSlide:
            return TabWalkthroughs.friends[2]
        case .preferencesSlide:
            return TabWalkthroughs.friends[3]
        case .completeSlide:
            return TabWalkthroughs.friends[4]
        case .none, .addPointer, .goalListPointer, .goalButtonPointer, .settingsPointer:
            return nil
        }
    }

    var hasPreviousSlide: Bool {
        switch self {
        case .addSlide, .healthSlide, .preferencesSlide, .completeSlide:
            return true
        case .none, .introSlide, .addPointer, .goalListPointer, .goalButtonPointer, .settingsPointer:
            return false
        }
    }
}
