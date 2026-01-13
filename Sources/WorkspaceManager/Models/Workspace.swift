import Foundation

struct Workspace: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var terminals: [Terminal]
    var isExpanded: Bool

    init(id: UUID = UUID(), name: String, path: String, terminals: [Terminal] = [], isExpanded: Bool = true) {
        self.id = id
        self.name = name
        self.path = path
        self.terminals = terminals
        self.isExpanded = isExpanded
    }

    mutating func addTerminal(name: String) -> Terminal {
        let terminal = Terminal(name: name, workingDirectory: path)
        terminals.append(terminal)
        return terminal
    }

    mutating func removeTerminal(id: UUID) {
        terminals.removeAll { $0.id == id }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        lhs.id == rhs.id
    }
}
