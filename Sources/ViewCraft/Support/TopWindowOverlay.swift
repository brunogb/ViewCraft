#if os(iOS)
import SwiftUI

public extension View {
    func topWindowOverlay<Overlay: View>(
        isPresented: Binding<Bool>,
        alignment: Alignment = .top,
        hidesStatusBar: Bool = false,
        @ViewBuilder overlay: @escaping (_ isPresented: Bool) -> Overlay
    ) -> some View {
        modifier(TopWindowOverlayModifier(isPresented: isPresented,
                                          alignment: alignment,
                                          hidesStatusBar: hidesStatusBar,
                                          overlay: overlay))
    }
}

private struct TopWindowOverlayModifier<Overlay: View>: ViewModifier {
    @Binding var isPresented: Bool
    var alignment: Alignment
    var hidesStatusBar: Bool
    @ViewBuilder var overlay: (Bool) -> Overlay

    func body(content: Content) -> some View {
        content.background(
            TopWindowOverlayInstaller(
                isPresented: isPresented,
                alignment: alignment,
                hidesStatusBar: hidesStatusBar,
                makeContent: { AnyView(overlay($0)) }
            )
        )
    }
}

final class OverlayHostingController: UIHostingController<AnyView> {
    var statusBarHidden = false {
        didSet {
            guard statusBarHidden != oldValue else { return }
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    override var prefersStatusBarHidden: Bool { statusBarHidden }
}

// Content is hosted directly here, only wrapped in a safe-area-transparent
// ZStack for alignment — an earlier version wrapped it in `.ignoresSafeArea()`
// instead, which zeroed the window's real safe-area insets and broke Dynamic
// Island detection for anything hosted inside.
private struct TopWindowOverlayInstaller: UIViewRepresentable {
    var isPresented: Bool
    var alignment: Alignment
    var hidesStatusBar: Bool
    var makeContent: (Bool) -> AnyView

    func makeUIView(context: Context) -> UIView {
        let probe = UIView(frame: .zero)
        probe.backgroundColor = .clear
        let coordinator = context.coordinator
        DispatchQueue.main.async { [weak probe] in
            guard let scene = probe?.window?.windowScene else { return }
            coordinator.attach(to: scene)
            // A fresh Transaction(), not one carried over from a caller: this is
            // the window's very first render, on a deferred async hop, not a
            // reaction to a SwiftUI state change, so there's nothing to inherit.
            coordinator.update(isPresented: isPresented,
                               alignment: alignment,
                               hidesStatusBar: hidesStatusBar,
                               makeContent: makeContent,
                               transaction: Transaction())
        }
        return probe
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(isPresented: isPresented,
                                   alignment: alignment,
                                   hidesStatusBar: hidesStatusBar,
                                   makeContent: makeContent,
                                   transaction: context.transaction)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // Without this the window stays in the scene's `windows` array — which
    // retains it — so every visit to a screen that installs an overlay leaves
    // another invisible window behind, each one still hit-testing every touch.
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private var window: PassThroughWindow?
        private var host: OverlayHostingController?
        private var latest: (isPresented: Bool, alignment: Alignment, makeContent: (Bool) -> AnyView)?

        func attach(to scene: UIWindowScene) {
            guard window == nil else { return }
            let overlayWindow = PassThroughWindow(windowScene: scene)
            overlayWindow.backgroundColor = .clear
            overlayWindow.windowLevel = .alert + 1
            overlayWindow.isHidden = false
            overlayWindow.isUserInteractionEnabled = true
            let controller = OverlayHostingController(rootView: AnyView(EmptyView()))
            controller.view.backgroundColor = .clear
            overlayWindow.rootViewController = controller
            self.window = overlayWindow
            self.host = controller
            render()
        }

        func detach() {
            window?.isHidden = true
            window?.rootViewController = nil
            window = nil
            host = nil
        }

        func update(
            isPresented: Bool,
            alignment: Alignment,
            hidesStatusBar: Bool,
            makeContent: @escaping (Bool) -> AnyView,
            transaction: Transaction
        ) {
            latest = (isPresented, alignment, makeContent)
            host?.statusBarHidden = hidesStatusBar && isPresented
            // Assigning `rootView` crosses straight into a different
            // UIHostingController's own SwiftUI render pass — a boundary that
            // does not inherit the calling transaction just because
            // `updateUIView` happened to run inside one. Wrapping in the real
            // `transaction` here is what actually applies the animation on the
            // other side, instead of every crossing being a silent, unanimated snap.
            withTransaction(transaction) {
                render()
            }
        }

        private func render() {
            guard let host, let latest else { return }
            host.rootView = AnyView(
                ZStack(alignment: latest.alignment) {
                    latest.makeContent(latest.isPresented)
                }
            )
        }
    }
}
#endif
