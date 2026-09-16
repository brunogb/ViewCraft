import CoreGraphics

// Cross-platform (and so unit-testable on macOS) even though only iOS has the
// hardware, so anything that wants to grow out of the cutout agrees on where
// "it" is regardless of platform.
public enum DynamicIslandMetrics {
    public static let size = CGSize(width: 120, height: 36)
    // Island devices report at least this much top safe area; older notched
    // and flat-top devices report less.
    public static let detectionInset: CGFloat = 59

    public static func isPresent(topSafeAreaInset: CGFloat) -> Bool {
        topSafeAreaInset >= detectionInset
    }

    public static func topOffset(topSafeAreaInset: CGFloat) -> CGFloat {
        11 + max(topSafeAreaInset - detectionInset, 0)
    }
}
