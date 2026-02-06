import Foundation

enum EdgeType: String, Codable, Sendable {
    case containment
    case dependency
    case custom
}

struct GraphEdge: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let sourceNodeId: UUID
    let targetNodeId: UUID
    let edgeType: EdgeType

    init(
        id: UUID = UUID(),
        sourceNodeId: UUID,
        targetNodeId: UUID,
        edgeType: EdgeType
    ) {
        self.id = id
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.edgeType = edgeType
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceNodeId = "source_node_id"
        case targetNodeId = "target_node_id"
        case edgeType = "edge_type"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GraphEdge, rhs: GraphEdge) -> Bool {
        lhs.id == rhs.id
    }
}
