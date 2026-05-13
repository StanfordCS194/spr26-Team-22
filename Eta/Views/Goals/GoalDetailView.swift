import SwiftUI

struct GoalDetailView: View {
    let goal: Goal
    let contacts: [TrackedContact]
    let formatter: ContactFormatter
    let onSave: () -> Void
    let onDelete: () -> Void
    let onPause: () -> Void

    @State private var isEditing = false
    @State private var editTitle: String = ""
    @State private var editTarget: Int = 2
    @State private var editCadence: GoalCadence = .monthly
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader
                friendChips
                interactionHistory
                dangerZone
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Edit Goal" : goal.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save") { saveEdits() }
                        .fontWeight(.semibold)
                } else {
                    Button("Edit") { beginEditing() }
                }
            }
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isEditing = false }
                }
            }
        }
        .confirmationDialog("Delete Goal", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the goal.")
        }
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isEditing {
                TextField("Goal title", text: $editTitle)
                    .font(.title2.weight(.semibold))
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How often").font(.caption).foregroundStyle(.secondary)
                        Picker("Cadence", selection: $editCadence) {
                            ForEach(GoalCadence.allCases, id: \.self) { c in
                                Text(c.rawValue.capitalized).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Times").font(.caption).foregroundStyle(.secondary)
                        Stepper("\(editTarget)×", value: $editTarget, in: 1...20)
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 20) {
                    largeProgressRing
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(goal.progress) of \(goal.target) this \(goal.cadence.displayName)")
                            .font(.headline)
                        statusBadge
                        if goal.daysRemaining > 0 {
                            Text("\(goal.daysRemaining) days left in window")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Window closed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var largeProgressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 6)
            Circle()
                .trim(from: 0, to: goal.progressFraction)
                .stroke(statusColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(goal.progress)")
                    .font(.title2.weight(.bold))
                Text("/ \(goal.target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72, height: 72)
    }

    private var statusBadge: some View {
        Text(statusLabel)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor)
    }

    // MARK: - Friend chips

    private var friendChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Friends")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if goal.friendIDs.isEmpty {
                Text("Applies to all friends")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let ids: [UUID] = goal.friendIDs
                FlowLayout(spacing: 8) {
                    ForEach(ids, id: \.self) { id in
                        if let contact = contacts.first(where: { $0.id == id }) {
                            Text(formatter.displayName(for: contact))
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Interaction history

    private var interactionHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This window")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if goal.progress == 0 {
                Text("No hangouts logged yet in this window.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(0..<goal.progress, id: \.self) { i in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                        Text("Hangout \(i + 1)")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Danger zone

    private var dangerZone: some View {
        VStack(spacing: 12) {
            if !goal.isPaused {
                Button {
                    onPause()
                    dismiss()
                } label: {
                    Label("Pause goal", systemImage: "pause.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }

            Button {
                showDeleteConfirm = true
            } label: {
                Label("Delete goal", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch goal.status {
        case .onTrack:  return Color(red: 0.2, green: 0.7,  blue: 0.45)
        case .atRisk:   return Color(red: 0.9, green: 0.65, blue: 0.1)
        case .behind:   return Color(red: 0.85, green: 0.35, blue: 0.28)
        case .achieved: return Color(red: 0.3, green: 0.55, blue: 0.9)
        }
    }

    private var statusLabel: String {
        switch goal.status {
        case .onTrack:  return "On track"
        case .atRisk:   return "At risk"
        case .behind:   return "Behind"
        case .achieved: return "Achieved"
        }
    }

    private func beginEditing() {
        editTitle = goal.title
        editTarget = goal.target
        editCadence = goal.cadence
        isEditing = true
    }

    private func saveEdits() {
        guard !editTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        goal.title = editTitle
        goal.target = editTarget
        goal.cadenceRaw = editCadence.rawValue
        goal.lastUpdated = .now
        onSave()
        isEditing = false
    }
}

// MARK: - Simple flow layout for chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
            .reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        var rows: [[LayoutSubviews.Element]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(subview)
            x += size.width + spacing
        }
        return rows
    }
}
