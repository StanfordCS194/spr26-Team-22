//
//  AnalyticsDebugOverlay.swift
//  Eta
//
//  Created on 4/23/26.
//

import SwiftUI

/// Debug overlay for exporting analytics data during testing.
/// Allows selecting sessions to export and adding notes for each session.
/// Only available in DEBUG builds.
struct AnalyticsDebugOverlay: View {
    let analyticsService: AnalyticsService

    @State private var sessions: [SessionInfo] = []
    @State private var selectedSessionIDs: Set<String> = []
    @State private var showingShareSheet = false
    @State private var shareFiles: [URL] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "chart.bar",
                        description: Text("Start using the app to generate analytics data.")
                    )
                } else {
                    List {
                        Section {
                            Text("\(selectedSessionIDs.count) of \(sessions.count) sessions selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Section("Sessions") {
                            ForEach(sessions) { session in
                                SessionRow(
                                    session: session,
                                    isSelected: selectedSessionIDs.contains(session.sessionID),
                                    notes: Binding(
                                        get: { analyticsService.sessionNotes[session.sessionID] ?? "" },
                                        set: { analyticsService.sessionNotes[session.sessionID] = $0 }
                                    ),
                                    toggleSelection: {
                                        if selectedSessionIDs.contains(session.sessionID) {
                                            selectedSessionIDs.remove(session.sessionID)
                                        } else {
                                            selectedSessionIDs.insert(session.sessionID)
                                        }
                                    }
                                )
                            }
                        }
                        
                        Section {
                            Button {
                                selectAll()
                            } label: {
                                Label("Select All", systemImage: "checkmark.circle")
                            }

                            Button {
                                deselectAll()
                            } label: {
                                Label("Deselect All", systemImage: "circle")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Export Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Export") { exportAnalytics() }
                        .disabled(selectedSessionIDs.isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .task {
                loadSessions()
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareFiles)
        }
    }
    
    private func loadSessions() {
        sessions = analyticsService.getAllSessions()
        // Select all by default
        selectedSessionIDs = Set(sessions.map { $0.sessionID })
    }
    
    private func selectAll() {
        selectedSessionIDs = Set(sessions.map { $0.sessionID })
    }
    
    private func deselectAll() {
        selectedSessionIDs.removeAll()
    }
    
    private func exportAnalytics() {
        shareFiles = analyticsService.createExportFiles(
            sessionIDs: selectedSessionIDs.isEmpty ? nil : selectedSessionIDs,
            notes: analyticsService.sessionNotes
        )
        showingShareSheet = true
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: SessionInfo
    let isSelected: Bool
    @Binding var notes: String
    let toggleSelection: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    toggleSelection()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.sessionID)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                Text(session.formattedStartTime)
                                Text("•")
                                Text("\(session.eventCount) events")
                                Text("•")
                                Text(session.formattedDuration)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            // Notes field (expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes (e.g., user name, observations)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("User name or notes...", text: $notes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                .padding(.leading, 28)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Share Sheet

/// UIKit share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
