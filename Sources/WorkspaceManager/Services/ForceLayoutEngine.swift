import Foundation
import simd

@MainActor
final class ForceLayoutEngine {
    private var nodes: [ForceNode] = []
    private var edges: [(source: Int, target: Int)] = []
    private var nodeIdToIndex: [UUID: Int] = [:]
    private var indexToNodeId: [Int: UUID] = [:]
    private var alpha: Double = 1.0
    private let alphaMin: Double = 0.001
    private let alphaDecay: Double = 0.02
    private let velocityDecay: Double = 0.4

    private let repulsionStrength: Double = -600
    private let linkStiffness: Double = 0.15
    private let linkRestLength: Double = 200
    private let centerStrength: Double = 0.05
    private let collideRadius: Double = 90

    func configure(graphNodes: [GraphNode], graphEdges: [GraphEdge]) {
        nodeIdToIndex.removeAll()
        indexToNodeId.removeAll()
        nodes.removeAll()
        edges.removeAll()
        alpha = 1.0

        for (index, graphNode) in graphNodes.enumerated() {
            nodeIdToIndex[graphNode.id] = index
            indexToNodeId[index] = graphNode.id
            nodes.append(ForceNode(
                position: SIMD2<Double>(graphNode.positionX, graphNode.positionY),
                velocity: .zero,
                isPinned: graphNode.isPinned
            ))
        }

        for graphEdge in graphEdges {
            guard let sourceIndex = nodeIdToIndex[graphEdge.sourceNodeId],
                  let targetIndex = nodeIdToIndex[graphEdge.targetNodeId] else { continue }
            edges.append((source: sourceIndex, target: targetIndex))
        }
    }

    func tick() -> Bool {
        guard alpha >= alphaMin else { return false }
        alpha += (0.0 - alpha) * alphaDecay

        applyManyBodyForce()
        applyLinkForce()
        applyCenterForce()
        applyCollisionForce()

        for i in nodes.indices {
            guard !nodes[i].isPinned else { continue }
            nodes[i].velocity *= velocityDecay
            nodes[i].position += nodes[i].velocity
        }

        return alpha >= alphaMin
    }

    func positions() -> [UUID: CGPoint] {
        var result: [UUID: CGPoint] = [:]
        for (index, node) in nodes.enumerated() {
            guard !node.isPinned else { continue }
            guard let nodeId = indexToNodeId[index] else { continue }
            result[nodeId] = CGPoint(x: node.position.x, y: node.position.y)
        }
        return result
    }

    func invalidate() {
        nodes.removeAll()
        edges.removeAll()
        nodeIdToIndex.removeAll()
        indexToNodeId.removeAll()
        alpha = 0
    }

    private func applyManyBodyForce() {
        let count: Int = nodes.count
        for i in 0..<count {
            guard !nodes[i].isPinned else { continue }
            for j in 0..<count where i != j {
                let delta: SIMD2<Double> = nodes[i].position - nodes[j].position
                var distSq: Double = simd_length_squared(delta)
                if distSq < 1.0 { distSq = 1.0 }
                let dist: Double = sqrt(distSq)
                let force: Double = repulsionStrength * alpha / distSq
                nodes[i].velocity += (delta / dist) * force
            }
        }
    }

    private func applyLinkForce() {
        for edge in edges {
            let delta: SIMD2<Double> = nodes[edge.target].position - nodes[edge.source].position
            let dist: Double = max(simd_length(delta), 1.0)
            let displacement: Double = (dist - linkRestLength) * linkStiffness * alpha
            let direction: SIMD2<Double> = delta / dist

            if !nodes[edge.source].isPinned {
                nodes[edge.source].velocity += direction * displacement
            }
            if !nodes[edge.target].isPinned {
                nodes[edge.target].velocity -= direction * displacement
            }
        }
    }

    private func applyCenterForce() {
        var centroid: SIMD2<Double> = .zero
        var count: Int = 0
        for node in nodes {
            centroid += node.position
            count += 1
        }
        guard count > 0 else { return }
        centroid /= Double(count)

        for i in nodes.indices {
            guard !nodes[i].isPinned else { continue }
            nodes[i].velocity -= centroid * centerStrength * alpha
        }
    }

    private func applyCollisionForce() {
        let count: Int = nodes.count
        let diameter: Double = collideRadius * 2
        for i in 0..<count {
            guard !nodes[i].isPinned else { continue }
            for j in (i + 1)..<count {
                let delta: SIMD2<Double> = nodes[i].position - nodes[j].position
                let dist: Double = max(simd_length(delta), 0.1)
                guard dist < diameter else { continue }
                let overlap: Double = (diameter - dist) * 0.5
                let direction: SIMD2<Double> = delta / dist

                if !nodes[i].isPinned {
                    nodes[i].velocity += direction * overlap * 0.3
                }
                if !nodes[j].isPinned {
                    nodes[j].velocity -= direction * overlap * 0.3
                }
            }
        }
    }
}

private struct ForceNode {
    var position: SIMD2<Double>
    var velocity: SIMD2<Double>
    var isPinned: Bool
}
