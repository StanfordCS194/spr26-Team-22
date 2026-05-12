import SwiftUI

struct ConnectionsView: View {
    let viewModel: ConnectionsViewModel
    let homeViewModel: HomeViewModel
    let analyticsService: AnalyticsService

    @State private var showingAddSheet = false
    @Environment(\.scenePhase) private var scenePhase

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
                    List {
                        if !homeViewModel.friendSpotlights.isEmpty {
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
                            ForEach(viewModel.contacts) { contact in
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
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let contact = viewModel.contacts[index]
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
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        analyticsService.logButtonTapped(screen: "ConnectionsView", button: "AddConnection")
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddConnectionSheet(
                    viewModel: viewModel,
                    analyticsService: analyticsService
                )
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
}

// MARK: - Contact row

private struct ContactRow: View {
    let contact: TrackedContact
    let viewModel: ConnectionsViewModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(healthColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.displayName(for: contact))
                    .font(.body)

                if let label = viewModel.healthLabel(for: contact) {
                    Text(label)
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
