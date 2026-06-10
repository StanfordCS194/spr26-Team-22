import SwiftUI

struct ConnectionsView: View {
    let viewModel: ConnectionsViewModel
    let homeViewModel: HomeViewModel
    let analyticsService: AnalyticsService
    let onShowSettings: () -> Void

    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var isSelecting = false
    @State private var selectedContactIDs: Set<UUID> = []
    @State private var showingBulkTagPicker = false
    @State private var bulkEditingTags: [ContactTag] = []
    @State private var showingDeleteConfirmation = false
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

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        Task {
            await viewModel.loadHealthScores()
            await homeViewModel.refresh()
        }
    }

    @ViewBuilder
    private var forYouSection: some View {
        if !homeViewModel.friendSpotlights.isEmpty && !isSelecting && searchText.isEmpty {
            Section {
                ForEach(homeViewModel.friendSpotlights) { item in
                    NavigationLink {
                        FriendDetailView(
                            contact: item.contact,
                            health: item.health,
                            displayName: homeViewModel.displayName(for: item.contact),
                            homeViewModel: homeViewModel
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
            } header: {
                Text("For You")
                    .font(.title3.weight(.semibold))
                    .textCase(nil)
                    .foregroundStyle(.primary)
                    .padding(.top, 4)
            }
        }
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
                            homeViewModel: homeViewModel
                        )
                    } label: {
                        ContactRow(contact: contact, viewModel: viewModel, activeFilter: viewModel.selectedTagFilter)
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
            forYouSection
            allFriendsSection
        }
        // Fix: pill bar is injected via safeAreaInset so it's fully opaque and list scrolls beneath it.
        .safeAreaInset(edge: .top, spacing: 0) {
            if !isSearching {
                filterBar
            }
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
            }
            .onChange(of: scenePhase) { _, newPhase in handleScenePhaseChange(newPhase) }
            .trackScreen("ConnectionsView", analytics: analyticsService)
        }
    }

    // MARK: - Filter bar

    @ViewBuilder
    private var filterBar: some View {
        VStack(spacing: 0) {
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
            // Solid background prevents list content from bleeding through
            .background(EtaColor.ink0)
            Divider()
                .overlay(EtaColor.hairline)
        }
    }

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
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? AnyShapeStyle(EtaColor.appGradient)
                    : AnyShapeStyle(EtaColor.surface2),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? EtaColor.ink0 : EtaColor.text2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}


// MARK: - Contact row

private let tagCategoryPriority: [TagCategory] = [.family, .friends, .school, .work, .community]

private func primaryTag(for contact: TrackedContact, filter: TagCategory?) -> ContactTag? {
    let tags = contact.contextTags
    guard !tags.isEmpty else { return nil }
    if let filter, let match = tags.first(where: { $0.parentCategory == filter }) { return match }
    for category in tagCategoryPriority {
        if let match = tags.first(where: { $0.parentCategory == category }) { return match }
    }
    return tags.first
}

private struct ContactRow: View {
    let contact: TrackedContact
    let viewModel: ConnectionsViewModel
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var activeFilter: TagCategory? = nil

    private var days: Int? { viewModel.healthScores[contact.id]?.daysSinceLastHangout }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? EtaColor.warm : EtaColor.text2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.displayName(for: contact))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(EtaColor.text1)

                    if let label = viewModel.healthLabel(for: contact) {
                        let tag = primaryTag(for: contact, filter: activeFilter)
                        Text((tag.map { "\($0.displayName) · " } ?? "") + label)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(EtaColor.text2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Nudge chip: gentle prompt for contacts not seen in 30+ days
                if let d = days, d >= 30, !isSelecting {
                    nudgeChip(days: d)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)

            WarmthBar(days: days)
        }
    }

    @ViewBuilder
    private func nudgeChip(days: Int) -> some View {
        let label = days > 365 ? "been a while" : "worth a hello"
        Text("\(label) →")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(EtaColor.text1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(EtaColor.surface2, in: Capsule())
    }
}
