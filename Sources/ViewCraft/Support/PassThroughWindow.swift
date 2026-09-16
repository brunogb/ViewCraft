#if os(iOS)
import UIKit

final class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard super.hitTest(point, with: event) != nil,
              let rootView = rootViewController?.view else { return nil }
        // SwiftUI backs empty scaffolding with *named* layers and real drawn
        // content with *unnamed* layers. An unnamed layer at this point means
        // actual overlay content, so deliver the touch to it; a named layer
        // means empty space, so pass the touch through to the app below
        // (return nil). Inverting this makes the always-on overlay window
        // swallow every touch and freeze the UI.
        if rootView.layer.hitTest(point)?.name == nil {
            return rootView
        }
        return nil
    }
}
#endif
