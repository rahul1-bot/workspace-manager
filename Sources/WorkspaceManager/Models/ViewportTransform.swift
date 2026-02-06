import Foundation

struct ViewportTransform: Sendable {
    var translation: SIMD2<Double>
    var scale: Double

    init(translation: SIMD2<Double> = .zero, scale: Double = 1.0) {
        self.translation = translation
        self.scale = max(0.1, min(scale, 5.0))
    }

    func apply(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * scale + translation.x,
            y: point.y * scale + translation.y
        )
    }

    func invert(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - translation.x) / scale,
            y: (point.y - translation.y) / scale
        )
    }

    static let identity: ViewportTransform = ViewportTransform()
}
