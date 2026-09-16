import SwiftUI

public struct TextWritingRevealConfig: Sendable, Equatable {
    public var dimColor: Color
    public var fillColor: Color
    public var penWidthMultiplier: CGFloat

    public init(dimColor: Color = .primary.opacity(0.2),
                fillColor: Color = .primary,
                penWidthMultiplier: CGFloat = 0.12) {
        self.dimColor = dimColor
        self.fillColor = fillColor
        self.penWidthMultiplier = penWidthMultiplier
    }

    public static let `default` = TextWritingRevealConfig()
}

@Animatable
public struct TextWritingReveal: View {
    @AnimatableIgnored public var text: String
    @AnimatableIgnored public var font: PlatformFont
    public var progress: CGFloat
    @AnimatableIgnored public var config: TextWritingRevealConfig

    public init(text: String, font: PlatformFont, progress: CGFloat, config: TextWritingRevealConfig = .default) {
        self.text = text
        self.font = font
        self.progress = progress
        self.config = config
    }

    public var body: some View {
        let (paths, size) = GlyphPaths.paths(for: text, font: font)
        let penWidth = font.pointSize * config.penWidthMultiplier

        Canvas { context, _ in
            for (index, glyphPath) in paths.enumerated() {
                context.fill(glyphPath, with: .color(config.dimColor))

                let glyphProgress = progress.windowedProgress(index: index, count: paths.count)
                guard glyphProgress > 0 else { continue }

                if glyphProgress >= 1 {
                    context.fill(glyphPath, with: .color(config.fillColor))
                } else {
                    var writingContext = context
                    writingContext.clip(to: glyphPath)
                    writingContext.stroke(
                        glyphPath.trimmedPath(from: 0, to: glyphProgress),
                        with: .color(config.fillColor),
                        style: StrokeStyle(lineWidth: penWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
