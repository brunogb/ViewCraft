import SwiftUI

public struct TruncationEffectConfig: Sendable, Equatable {
    public var lineLimit: Int
    public var moreLabel: String
    public var moreColor: Color
    public var blurRadius: CGFloat
    public var animation: Animation

    public init(lineLimit: Int = 3,
                moreLabel: String = "…More",
                moreColor: Color = .gray,
                blurRadius: CGFloat = 5,
                animation: Animation = .smooth(duration: 0.45)) {
        self.lineLimit = max(lineLimit, 1)
        self.moreLabel = moreLabel
        self.moreColor = moreColor
        self.blurRadius = blurRadius
        self.animation = animation
    }

    public static let `default` = TruncationEffectConfig()
}

public extension Text {
    // @MainActor: an extension on a concrete type doesn't inherit isolation the
    // way a View conformance would, and the modifier this builds is
    // main-actor-isolated.
    @MainActor
    func truncationEffect(isExpanded: Bool,
                          config: TruncationEffectConfig = .default) -> some View {
        modifier(TruncationEffectModifier(isExpanded: isExpanded, config: config, text: self))
    }
}

private struct TruncationEffectModifier: ViewModifier {
    let isExpanded: Bool
    let config: TruncationEffectConfig
    let text: Text

    @State private var collapsedSize: CGSize = .zero
    @State private var fullSize: CGSize = .zero
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        // The invisible copy below reserves the collapsed height; the visible
        // copy is drawn over it by the renderer, so the two can differ in height
        // without the surrounding layout jumping.
        content
            .lineLimit(config.lineLimit)
            .opacity(0)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { collapsedSize = $0 }
            .frame(height: progress == 1 ? fullSize.height : nil)
            .overlay {
                GeometryReader { proxy in
                    text
                        .textRenderer(
                            TruncationTextRenderer(
                                lineLimit: config.lineLimit,
                                moreLabel: config.moreLabel,
                                moreColor: config.moreColor,
                                maximumBlur: config.blurRadius,
                                progress: progress
                            )
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { fullSize = $0 }
                        .frame(width: proxy.size.width,
                               height: proxy.size.height,
                               alignment: progress == 1 ? .leading : .topLeading)
                }
            }
            .contentShape(.rect)
            .onChange(of: isExpanded) { _, newValue in
                withAnimation(config.animation) { progress = newValue ? 1 : 0 }
            }
            .onAppear { progress = isExpanded ? 1 : 0 }
    }
}

@Animatable
private struct TruncationTextRenderer: TextRenderer {
    // Animating a line count would relayout the text on every frame.
    @AnimatableIgnored var lineLimit: Int
    @AnimatableIgnored var moreLabel: String
    @AnimatableIgnored var moreColor: Color
    @AnimatableIgnored var maximumBlur: CGFloat
    var progress: CGFloat

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for (index, line) in layout.enumerated() {
            var lineContext = context

            if index == lineLimit - 1 {
                drawLastVisibleLine(line, in: &lineContext)
            } else if index < lineLimit {
                lineContext.draw(line)
            } else {
                drawHiddenLine(at: index, layout: layout, in: &lineContext)
            }
        }
    }

    private func drawHiddenLine(at index: Int, layout: Text.Layout, in context: inout GraphicsContext) {
        let line = layout[index]
        let lineProgress = progress.windowedProgress(index: index - lineLimit,
                                                     count: max(layout.count - lineLimit, 1))

        context.opacity = lineProgress
        context.addFilter(.blur(radius: maximumBlur - maximumBlur * lineProgress))
        context.draw(line)
    }

    // Splits the last visible line into a head that stays put and a tail that
    // fades out as the label fades in over it, so the label replaces the words
    // it's standing in for instead of sitting on top of them.
    private func drawLastVisibleLine(_ line: Text.Layout.Line, in context: inout GraphicsContext) {
        let runs = line.flatMap { $0 }
        let tailCount = moreLabel.count
        let tailStart = max(runs.count - tailCount, 0)

        for index in 0..<tailStart {
            context.draw(runs[index])
        }

        for index in tailStart..<runs.count {
            context.opacity = progress
            context.draw(runs[index])
        }

        guard progress < 1 else { return }

        let bounds = runs.indices.contains(tailStart)
            ? runs[tailStart].typographicBounds
            : line.typographicBounds

        // Sized from the line's own ascent, so the label matches whatever font
        // the caller used without being told about it.
        let label = Text(moreLabel)
            .font(.system(size: bounds.ascent))
            .foregroundStyle(moreColor)

        context.opacity = 1 - progress
        context.draw(label, at: CGPoint(x: bounds.rect.minX, y: bounds.rect.midY), anchor: .leading)
    }
}
