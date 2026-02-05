import Foundation

struct Terminal: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var workingDirectory: String
    var isActive: Bool

    init(id: UUID = UUID(), name: String, workingDirectory: String, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.isActive = isActive
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Terminal, rhs: Terminal) -> Bool {
        lhs.id == rhs.id
    }
}
