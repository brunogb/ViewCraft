import SwiftUI

public extension View {
    // - Warning: `mask` rasterises. Fine for text and shapes; a hosted layer
    //   (camera preview, video, `glassEffect`) renders blank under it.
    func progressMask(_ fraction: CGFloat, axis: Axis = .horizontal) -> some View {
        mask(alignment: axis == .horizontal ? .leading : .bottom) {
            Rectangle().scale(
                x: axis == .horizontal ? max(fraction, 0) : 1,
                y: axis == .vertical ? max(fraction, 0) : 1,
                anchor: axis == .horizontal ? .leading : .bottom
            )
        }
    }

    func progressMask(filledWidth: CGFloat) -> some View {
        mask(alignment: .leading) {
            Rectangle().frame(width: max(filledWidth, 0))
        }
    }
}
