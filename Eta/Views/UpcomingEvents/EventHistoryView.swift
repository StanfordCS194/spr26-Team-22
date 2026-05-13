import SwiftUI

struct EventHistoryView: View {
    let items: [HangoutDisplayItem]
    let photoRepository: ActivityPhotoRepository

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "No events yet",
                    systemImage: "calendar",
                    description: Text("Events you schedule will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            UpcomingEventCardView(item: item, photoRepository: photoRepository)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("All Events")
        .navigationBarTitleDisplayMode(.large)
    }
}
