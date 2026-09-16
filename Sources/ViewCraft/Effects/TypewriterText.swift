import SwiftUI
#if os(iOS)
import CoreHaptics
#endif

public enum TypewriterMetrics {
    public static func steppedProgress(timeProgress: CGFloat, stepCount: Int, pause: CGFloat) -> CGFloat {
        guard stepCount > 0 else { return 0 }
        let count = CGFloat(stepCount)
        let index = floor(timeProgress * count)
        let stepProgress = (timeProgress * count) - index

        if stepProgress < pause {
            return index / count
        }

        return (index + (stepProgress - pause) / (1 - pause)) / count
    }
}

public struct TypewriterTextConfig: Sendable, Equatable {
    public var font: Font
    public var typingIndicatorSize: CGSize

    public var typingDuration: Double
    public var typingPauseIntensity: PauseIntensity

    public var dismissDuration: Double
    public var dismissPauseIntensity: PauseIntensity

    public var textWaitDelay: Double
    public var nextContentDelay: Double
    public var initialDelay: Double
    public var enableTextFading: Bool
    public var enableHaptics: Bool

    public init(font: Font = .system(size: 25, weight: .bold),
                typingIndicatorSize: CGSize = CGSize(width: 20, height: 2.5),
                typingDuration: Double = 0.8,
                typingPauseIntensity: PauseIntensity = .full,
                dismissDuration: Double = 0.4,
                dismissPauseIntensity: PauseIntensity = .none,
                textWaitDelay: Double = 1.1,
                nextContentDelay: Double = 0.4,
                initialDelay: Double = 0.8,
                enableTextFading: Bool = false,
                enableHaptics: Bool = true) {
        self.font = font
        self.typingIndicatorSize = typingIndicatorSize
        self.typingDuration = typingDuration
        self.typingPauseIntensity = typingPauseIntensity
        self.dismissDuration = dismissDuration
        self.dismissPauseIntensity = dismissPauseIntensity
        self.textWaitDelay = textWaitDelay
        self.nextContentDelay = nextContentDelay
        self.initialDelay = initialDelay
        self.enableTextFading = enableTextFading
        self.enableHaptics = enableHaptics
    }

    public static let `default` = TypewriterTextConfig()

    public enum PauseIntensity: CGFloat, Sendable, Equatable, CaseIterable {
        case none = 0.0
        case small = 0.15
        case medium = 0.5
        case large = 0.85
        case full = 1.0
    }
}

public struct TypewriterText: View {
    public let texts: [String]
    public let config: TypewriterTextConfig

    @State private var startDate: Date?
    @State private var progress: CGFloat = 0
    #if os(iOS)
    @State private var hapticsManager = HapticsManager()
    #endif
    @Environment(\.scenePhase) private var scenePhase

    public init(texts: [String], config: TypewriterTextConfig = .default) {
        self.texts = texts
        self.config = config
    }

    public var body: some View {
        ZStack {
            if let startDate {
                let duration = config.typingDuration + config.textWaitDelay
                    + config.dismissDuration + config.nextContentDelay

                TimelineView(.periodic(from: startDate, by: duration)) { context in
                    let index = Int((startDate.distance(to: context.date) / duration).rounded()) % texts.count
                    let text = texts[index]

                    HStack(alignment: .bottom, spacing: 0) {
                        Text(text)
                            .font(config.font)
                            .textRenderer(TypingTextRenderer(
                                fadeEffect: config.enableTextFading,
                                progress: progress
                            ))
                            // Keeps the text's trailing edge pinned to the cursor as it
                            // grows, instead of typing away from a fixed left edge.
                            .visualEffect { [progress] content, proxy in
                                content.offset(x: proxy.size.width * (1 - progress))
                            }

                        TypingIndicator(size: config.typingIndicatorSize)
                    }
                    // Re-centers the whole (text + cursor) pair as the text grows, so an
                    // empty line starts as a lone centered cursor rather than one stuck
                    // at the left edge.
                    .visualEffect { [config, progress] content, proxy in
                        let offset = (proxy.size.width - config.typingIndicatorSize.width) / 2
                        return content.offset(x: -offset * (1 - progress))
                    }
                    .onChange(of: text, initial: true) { _, newValue in
                        animateText(for: newValue)
                    }
                }
            } else {
                HStack(alignment: .bottom, spacing: 0) {
                    Text(" ").font(config.font).frame(width: 0)
                    TypingIndicator(size: config.typingIndicatorSize)
                }
            }
        }
        .lineLimit(1)
        .onChange(of: scenePhase, initial: true) { _, newValue in
            #if os(iOS)
            if config.enableHaptics {
                if newValue == .active {
                    hapticsManager.prepareEngine()
                } else {
                    hapticsManager.stopEngine()
                }
            }
            #endif

            Task {
                if newValue == .background {
                    startDate = nil
                } else {
                    guard startDate == nil else { return }
                    try? await Task.sleep(for: .seconds(config.initialDelay))
                    startDate = .now
                }
            }
        }
    }

