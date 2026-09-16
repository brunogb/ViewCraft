import SwiftUI

public enum TextFillRevealMetrics {
    public static func glyphFill(index: Int, count: Int, progress: CGFloat, bandWidth: CGFloat) -> CGFloat {
        guard count > 0 else { return progress }
        guard bandWidth > 0 else {
            return CGFloat(index) < progress * CGFloat(count) ? 1 : 0
        }
        let front = progress * (CGFloat(count - 1) + bandWidth)
        return min(max((front - CGFloat(index)) / bandWidth, 0), 1)
    }
}

public extension Text {
    func fillReveal(progress: CGFloat, dimOpacity: CGFloat = 0.25, bandWidth: CGFloat = 2.5) -> some View {
        textRenderer(TextFillRevealRenderer(progress: progress, dimOpacity: dimOpacity, bandWidth: bandWidth))
    }
}

@Animatable
private struct TextFillRevealRenderer: TextRenderer {
    var progress: CGFloat
    @AnimatableIgnored var dimOpacity: CGFloat
    @AnimatableIgnored var bandWidth: CGFloat

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let slices = layout.flatMap { $0 }.flatMap { $0 }

        for (index, slice) in slices.enumerated() {
            var sliceContext = context
            let fill = TextFillRevealMetrics.glyphFill(
                index: index, count: slices.count, progress: progress, bandWidth: bandWidth
            )
            sliceContext.opacity = dimOpacity + (1 - dimOpacity) * fill
            sliceContext.draw(slice)
        }
    }
}
