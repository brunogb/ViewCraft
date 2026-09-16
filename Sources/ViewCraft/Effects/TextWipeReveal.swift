import SwiftUI

public extension Text {
    // @MainActor: an extension on a concrete type doesn't inherit isolation the
    // way a View conformance would, and progressMask(_:axis:) is main-actor-isolated.
    @MainActor
    func wipeReveal(progress: CGFloat, dimOpacity: CGFloat = 0.25, axis: Axis = .horizontal) -> some View {
        ZStack(alignment: axis == .horizontal ? .leading : .bottom) {
            opacity(dimOpacity)
            progressMask(progress, axis: axis)
        }
    }
}
