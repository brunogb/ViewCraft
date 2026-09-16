import SwiftUI

public struct MorphingLayout<Content: View>: View {
    public var isStacked: Bool
    public var stacked: AnyLayout
    public var unstacked: AnyLayout
    @ViewBuilder public var content: Content

    public init(isStacked: Bool,
                stacked: AnyLayout = AnyLayout(ZStackLayout(alignment: .leading)),
                unstacked: AnyLayout = AnyLayout(VStackLayout(alignment: .leading, spacing: 15)),
                @ViewBuilder content: () -> Content) {
        self.isStacked = isStacked
        self.stacked = stacked
        self.unstacked = unstacked
        self.content = content()
    }

    public var body: some View {
        let layout = isStacked ? stacked : unstacked
        layout { content }
    }
}
