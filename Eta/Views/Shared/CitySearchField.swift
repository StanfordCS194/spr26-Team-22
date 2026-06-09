import SwiftUI
import MapKit

struct CitySearchField: View {
    @Binding var city: String
    var placeholder: String = "e.g. San Francisco"
    var onCommit: ((String) -> Void)? = nil
    var onCoordinates: ((Double, Double) -> Void)? = nil

    @State private var completer = CityCompleter()
    @State private var showingSuggestions = false
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $city)
            .focused($isFocused)
            .onSubmit {
                showingSuggestions = false
                onCommit?(city)
            }
            .onChange(of: city) { _, value in
                completer.search(value)
                showingSuggestions = isFocused && !value.isEmpty
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showingSuggestions = false
                    }
                } else if !city.isEmpty {
                    showingSuggestions = true
                }
            }

        if showingSuggestions && !completer.results.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(completer.results.prefix(4).enumerated()), id: \.element.title) { index, result in
                    Button {
                        city = result.title
                        showingSuggestions = false
                        isFocused = false
                        onCommit?(result.title)
                        Task {
                            let req = MKLocalSearch.Request(completion: result)
                            if let resp = try? await MKLocalSearch(request: req).start(),
                               let coord = resp.mapItems.first?.placemark.coordinate {
                                await MainActor.run { onCoordinates?(coord.latitude, coord.longitude) }
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if index < min(completer.results.count, 4) - 1 {
                        Divider().padding(.leading, 38)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
    }
}

@Observable
private final class CityCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(_ query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results.filter { !($0.title.first?.isNumber ?? false) }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
