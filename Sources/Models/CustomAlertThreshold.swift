import Foundation

struct CustomAlertThreshold: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var percent: Int
    var isEnabled: Bool

    init(id: UUID = UUID(), percent: Int, isEnabled: Bool = true) {
        self.id = id
        self.percent = percent
        self.isEnabled = isEnabled
    }
}
