import SwiftUI

struct GraphCanvasView: View {
    @EnvironmentObject var appState: AppState
    @State private var viewportTransform: ViewportTransform = .identity
    @State private var draggedNodeId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var selectedNodeId: UUID?
    @State private var panStartTranslation: SIMD2<Double>?

    private let nodeWidth: CGFloat = 140
    private let nodeHeight: CGFloat = 48
    private let nodeCornerRadius: CGFloat = 8
    private let gridSpacing: CGFloat = 40
    private let hitTestRadius: CGFloat = 80

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                canvas(size: geometry.size)
                    .gesture(panGesture)
                    .gesture(zoomGesture(center: geometry.size))
                    .onTapGesture(count: 2) { location in
                        handleDoubleTap(at: location)
                    }
                    .onTapGesture { location in
                        handleSingleTap(at: location)
                    }

                nodeOverlays(size: geometry.size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.85))
            .onAppear {
                centerViewportOnContent(canvasSize: geometry.size)
            }
        }
    }

    private func centerViewportOnContent(canvasSize: CGSize) {
        let nodes: [GraphNode] = appState.graphDocument.nodes
        guard !nodes.isEmpty else { return }
        guard viewportTransform.translation == .zero else { return }

        let avgX: Double = nodes.map(\.positionX).reduce(0, +) / Double(nodes.count)
        let avgY: Double = nodes.map(\.positionY).reduce(0, +) / Double(nodes.count)

        viewportTransform.translation = SIMD2<Double>(
            canvasSize.width / 2 - avgX * viewportTransform.scale,
            canvasSize.height / 2 - avgY * viewportTransform.scale
        )
    }

    private func canvas(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            drawGrid(context: &context, size: canvasSize)
            drawClusterBoundaries(context: &context)
            drawEdges(context: &context)
            drawNodes(context: &context)
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        let dotRadius: CGFloat = 1.5
        let scaledSpacing: CGFloat = gridSpacing * viewportTransform.scale
        guard scaledSpacing > 8 else { return }

        let offsetX: CGFloat = viewportTransform.translation.x.truncatingRemainder(dividingBy: scaledSpacing)
        let offsetY: CGFloat = viewportTransform.translation.y.truncatingRemainder(dividingBy: scaledSpacing)

        var gridContext: GraphicsContext = context
        gridContext.opacity = 0.15

        var x: CGFloat = offsetX
        while x < size.width {
            var y: CGFloat = offsetY
            while y < size.height {
                let dotRect: CGRect = CGRect(
                    x: x - dotRadius,
                    y: y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )
                gridContext.fill(Ellipse().path(in: dotRect), with: .color(.white))
                y += scaledSpacing
            }
            x += scaledSpacing
        }
    }

    private func drawClusterBoundaries(context: inout GraphicsContext) {
        let workspaceIds: Set<UUID> = Set(appState.graphDocument.nodes.map(\.workspaceId))

        for workspaceId in workspaceIds {
            let clusterNodes: [GraphNode] = appState.graphDocument.nodes(in: workspaceId)
            guard !clusterNodes.isEmpty else { continue }

            let workspaceName: String = appState.workspaces
                .first { $0.id == workspaceId }?.name ?? "Workspace"

            let padding: CGFloat = 30
            let labelTopPadding: CGFloat = 24
            var minX: CGFloat = .greatestFiniteMagnitude
            var minY: CGFloat = .greatestFiniteMagnitude
            var maxX: CGFloat = -.greatestFiniteMagnitude
            var maxY: CGFloat = -.greatestFiniteMagnitude

            for node in clusterNodes {
                let screenPos: CGPoint = viewportTransform.apply(node.position)
                minX = min(minX, screenPos.x - nodeWidth / 2 - padding)
                minY = min(minY, screenPos.y - nodeHeight / 2 - padding - labelTopPadding)
                maxX = max(maxX, screenPos.x + nodeWidth / 2 + padding)
                maxY = max(maxY, screenPos.y + nodeHeight / 2 + padding)
            }

            let clusterRect: CGRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            let clusterPath: Path = RoundedRectangle(cornerRadius: 12).path(in: clusterRect)

            var clusterContext: GraphicsContext = context
            clusterContext.opacity = 0.06
            clusterContext.fill(clusterPath, with: .color(.white))

            clusterContext.opacity = 0.1
            clusterContext.stroke(clusterPath, with: .color(.white), lineWidth: 1)

            let labelText: Text = Text(workspaceName)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            let resolvedLabel = context.resolve(labelText)
            var labelContext: GraphicsContext = context
            labelContext.opacity = 0.5
            labelContext.draw(
                resolvedLabel,
                at: CGPoint(x: minX + 12, y: minY + 8),
                anchor: .topLeading
            )
        }
    }

    private func drawEdges(context: inout GraphicsContext) {
        let nodeMap: [UUID: GraphNode] = Dictionary(
            appState.graphDocument.nodes.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for edge in appState.graphDocument.edges {
            guard let sourceNode = nodeMap[edge.sourceNodeId],
                  let targetNode = nodeMap[edge.targetNodeId] else { continue }

            let sourceScreen: CGPoint = viewportTransform.apply(sourceNode.position)
            let targetScreen: CGPoint = viewportTransform.apply(targetNode.position)

            let edgeColor: Color = edgeColor(for: edge.edgeType)
            let lineWidth: CGFloat = edge.edgeType == .containment ? 3.0 : 3.5

            var path: Path = Path()
            path.move(to: sourceScreen)

            let midX: CGFloat = (sourceScreen.x + targetScreen.x) / 2
            let controlOffset: CGFloat = abs(targetScreen.y - sourceScreen.y) * 0.3
            path.addCurve(
                to: targetScreen,
                control1: CGPoint(x: midX + controlOffset, y: sourceScreen.y),
                control2: CGPoint(x: midX - controlOffset, y: targetScreen.y)
            )

            var edgeContext: GraphicsContext = context
            edgeContext.opacity = edge.edgeType == .containment ? 0.7 : 0.8
            edgeContext.stroke(path, with: .color(edgeColor), lineWidth: lineWidth)
        }
    }

    private func drawNodes(context: inout GraphicsContext) {
        for node in appState.graphDocument.nodes {
            let screenPos: CGPoint = viewportTransform.apply(node.position)
            let isSelected: Bool = selectedNodeId == node.id
            let isDragging: Bool = draggedNodeId == node.id

            let nodeRect: CGRect = CGRect(
                x: screenPos.x - nodeWidth / 2,
                y: screenPos.y - nodeHeight / 2,
                width: nodeWidth,
                height: nodeHeight
            )

            let nodePath: Path = RoundedRectangle(cornerRadius: nodeCornerRadius).path(in: nodeRect)
            context.fill(nodePath, with: .color(Color.black.opacity(0.7)))

            let borderColor: Color = isSelected ? .blue : (isDragging ? .white : .gray)
            let borderWidth: CGFloat = isSelected ? 2.0 : 1.0
            context.stroke(nodePath, with: .color(borderColor.opacity(isSelected ? 0.8 : 0.3)), lineWidth: borderWidth)

            let statusColor: Color = nodeStatusColor(for: node)
            let statusRect: CGRect = CGRect(
                x: nodeRect.minX + 8,
                y: nodeRect.midY - 4,
                width: 8,
                height: 8
            )
            let statusPath: Path = Ellipse().path(in: statusRect)
            context.fill(statusPath, with: .color(statusColor))

            let labelText: Text = Text(node.name)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            let resolvedLabel = context.resolve(labelText)

            let labelX: CGFloat = nodeRect.minX + 22
            let labelY: CGFloat = nodeRect.midY - resolvedLabel.measure(in: nodeRect.size).height / 2
            context.draw(resolvedLabel, at: CGPoint(x: labelX, y: labelY), anchor: .topLeading)

            let typeIcon: Text = Text(nodeTypeIcon(for: node.nodeType))
                .font(.system(size: 10))
                .foregroundColor(.gray)
            let resolvedIcon = context.resolve(typeIcon)
            let iconX: CGFloat = nodeRect.maxX - 20
            let iconY: CGFloat = nodeRect.midY
            context.draw(resolvedIcon, at: CGPoint(x: iconX, y: iconY), anchor: .center)
        }
    }

    private func nodeOverlays(size: CGSize) -> some View {
        ForEach(appState.graphDocument.nodes) { node in
            let screenPos: CGPoint = viewportTransform.apply(node.position)
            Color.clear
                .frame(width: nodeWidth, height: nodeHeight)
                .contentShape(Rectangle())
                .position(screenPos)
                .gesture(nodeDragGesture(nodeId: node.id))
                .contextMenu {
                    Button("Focus Terminal") {
                        appState.focusGraphNode(node.id)
                    }
                    Divider()
                    Button("Rename") {
                        if let terminalId = node.terminalId {
                            appState.renamingTerminalId = terminalId
                        }
                    }
                }
        }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if panStartTranslation == nil {
                    panStartTranslation = viewportTransform.translation
                }
                guard let start = panStartTranslation else { return }
                viewportTransform.translation = SIMD2<Double>(
                    start.x + value.translation.width,
                    start.y + value.translation.height
                )
            }
            .onEnded { _ in
                panStartTranslation = nil
            }
    }

    private func zoomGesture(center: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale: Double = max(0.1, min(viewportTransform.scale * value.magnification, 5.0))
                viewportTransform = ViewportTransform(
                    translation: viewportTransform.translation,
                    scale: newScale
                )
            }
    }

    private func nodeDragGesture(nodeId: UUID) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                draggedNodeId = nodeId
                let canvasPoint: CGPoint = viewportTransform.invert(value.location)
                appState.updateGraphNodePosition(nodeId, to: canvasPoint)
            }
            .onEnded { _ in
                draggedNodeId = nil
                appState.pinGraphNode(nodeId)
                appState.saveGraphState()
            }
    }

    private func handleSingleTap(at location: CGPoint) {
        let canvasPoint: CGPoint = viewportTransform.invert(location)
        selectedNodeId = hitTestNode(at: canvasPoint)
    }

    private func handleDoubleTap(at location: CGPoint) {
        let canvasPoint: CGPoint = viewportTransform.invert(location)
        guard let nodeId = hitTestNode(at: canvasPoint) else { return }
        appState.focusGraphNode(nodeId)
    }

    private func hitTestNode(at canvasPoint: CGPoint) -> UUID? {
        let halfWidth: CGFloat = nodeWidth / (2 * viewportTransform.scale)
        let halfHeight: CGFloat = nodeHeight / (2 * viewportTransform.scale)

        for node in appState.graphDocument.nodes.reversed() {
            let dx: CGFloat = abs(canvasPoint.x - node.position.x)
            let dy: CGFloat = abs(canvasPoint.y - node.position.y)
            if dx <= halfWidth && dy <= halfHeight {
                return node.id
            }
        }
        return nil
    }

    private func edgeColor(for edgeType: EdgeType) -> Color {
        switch edgeType {
        case .containment:
            return .gray
        case .dependency:
            return .blue
        case .custom:
            return .purple
        }
    }

    private func nodeStatusColor(for node: GraphNode) -> Color {
        guard let terminalId = node.terminalId else { return .gray }
        let isActive: Bool = appState.workspaces
            .flatMap(\.terminals)
            .first { $0.id == terminalId }?.isActive ?? false
        return isActive ? .green : .gray
    }

    private func nodeTypeIcon(for nodeType: NodeType) -> String {
        switch nodeType {
        case .terminal:
            return ">"
        case .markdown:
            return "#"
        }
    }
}
