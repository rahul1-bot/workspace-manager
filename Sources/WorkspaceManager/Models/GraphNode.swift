import Foundation

enum NodeType: String, Codable, Sendable {
    case terminal
    case markdown
}

struct GraphNode: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var nodeType: NodeType
    var positionX: Double
    var positionY: Double
    var workspaceId: UUID
    var terminalId: UUID?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        name: String,
        nodeType: NodeType,
        positionX: Double = 0.0,
        positionY: Double = 0.0,
        workspaceId: UUID,
        terminalId: UUID? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.nodeType = nodeType
        self.positionX = positionX
        self.positionY = positionY
        self.workspaceId = workspaceId
        self.terminalId = terminalId
        self.isPinned = isPinned
    }

    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case nodeType = "node_type"
        case positionX = "position_x"
        case positionY = "position_y"
        case workspaceId = "workspace_id"
        case terminalId = "terminal_id"
        case isPinned = "is_pinned"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool {
        lhs.id == rhs.id
    }
}
