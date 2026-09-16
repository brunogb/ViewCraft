import SwiftUI

public struct DynamicIslandToast: Identifiable, Sendable, Equatable {
    public let id: String
    public var symbol: String
    public var symbolColors: (foreground: Color, background: Color)
    public var title: String
    public var message: String

    public init(
        id: String = UUID().uuidString,
        symbol: String,
        symbolColors: (foreground: Color, background: Color),
        title: String,
        message: String
    ) {
        self.id = id
        self.symbol = symbol
        self.symbolColors = symbolColors
        self.title = title
        self.message = message
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    public static let success = DynamicIslandToast(
        symbol: "checkmark.seal.fill",
        symbolColors: (.white, .green),
        title: "Success",
        message: "Your action completed"
    )

    public static let failure = DynamicIslandToast(
        symbol: "xmark.seal.fill",
        symbolColors: (.white, .red),
        title: "Failed",
        message: "Something went wrong"
    )
}

#if os(iOS)
public extension View {
    func dynamicIslandToast(
        isPresented: Binding<Bool>,
        toast: DynamicIslandToast
    ) -> some View {
        topWindowOverlay(isPresented: isPresented, alignment: .top, hidesStatusBar: true) { isExpanded in
            DynamicIslandToastView(
                toast: toast,
                isExpanded: isExpanded,
                onDismiss: { isPresented.wrappedValue = false }
            )
        }
    }
}

struct DynamicIslandToastView: View {
    var toast: DynamicIslandToast
    var isExpanded: Bool
    var onDismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeArea = proxy.safeAreaInsets
            let size = proxy.size

            let haveDynamicIsland = DynamicIslandMetrics.isPresent(topSafeAreaInset: safeArea.top)
            let dynamicIslandWidth = DynamicIslandMetrics.size.width
            let dynamicIslandHeight = DynamicIslandMetrics.size.height
            let topOffset = DynamicIslandMetrics.topOffset(topSafeAreaInset: safeArea.top)

            let expandedWidth = size.width - 20
            let expandedHeight: CGFloat = haveDynamicIsland ? 90 : 70
            let scaleX: CGFloat = isExpanded ? 1 : (dynamicIslandWidth / expandedWidth)
            let scaleY: CGFloat = isExpanded ? 1 : (dynamicIslandHeight / expandedHeight)

            ZStack {
                islandShape
                    .fill(.black)
                    .overlay {
                        // Rendered at full expanded size and scaled down to the
                        // capsule, rather than re-laid-out at each size, so the
                        // text never reflows mid-morph.
                        toastContent(haveDynamicIsland: haveDynamicIsland)
                            .frame(width: expandedWidth, height: expandedHeight)
                            .scaleEffect(x: scaleX, y: scaleY)
                    }
                    .frame(
                        width: isExpanded ? expandedWidth : dynamicIslandWidth,
                        height: isExpanded ? expandedHeight : dynamicIslandHeight
                    )
                    .offset(
                        y: haveDynamicIsland ? topOffset : (isExpanded ? safeArea.top + 10 : -80)
                    )
                    .opacity(haveDynamicIsland ? 1 : (isExpanded ? 1 : 0))
                    .animation(.linear(duration: 0.02).delay(isExpanded ? 0 : 0.28)) { view in
                        view.opacity(haveDynamicIsland ? (isExpanded ? 1 : 0) : 1)
                    }
                    .geometryGroup()
                    .contentShape(.rect)
                    .gesture(
                        DragGesture().onEnded { value in
                            if value.translation.height < 0 { onDismiss() }
                        }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .animation(.bouncy(duration: 0.3, extraBounce: 0), value: isExpanded)
        }
    }

    private var islandShape: some Shape {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(30)), isUniform: true)
    }

    @ViewBuilder
    private func toastContent(haveDynamicIsland: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: toast.symbol)
                .font(.system(size: 30))
                .foregroundStyle(toast.symbolColors.foreground, toast.symbolColors.background)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                if haveDynamicIsland {
                    Spacer(minLength: 0)
                }

                Text(toast.title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(toast.message)
                    .font(.caption)
                    .foregroundStyle(.white.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, haveDynamicIsland ? 12 : 0)
            .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .compositingGroup()
        .blur(radius: isExpanded ? 0 : 5)
        .opacity(isExpanded ? 1 : 0)
    }
}
#endif
