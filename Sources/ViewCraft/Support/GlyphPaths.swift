import SwiftUI
import CoreText

#if canImport(UIKit)
import UIKit
// The concrete font type CoreText's glyph APIs need — SwiftUI's own `Font`
// can't be introspected back into one.
public typealias PlatformFont = UIFont
#else
import AppKit
public typealias PlatformFont = NSFont
#endif

// Drops below SwiftUI to CoreText because nothing in `Text`/`TextRenderer`
// exposes a glyph's actual outline — `CTFontCreatePathForGlyph` does.
public enum GlyphPaths {
    public static func paths(for text: String, font: PlatformFont) -> (paths: [Path], size: CGSize) {
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return ([], .zero) }

        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

        // CoreText lays out glyphs y-up with the baseline at 0; SwiftUI draws
        // y-down with the top of the line at 0.
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: ascent)

        var paths: [Path] = []
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            guard glyphCount > 0 else { continue }

            // Glyph indices are only meaningful against the specific font that
            // shaped this run, which isn't necessarily `font` itself — a
            // descriptor CoreText can't satisfy exactly gets silently
            // substituted for a fallback font at shaping time, and looking its
            // glyph indices up in the requested font instead reads the wrong
            // glyph table (a real symptom seen here: the wrong letter, or a digit).
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let runFont = attributes[kCTFontAttributeName as String] else { continue }
            let runCTFont = runFont as! CTFont

            var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            var positions = [CGPoint](repeating: .zero, count: glyphCount)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)

            for index in 0..<glyphCount {
                guard let glyphPath = CTFontCreatePathForGlyph(runCTFont, glyphs[index], nil) else { continue }
                var transform = CGAffineTransform(translationX: positions[index].x, y: positions[index].y)
                    .concatenating(flip)
                guard let positioned = glyphPath.copy(using: &transform) else { continue }
                paths.append(Path(positioned))
            }
        }

        return (paths, CGSize(width: width, height: ascent + descent))
    }
}
