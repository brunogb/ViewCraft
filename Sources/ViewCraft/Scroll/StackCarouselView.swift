import SwiftUI

public struct StackCarouselConfig: Sendable, Equatable {
    public var minimizedItemSize: CGSize
    public var expandedItemSize: CGSize
    public var expandAnimation: Animation
    public var collapseAnimation: Animation
    public var revealDelay: Duration

    public init(minimizedItemSize: CGSize = CGSize(width: 81, height: 176),
                expandedItemSize: CGSize = CGSize(width: 111, height: 241),
                expandAnimation: Animation = .interpolatingSpring(duration: 0.35, bounce: 0, initialVelocity: 0),
                collapseAnimation: Animation = .easeInOut(duration: 0.25),
                revealDelay: Duration = .milliseconds(320)) {
        self.minimizedItemSize = minimizedItemSize
        self.expandedItemSize = expandedItemSize
        self.expandAnimation = expandAnimation
        self.collapseAnimation = collapseAnimation
        self.revealDelay = revealDelay
    }

    public static let `default` = StackCarouselConfig()
}

public struct StackCarouselView<Content: View, Action: View>: View {
    public var title: String
    public var description: String
    public var config: StackCarouselConfig
    @ViewBuilder public var content: Content
    @ViewBuilder public var action: (_ isExpanded: Bool, _ toggle: @escaping () -> Void) -> Action

    @State private var isExpanded = false
    @State private var isRevealed = false
    @State private var isRemoved = false
    @State private var expandedContentHeight: CGFloat = 0
    @State private var settleTask: Task<Void, Never>?

    public init(title: String,
                description: String,
                config: StackCarouselConfig = .default,
                @ViewBuilder content: () -> Content,
                @ViewBuilder action: @escaping (_ isExpanded: Bool, _ toggle: @escaping () -> Void) -> Action) {
        self.title = title
        self.description = description
        self.config = config
        self.content = content()
        self.action = action
    }

    public var body: some View {
        MorphingLayout(isStacked: !isExpanded) {
            if !isRemoved {
                header
                carousel
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { newValue in
            if !isRemoved { expandedContentHeight = newValue }
        }
        .frame(minHeight: isRemoved ? expandedContentHeight : config.minimizedItemSize.height)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.title.bold()).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.trailing, isExpanded ? 50 : 0)
            .overlay(alignment: .trailing) {
                if isExpanded { action(isExpanded, toggle) }
            }

            Text(description)
                .lineLimit(isExpanded ? 2 : 3)
                .transition(.blurReplace)
                .font(.callout)
                .foregroundStyle(.secondary)

            if !isExpanded {
                action(isExpanded, toggle)
                    .transition(.identity)
            }
        }
        .padding(.leading, isExpanded ? 0 : (config.minimizedItemSize.width + 40))
        .transition(.blurReplace.combined(with: .move(edge: isExpanded ? .trailing : .leading)))
    }

    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 18) {
                Group(subviews: content) { collection in
                    let visible = Array(collection.prefix(isExpanded ? collection.count : 3).enumerated())
                    ForEach(visible, id: \.element.id) { index, subview in
                        subview
                            .frame(width: itemSize.width, height: itemSize.height)
                            .stackedCardReveal(index: index, isExpanded: isExpanded, isRevealed: isRevealed)
                    }
                }
            }
        }
        .frame(height: itemSize.height)
        .allowsHitTesting(isRevealed)
        .transition(.blurReplace.combined(with: .move(edge: isExpanded ? .trailing : .leading)))
    }

    private var itemSize: CGSize { isExpanded ? config.expandedItemSize : config.minimizedItemSize }

    private func toggle() {
        settleTask?.cancel()
        settleTask = nil

        if !isExpanded {
            withAnimation(config.expandAnimation) {
                isRemoved = false
                isExpanded = true
            }
            settleTask = Task {
                try? await Task.sleep(for: config.revealDelay)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.22)) { isRevealed = true }
            }
        } else {
            withAnimation(config.collapseAnimation) { isRemoved = true }
            settleTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                isExpanded = false
                isRevealed = false
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.25)) { isRemoved = false }
            }
        }
    }
}
