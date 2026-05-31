//  Created by Lauren Hamilton on 5/12/26.
//
import Foundation
import SwiftUI

/// Availability tab for entering free time, choosing hangout length, and viewing scheduled blocks.
struct AvailabilityView: View {

    let viewModel: AvailabilityViewModel
    let onShowSettings: () -> Void
    /// Day currently shown in the availability grid.
    @State private var selectedDate = Date()
    /// Controls whether schedule blocks can be selected and deselected.
    @State private var isEditingAvailability = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DatePicker(
                        "Day",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)

                    activityDurationEditor

                    if viewModel.blocks(on: selectedDate).isEmpty && !isEditingAvailability {
                        EmptyAvailabilityState()
                    } else {
                        legend

                        VStack(spacing: 0) {
                            ForEach(displayedHours, id: \.self) { hour in
                                if let interval = hourInterval(for: hour) {
                                    HourAvailabilityRow(
                                        label: hourLabel(for: interval.start),
                                        status: status(for: interval),
                                        detail: detail(for: interval),
                                        isEditing: isEditingAvailability,
                                        onToggle: {
                                            withAnimation {
                                                viewModel.toggleAvailability(during: interval)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                    }

                    Button {
                        withAnimation {
                            isEditingAvailability.toggle()
                        }
                    } label: {
                        Label(
                            isEditingAvailability ? "Done" : "Change Availability",
                            systemImage: isEditingAvailability ? "checkmark" : "square.grid.3x3"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Availability")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onShowSettings() } label: { Image(systemName: "gearshape") }
                }
            }
            .task {
                await viewModel.loadAvailability()
            }
            .onReceive(NotificationCenter.default.publisher(for: .scheduledHangoutsDidChange)) { _ in
                Task {
                    await viewModel.loadAvailability()
                }
            }
        }
    }

    /// Hours displayed in the day grid.
    private var displayedHours: [Int] {
        Array(5..<24)
    }

    /// Color legend for the availability grid.
    private var legend: some View {
        HStack(spacing: 16) {
            LegendItem(color: .green, label: "Free")
            LegendItem(color: .pink, label: "Scheduled")
            LegendItem(color: Color(.systemBackground), label: "Unavailable", bordered: true)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// Slider that edits the shared hangout duration setting.
    private var activityDurationEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preferred hangout length")
                    .font(.headline)
                Spacer()
                Text(viewModel.activityDurationLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: durationSliderBinding,
                in: 15...360,
                step: 15
            ) {
                Text("Preferred hangout length")
            } minimumValueLabel: {
                Text("15m")
                    .font(.caption)
            } maximumValueLabel: {
                Text("6h")
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Bridge between the view model's integer-minute setting and SwiftUI's `Slider` API.
    private var durationSliderBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.activityDurationMinutes) },
            set: { viewModel.setActivityDurationMinutes(Int($0)) }
        )
    }

    /// Builds a one-hour interval for a displayed grid row.
    private func hourInterval(for hour: Int) -> DateInterval? {
        let calendar = Calendar.current
        guard let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: selectedDate),
              let end = calendar.date(byAdding: .hour, value: 1, to: start)
        else { return nil }

        return DateInterval(start: start, end: end)
    }

    /// Resolves the visual state for a grid row.
    private func status(for interval: DateInterval) -> HourAvailabilityRow.Status {
        if viewModel.isScheduled(during: interval) {
            return .scheduled
        }

        if viewModel.isFree(during: interval) {
            return .free
        }

        return .unavailable
    }

    /// Returns the row label shown inside a free or scheduled grid block.
    private func detail(for interval: DateInterval) -> String {
        let scheduledLabels = viewModel.scheduledLabels(during: interval)
        if !scheduledLabels.isEmpty {
            return scheduledLabels.joined(separator: ", ")
        }

        if viewModel.isFree(during: interval) {
            return "Free"
        }

        return ""
    }

    /// Formats the left-hand hour label for the grid.
    private func hourLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }

}

/// One row in the hour-by-hour availability grid.
private struct HourAvailabilityRow: View {
    /// Display states supported by an hourly availability row.
    enum Status: Equatable {
        case free
        case scheduled
        case unavailable
    }

    /// Left-side hour label.
    let label: String
    /// Visual state of the row.
    let status: Status
    /// Optional text shown inside the colored row block.
    let detail: String
    /// Whether the row should visually indicate it can be toggled.
    let isEditing: Bool
    /// Called when the row is selected in edit mode.
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)

            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor)
                .frame(height: 34)
                .overlay(alignment: .leading) {
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(borderColor, lineWidth: 1)
                )
                .overlay(alignment: .trailing) {
                    if isEditing && status != .scheduled {
                        Image(systemName: status == .free ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(status == .free ? .green : .secondary)
                            .padding(.trailing, 10)
                    }
                }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditing, status != .scheduled else { return }
            onToggle()
        }
    }

    /// Fill color associated with the row status.
    private var fillColor: Color {
        switch status {
        case .free: return .green.opacity(0.65)
        case .scheduled: return .pink.opacity(0.55)
        case .unavailable: return Color(.systemBackground)
        }
    }

    /// Border color used to outline unavailable rows.
    private var borderColor: Color {
        switch status {
        case .unavailable: return Color.secondary.opacity(0.25)
        default: return .clear
        }
    }

    /// Text color used inside the row block.
    private var textColor: Color {
        switch status {
        case .free, .scheduled: return .primary
        case .unavailable: return .secondary
        }
    }
}

/// Empty state shown before the user has added free time for the selected day.
private struct EmptyAvailabilityState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("No Availability Indicated")
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("Let us know when you're free!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

/// Small color swatch and label used by the availability grid legend.
private struct LegendItem: View {
    /// Swatch color.
    let color: Color
    /// Text shown beside the swatch.
    let label: String
    /// Whether the swatch needs an outline to remain visible.
    var bordered: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 16, height: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(bordered ? Color.secondary.opacity(0.4) : .clear, lineWidth: 1)
                )
            Text(label)
        }
    }
}
