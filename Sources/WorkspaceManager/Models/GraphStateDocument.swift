import Foundation

struct ViewportState: Codable, Sendable {
    var panOffsetX: Double
    var panOffsetY: Double
    var zoomScale: Double

    init(
        panOffsetX: Double = 0.0,
        panOffsetY: Double = 0.0,
        zoomScale: Double = 1.0
    ) {
        self.panOffsetX = panOffsetX
        self.panOffsetY = panOffsetY
        self.zoomScale = zoomScale
    }

    var panOffset: CGPoint {
        get { CGPoint(x: panOffsetX, y: panOffsetY) }
        set {
            panOffsetX = newValue.x
            panOffsetY = newValue.y
        }
    }

    private enum CodingKeys: String, CodingKey {
        case panOffsetX = "pan_offset_x"
        case panOffsetY = "pan_offset_y"
        case zoomScale = "zoom_scale"
    }
}

enum LayoutAlgorithm: String, Codable, Sendable {
    case forceDirected = "force_directed"
    case manual
}

struct GraphStateDocument: Codable, Sendable {
    var nodes: [GraphNode]
    var edges: [GraphEdge]
    var viewport: ViewportState
    var layoutAlgorithm: LayoutAlgorithm

    init(
        nodes: [GraphNode] = [],
        edges: [GraphEdge] = [],
        viewport: ViewportState = ViewportState(),
        layoutAlgorithm: LayoutAlgorithm = .forceDirected
    ) {
        self.nodes = nodes
        self.edges = edges
        self.viewport = viewport
        self.layoutAlgorithm = layoutAlgorithm
    }

    private enum CodingKeys: String, CodingKey {
        case nodes
        case edges
        case viewport
        case layoutAlgorithm = "layout_algorithm"
    }

    func node(for terminalId: UUID) -> GraphNode? {
        nodes.first { $0.terminalId == terminalId }
    }

    func nodes(in workspaceId: UUID) -> [GraphNode] {
        nodes.filter { $0.workspaceId == workspaceId }
    }

    func edges(connectedTo nodeId: UUID) -> [GraphEdge] {
        edges.filter { $0.sourceNodeId == nodeId || $0.targetNodeId == nodeId }
    }
}
