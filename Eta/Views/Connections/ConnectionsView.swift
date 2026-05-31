import SwiftUI

struct ConnectionsView: View {
    let viewModel: ConnectionsViewModel
    let homeViewModel: HomeViewModel
    let analyticsService: AnalyticsService
    let onShowSettings: () -> Void

    @State private var showingAddSheet = false
    @State private var isSelecting = false
    @State private var selectedContactIDs: Set<UUID> = []
    @State private var showingBulkTagPicker = false
    @State private var bulkEditingTags: [ContactTag] = []
    @State private var showingDeleteConfirmation = false
    @Environment(\.scenePhase) private var scenePhase

    private var selectedContacts: [TrackedContact] {
        viewModel.filteredContacts.filter { selectedContactIDs.contains($0.id) }
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
                    VStack(spacing: 0) {
                        filterBar
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
                                ForEach(viewModel.filteredContacts) { contact in
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
                                                isSelected: selectedContactIDs.contains(contact.id)
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
                                            ContactRow(contact: contact, viewModel: viewModel)
                                        }
                                    }
                                }
                                .onDelete { indexSet in
                                    guard !isSelecting else { return }
                                    for index in indexSet {
                                        let contact = viewModel.filteredContacts[index]
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isSelecting {
                        Button(selectedContactIDs.count == viewModel.filteredContacts.count ? "Deselect All" : "Select All") {
                            if selectedContactIDs.count == viewModel.filteredContacts.count {
                                selectedContactIDs = []
                            } else {
                                selectedContactIDs = Set(viewModel.filteredContacts.map(\.id))
                            }
                        }
                    } else {
                        Button("Select") {
                            isSelecting = true
                        }
                        Button {
                            analyticsService.logButtonTapped(screen: "ConnectionsView", button: "AddConnection")
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if isSelecting {
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
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddConnectionSheet(
                    viewModel: viewModel,
                    analyticsService: analyticsService
                )
            }
            .sheet(isPresented: $showingBulkTagPicker) {
                ContactTagPickerView(selectedTags: $bulkEditingTags) {
                    for contact in selectedContacts {
                        homeViewModel.updateTags(bulkEditingTags, for: contact)
                    }
                    isSelecting = false
                    selectedContactIDs = []
                }
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

// MARK: - Contact row

private struct ContactRow: View {
    let contact: TrackedContact
    let viewModel: ConnectionsViewModel
    var isSelecting: Bool = false
    var isSelected: Bool = false

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
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let tags = contact.contextTags
                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(tags.prefix(2))) { tag in
                            Text(tag.displayName)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(tag.parentCategory.color.opacity(0.15), in: Capsule())
                                .foregroundStyle(tag.parentCategory.color)
                        }
                        if tags.count > 2 {
                            Text("+\(tags.count - 2)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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
