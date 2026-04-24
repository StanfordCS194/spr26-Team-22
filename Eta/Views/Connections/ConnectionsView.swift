import SwiftUI

struct ConnectionsView: View {
    let viewModel: ConnectionsViewModel

    @State private var showingAddSheet = false

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
                        ForEach(viewModel.contacts) { contact in
                            ContactRow(contact: contact, viewModel: viewModel)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.removeContact(viewModel.contacts[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddConnectionSheet(viewModel: viewModel)
            }
            .task {
                viewModel.loadContacts()
                await viewModel.loadHealthScores()
            }
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
