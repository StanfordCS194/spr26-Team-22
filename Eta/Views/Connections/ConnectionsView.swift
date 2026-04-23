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
                            Text(viewModel.displayName(for: contact))
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
            }
        }
    }
}
