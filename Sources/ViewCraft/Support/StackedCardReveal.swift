import SwiftUI

public struct StackedCardRevealMetrics: Sendable, Equatable {
    public var index: Int
    public var isExpanded: Bool
    public var isRevealed: Bool
    public var scrollOffsetX: CGFloat
    public var visiblePeekCount: Int
    public var stepScale: CGFloat
    public var stepOffset: CGFloat

    public init(index: Int, isExpanded: Bool, isRevealed: Bool, scrollOffsetX: CGFloat,
                visiblePeekCount: Int = 3, stepScale: CGFloat = 0.1, stepOffset: CGFloat = 10) {
        self.index = index
        self.isExpanded = isExpanded
        self.isRevealed = isRevealed
        self.scrollOffsetX = scrollOffsetX
        self.visiblePeekCount = visiblePeekCount
        self.stepScale = stepScale
        self.stepOffset = stepOffset
    }

    public var scale: CGFloat { isExpanded ? 1 : 1 - (CGFloat(index) * stepScale) }

    public var stackOffsetX: CGFloat { isExpanded ? 0 : CGFloat(index) * stepOffset }

    public var scrollCorrectionOffsetX: CGFloat { isRevealed ? 0 : -scrollOffsetX }

    public var opacity: Double { index >= visiblePeekCount ? (isRevealed ? 1 : 0) : 1 }
}

public extension View {
    func stackedCardReveal(index: Int,
                            isExpanded: Bool,
                            isRevealed: Bool,
                            config: StackedCardRevealConfig = .default) -> some View {
        visualEffect { [isExpanded, isRevealed, config] content, proxy in
            let minX = proxy.frame(in: .scrollView).minX
            let metrics = StackedCardRevealMetrics(
                index: index, isExpanded: isExpanded, isRevealed: isRevealed, scrollOffsetX: minX,
                visiblePeekCount: config.visiblePeekCount, stepScale: config.stepScale, stepOffset: config.stepOffset
            )
            return content
                .scaleEffect(metrics.scale, anchor: .trailing)
                .offset(x: metrics.stackOffsetX)
                .offset(x: metrics.scrollCorrectionOffsetX)
        }
        .opacity(StackedCardRevealMetrics(
            index: index, isExpanded: isExpanded, isRevealed: isRevealed, scrollOffsetX: 0,
            visiblePeekCount: config.visiblePeekCount
        ).opacity)
        .zIndex(Double(-index))
    }
}

public struct StackedCardRevealConfig: Sendable, Equatable {
    public var visiblePeekCount: Int
    public var stepScale: CGFloat
    public var stepOffset: CGFloat

    public init(visiblePeekCount: Int = 3, stepScale: CGFloat = 0.1, stepOffset: CGFloat = 10) {
        self.visiblePeekCount = visiblePeekCount
        self.stepScale = stepScale
        self.stepOffset = stepOffset
    }

    public static let `default` = StackedCardRevealConfig()
}
