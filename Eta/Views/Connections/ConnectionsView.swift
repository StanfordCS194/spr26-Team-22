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

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.contacts.isEmpty {
                    ContentUnavailableView(
                        "No Friends Yet",
                        systemImage: "person.2",
                        description: Text("Tap + to add friends you want to keep up with.")
                    )
                } else {
                    SearchAwareContent(searchText: searchText) {
                        filterBar
                    } listContent: {
                        List {
                            if !homeViewModel.friendSpotlights.isEmpty && !isSelecting {
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
                                }
                            } header: {
                                Text("All Friends")
                                    .font(.title3.weight(.semibold))
                                    .textCase(nil)
                                    .foregroundStyle(.primary)
                                    .padding(.top, 4)
                            }
                        }
                    }
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
                "Delete \(selectedContactIDs.count) friend\(selectedContactIDs.count == 1 ? "" : "s")?",
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
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                viewModel.loadContacts()
                await viewModel.loadHealthScores()
                await homeViewModel.refresh()
                await homeViewModel.geocodeMissingCities()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await viewModel.loadHealthScores()
                        await homeViewModel.refresh()
                    }
                }
            }
            .trackScreen("ConnectionsView", analytics: analyticsService)
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

// MARK: - Search-aware wrapper

private struct SearchAwareContent<FilterBar: View, ListContent: View>: View {
    let searchText: String
    @ViewBuilder let filterBar: FilterBar
    @ViewBuilder let listContent: ListContent

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        VStack(spacing: 0) {
            if !isSearching { filterBar }
            if isSearching && searchText.isEmpty {
                Color.clear
            } else {
                listContent
            }
        }
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

    var body: some View {
        HStack(spacing: 10) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            } else {
                Circle()
                    .fill(healthColor)
                    .frame(width: 10, height: 10)
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
        }
        .padding(.vertical, 2)
    }

    private var healthColor: Color {
        guard let health = viewModel.healthScores[contact.id] else { return .gray }
        if health.upcomingHangout != nil { return .green }
        guard let days = health.daysSinceLastHangout else { return .gray }
        if days <= 14 { return .green }
        if days <= 30 { return .yellow }
        return .red
    }
}
