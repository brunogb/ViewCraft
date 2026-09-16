import SwiftUI

public struct PositionPadConfig: Sendable, Equatable {
    public var count: Int
    public var size: CGFloat
    public var tint: Color
    public var dotSize: CGFloat
    public var touchPointSize: CGFloat
    public var influenceRadius: CGFloat
    public var restingZoom: CGFloat
    public var animation: Animation

    public init(count: Int = 11,
                size: CGFloat = 140,
                tint: Color = .white,
                dotSize: CGFloat = 4,
                touchPointSize: CGFloat = 35,
                influenceRadius: CGFloat = 60,
                restingZoom: CGFloat = 3,
                animation: Animation = .easeInOut(duration: 0.2)) {
        self.count = max(count, 1)
        self.size = size
        self.tint = tint
        self.dotSize = dotSize
        self.touchPointSize = touchPointSize
        self.influenceRadius = influenceRadius
        self.restingZoom = restingZoom
        self.animation = animation
    }

    public static let `default` = PositionPadConfig()

    public var itemSize: CGFloat { size / CGFloat(count) }
}

public enum PositionPadMetrics {
    public static func location(for position: CGPoint, padSize: CGFloat, itemSize: CGFloat) -> CGPoint {
        let minimum = itemSize / 2
        let maximum = padSize - itemSize / 2
        let span = maximum - minimum
        return CGPoint(x: minimum + clamped(position.x) * span,
                       y: minimum + clamped(position.y) * span)
    }

    public static func position(for location: CGPoint, padSize: CGFloat, itemSize: CGFloat) -> CGPoint {
        let minimum = itemSize / 2
        let maximum = padSize - itemSize / 2
        let span = maximum - minimum
        guard span > 0 else { return CGPoint(x: 0, y: 0) }
        return CGPoint(x: clamped((location.x - minimum) / span),
                       y: clamped((location.y - minimum) / span))
    }

    public static func cell(at location: CGPoint, itemSize: CGFloat, count: Int) -> (row: Int, column: Int) {
        guard itemSize > 0 else { return (0, 0) }
        let column = Int(location.x / itemSize)
        let row = Int(location.y / itemSize)
        return (row: min(max(row, 0), count - 1), column: min(max(column, 0), count - 1))
    }

    public static func proximity(of location: CGPoint,
                                 toRow row: Int,
                                 column: Int,
                                 itemSize: CGFloat,
                                 radius: CGFloat) -> CGFloat {
        guard radius > 0 else { return 0 }
        let dx = location.x - CGFloat(column) * itemSize
        let dy = location.y - CGFloat(row) * itemSize
        let distance = sqrt(dx * dx + dy * dy)
        return 1 - clamped(distance / radius)
    }

    public static func clampToGrid(_ location: CGPoint, padSize: CGFloat, itemSize: CGFloat) -> CGPoint {
        CGPoint(x: min(max(location.x, itemSize / 2), padSize - itemSize / 2),
                y: min(max(location.y, itemSize / 2), padSize - itemSize / 2))
    }

    private static func clamped(_ value: CGFloat) -> CGFloat { min(max(value, 0), 1) }
}

public struct PositionPad: View {
    private let config: PositionPadConfig
    @Binding private var position: CGPoint

    @GestureState private var dragLocation: CGPoint?
    @State private var isDragging = false

    public init(position: Binding<CGPoint>, config: PositionPadConfig = .default) {
        self._position = position
        self.config = config
    }

    public var body: some View {
        let itemSize = config.itemSize
        let location = dragLocation
            ?? PositionPadMetrics.location(for: position, padSize: config.size, itemSize: itemSize)
        let active = PositionPadMetrics.cell(at: location, itemSize: itemSize, count: config.count)

        VStack(spacing: 0) {
            ForEach(0..<config.count, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<config.count, id: \.self) { column in
                        dot(row: row, column: column, location: location, active: active, itemSize: itemSize)
                    }
                }
            }
        }
        .frame(width: config.size, height: config.size)
        .overlay(alignment: .topLeading) {
            touchPoint(location: location, active: active, itemSize: itemSize)
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                .updating($dragLocation) { value, state, _ in
                    state = PositionPadMetrics.clampToGrid(value.location,
                                                           padSize: config.size,
                                                           itemSize: itemSize)
                }
                .onChanged { value in
                    let clamped = PositionPadMetrics.clampToGrid(value.location,
                                                                 padSize: config.size,
                                                                 itemSize: itemSize)
                    if !isDragging {
                        withAnimation(config.animation) { isDragging = true }
                    }
                    position = PositionPadMetrics.position(for: clamped,
                                                           padSize: config.size,
                                                           itemSize: itemSize)
                }
                .onEnded { _ in
                    withAnimation(config.animation) { isDragging = false }
                }
        )
        .coordinateSpace(.named(Self.space))
    }

    private func dot(row: Int, column: Int, location: CGPoint,
                     active: (row: Int, column: Int), itemSize: CGFloat) -> some View {
        let proximity = PositionPadMetrics.proximity(of: location, toRow: row, column: column,
                                                     itemSize: itemSize, radius: config.influenceRadius)
        let isOnAxis = active.row == row || active.column == column
        let isSettled = active.row == row && active.column == column

        // Dragging: a swell around the finger. Released: the settled dot grows
        // and its row/column stay lit, so the value reads with no finger on screen.
        return Circle()
            .fill(config.tint)
            .frame(width: config.dotSize, height: config.dotSize)
            .scaleEffect(isDragging ? 0.7 + proximity : (isSettled ? config.restingZoom : 1))
            .opacity(isDragging ? 0.1 + proximity : (isOnAxis ? 1 : 0.3))
            .frame(width: itemSize, height: itemSize)
    }

    private func touchPoint(location: CGPoint, active: (row: Int, column: Int),
                            itemSize: CGFloat) -> some View {
        let diameter = isDragging ? config.touchPointSize : config.dotSize * config.restingZoom
        // Follows the finger while dragging, then snaps to the settled dot.
        let offset = isDragging
            ? CGSize(width: location.x - itemSize / 2, height: location.y - itemSize / 2)
            : CGSize(width: CGFloat(active.column) * itemSize, height: CGFloat(active.row) * itemSize)

        return Circle()
            .fill(config.tint)
            .frame(width: diameter, height: diameter)
            .offset(offset)
            .frame(width: itemSize, height: itemSize)
    }

    private static var space: String { "craftkit.position-pad" }
}