    private func animateText(for text: String) {
        Task {
            playHaptics(text: text, forDismiss: false)
            withAnimation(Animation(TypingAnimation(
                characterCount: text.count,
                pauseIntensity: config.typingPauseIntensity,
                duration: config.typingDuration
            ))) {
                progress = 1
            }

            try? await Task.sleep(for: .seconds(config.typingDuration + config.textWaitDelay))

            playHaptics(text: text, forDismiss: true)
            withAnimation(Animation(TypingAnimation(
                characterCount: text.count,
                pauseIntensity: config.dismissPauseIntensity,
                duration: config.dismissDuration
            ))) {
                progress = 0
            }
            // No manual wait for nextContentDelay: it's already folded into the
            // timeline's own period.
        }
    }

    private func playHaptics(text: String, forDismiss: Bool) {
        #if os(iOS)
        guard config.enableHaptics, scenePhase == .active else { return }
        do {
            let duration = forDismiss ? config.dismissDuration : config.typingDuration
            try hapticsManager.playHaptics(text: text, duration: duration, forDismiss: forDismiss)
        } catch {
            print(error.localizedDescription)
        }
        #endif
    }
}

private struct TypingIndicator: View {
    var size: CGSize
    var duration: CGFloat = 0.5
    var delay: CGFloat = 0.1

    var body: some View {
        Rectangle()
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: CGFloat.zero, repeating: true) { content, opacity in
                content.opacity(opacity)
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(1, duration: duration / 2)
                LinearKeyframe(1, duration: delay)
                LinearKeyframe(0, duration: duration / 2)
            }
    }
}

@Animatable
private struct TypingTextRenderer: TextRenderer {
    @AnimatableIgnored var fadeEffect: Bool
    var progress: CGFloat

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let slices = layout.flatMap { $0 }.flatMap { $0 }

        for (index, slice) in slices.enumerated() {
            var sliceContext = context
            let sliceProgress = progress.windowedProgress(index: index, count: slices.count)

            sliceContext.opacity = fadeEffect ? sliceProgress : sliceProgress.rounded()
            sliceContext.draw(slice)
        }
    }
}

private struct TypingAnimation: CustomAnimation {
    var characterCount: Int
    var pauseIntensity: TypewriterTextConfig.PauseIntensity
    var duration: TimeInterval

    nonisolated func animate<V>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V: VectorArithmetic {
        guard time <= duration else { return nil }

        let timeProgress = time / duration
        let newValue = TypewriterMetrics.steppedProgress(
            timeProgress: timeProgress, stepCount: characterCount, pause: pauseIntensity.rawValue
        )
        return value.scaled(by: newValue)
    }
}

#if os(iOS)
@Observable
@MainActor
private class HapticsManager {
    var engine: CHHapticEngine?

    func prepareEngine() {
        #if !targetEnvironment(simulator)
        guard engine == nil else { return }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print(error.localizedDescription)
        }
        #endif
    }

    func stopEngine() {
        #if !targetEnvironment(simulator)
        guard let engine else { return }

        Task {
            do {
                try await engine.stop()
                self.engine = nil
            } catch {
                print(error.localizedDescription)
            }
        }
        #endif
    }

    func playHaptics(text: String, duration: CGFloat, forDismiss: Bool) throws {
        guard let engine else { return }

        let indices = 0..<text.count
        let delay = duration / CGFloat(indices.count)

        let events: [CHHapticEvent]
        if forDismiss {
            events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2)
                ], relativeTime: 0, duration: duration)
            ]
        } else {
            events = indices.map { index in
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4)
                ], relativeTime: CGFloat(index) * delay)
            }
        }

        let pattern = try CHHapticPattern(events: events, parameters: [])
        let player = try engine.makePlayer(with: pattern)
        try player.start(atTime: CHHapticTimeImmediate)
    }
}
#endif
