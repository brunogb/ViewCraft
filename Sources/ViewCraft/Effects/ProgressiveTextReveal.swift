import SwiftUI

public enum ProgressiveTextRevealMetrics {
    public static func sliceProgress(index: Int, count: Int, progress: CGFloat) -> CGFloat {
        guard count > 0, index >= 0 else { return 0 }
        let reached = CGFloat(count) * progress
        return min(max(reached / CGFloat(index + 1), 0), 1)
    }
}

public extension Text {
    func progressiveReveal(progress: CGFloat, blurRadius: CGFloat = 5, rise: CGFloat = 5) -> some View {
        textRenderer(ProgressiveTextRenderer(progress: progress,
                                             blurRadius: blurRadius,
                                             rise: rise))
    }
}

@Animatable
struct ProgressiveTextRenderer: TextRenderer {
    var progress: CGFloat
    @AnimatableIgnored var blurRadius: CGFloat
    @AnimatableIgnored var rise: CGFloat

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let slices = layout.flatMap { $0 }.flatMap { $0 }

        // The graphics context is deliberately not copied per glyph here, unlike
        // most of the other text renderers in this library — each slice inherits
        // the filters already applied to the ones before it.
        for (index, slice) in slices.enumerated() {
            let sliceProgress = ProgressiveTextRevealMetrics.sliceProgress(
                index: index, count: slices.count, progress: progress
            )

            context.addFilter(.blur(radius: blurRadius - blurRadius * sliceProgress))
            context.opacity = sliceProgress
            context.translateBy(x: 0, y: rise - rise * sliceProgress)
            // disablesSubpixelQuantization: without it, nudging glyphs by fractional
            // amounts gets quantised to the pixel grid and the rise jitters.
            context.draw(slice, options: .disablesSubpixelQuantization)
        }
    }
}
