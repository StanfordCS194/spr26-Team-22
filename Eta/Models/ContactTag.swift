import Foundation

struct ContactTag: Codable, Identifiable, Equatable {
    var subcategory: TagSubcategory
    var customLabel: String?

    var id: String { subcategory.rawValue }

    var displayName: String {
        if let label = customLabel, !label.isEmpty { return label }
        return subcategory.defaultName
    }

    var parentCategory: TagCategory {
        subcategory.parent
    }
}
