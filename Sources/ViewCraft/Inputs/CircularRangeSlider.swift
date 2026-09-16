import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public struct CircularRangeSliderConfig: Sendable, Equatable {
    public var startSymbol: String
    public var endSymbol: String
    public var selectionTint: Color
    public var trackTint: Color
    public var knobTint: Color
    public var knobSize: CGFloat
    public var knobInset: CGFloat
    public var diameter: CGFloat
    public var minimumSpacing: CGFloat
    public var tickTint: Color
    public var tickSpacing: CGFloat
    public var animation: Animation

    public init(startSymbol: String = "bed.double.fill",
                endSymbol: String = "alarm.fill",
                selectionTint: Color = CircularRangeSliderConfig.defaultSelectionTint,
                trackTint: Color = CircularRangeSliderConfig.defaultTrackTint,
                knobTint: Color = .gray,
                knobSize: CGFloat = 52,
                knobInset: CGFloat = 15,
                diameter: CGFloat = 320,
                minimumSpacing: CGFloat = 0.1,
                tickTint: Color = CircularRangeSliderConfig.defaultTrackTint,
                tickSpacing: CGFloat = 3,
                animation: Animation = .easeInOut(duration: 0.2)) {
        self.startSymbol = startSymbol
        self.endSymbol = endSymbol
        self.selectionTint = selectionTint
        self.trackTint = trackTint
        self.knobTint = knobTint
        self.knobSize = knobSize
        self.knobInset = knobInset
        self.diameter = diameter
        self.minimumSpacing = minimumSpacing
        self.tickTint = tickTint
        self.tickSpacing = tickSpacing
        self.animation = animation
    }

    public static let `default` = CircularRangeSliderConfig()

    public static var defaultSelectionTint: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGray5)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    public static var defaultTrackTint: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

public enum CircularRangeSliderMetrics {
    public static func progress(at location: CGPoint, center: CGPoint) -> CGFloat {
        let radians = atan2(location.y - center.y, location.x - center.x)
        var degrees = radians * 180 / .pi + 90
        degrees = degrees.truncatingRemainder(dividingBy: 360)
        if degrees < 0 { degrees += 360 }
        return CGFloat(degrees / 360)
    }

    public static func moving(_ isStart: Bool, to target: CGFloat,
                              start: CGFloat, end: CGFloat,
                              minimumSpacing: CGFloat) -> (start: CGFloat, end: CGFloat) {
        let current = isStart ? start : end
        let other = isStart ? end : start
        let diff = abs(target - other)
        let distance = min(diff, 1 - diff)

        guard distance >= minimumSpacing else {
            let delta = target - current
            return (wrapped(start + delta), wrapped(end + delta))
        }
        return isStart ? (target, end) : (start, target)
    }

    private static func wrapped(_ value: CGFloat) -> CGFloat {
        (value.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
    }
}

// A plain top-level constant, not a static property on CircularRangeSlider:
// static stored properties aren't allowed on a generic type.
private let circularRangeSliderSpace = "CircularRangeSlider"

public struct CircularRangeSlider<Label: View>: View {
    @Binding private var start: CGFloat
    @Binding private var end: CGFloat
    private let config: CircularRangeSliderConfig
    private let label: Label
    private let onInteractionChange: (_ isInteracting: Bool) -> Void

    @GestureState private var isInteracting = false

    public init(start: Binding<CGFloat>,
                end: Binding<CGFloat>,
                config: CircularRangeSliderConfig = .default,
                onInteractionChange: @escaping (_ isInteracting: Bool) -> Void = { _ in },
                @ViewBuilder label: () -> Label) {
        self._start = start
        self._end = end
        self.config = config
        self.onInteractionChange = onInteractionChange
        self.label = label()
    }

    public var body: some View {
        let center = CGPoint(x: config.diameter / 2, y: config.diameter / 2)

        ZStack {
            ring
            arcAndTicks(center: center)
            knob(isStart: true, center: center)
            knob(isStart: false, center: center)
        }
        .frame(width: config.diameter, height: config.diameter)
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 1)
        .coordinateSpace(.named(circularRangeSliderSpace))
        .onChange(of: isInteracting) { _, newValue in onInteractionChange(newValue) }
        .animation(config.animation, value: config.selectionTint)
    }

    private var ring: some View {
        let radius = (config.diameter - config.knobSize) / 2
        return Circle()
            .stroke(config.trackTint, lineWidth: config.knobSize)
            .frame(width: radius * 2, height: radius * 2)
            .overlay {
                label
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(.circle)
                    .padding(config.knobSize / 2)
            }
    }

    private func knob(isStart: Bool, center: CGPoint) -> some View {
        let progress = isStart ? start : end
        let radians = progress * 2 * .pi
        let radius = (config.diameter - config.knobSize) / 2
        let symbol = isStart ? config.startSymbol : config.endSymbol
        let knobDiameter = config.knobSize - config.knobInset

        return Image(systemName: symbol)
            .font(.system(size: knobDiameter / 2.5))
            .foregroundStyle(config.knobTint)
            .frame(width: knobDiameter, height: knobDiameter)
            .background(config.selectionTint, in: .circle)
            .contentShape(.circle)
            .position(x: center.x + radius * sin(radians), y: center.y - radius * cos(radians))
            .gesture(
                // Named, not .local: this knob's own position moves as the drag
                // updates start/end, and a .local gesture on a view that moves
                // itself oscillates, since the coordinate space would be chasing
                // the same value it's trying to read. Naming the fixed outer
                // frame keeps `location` measured against a `center` that never
                // moves instead.
                DragGesture(minimumDistance: 5, coordinateSpace: .named(circularRangeSliderSpace))
                    .updating($isInteracting) { _, out, _ in out = true }
                    .onChanged { value in
                        let target = CircularRangeSliderMetrics.progress(at: value.location, center: center)
                        let updated = CircularRangeSliderMetrics.moving(
                            isStart, to: target, start: start, end: end,
                            minimumSpacing: config.minimumSpacing)
                        start = updated.start
                        end = updated.end
                    }
            )
    }

    private func arcAndTicks(center: CGPoint) -> some View {
        Canvas { context, _ in
            let radius = (config.diameter - config.knobSize) / 2
            let lineWidth = config.knobSize - config.knobInset
            let tickCount = Int(config.diameter / config.tickSpacing)
            let tickWidth = config.knobSize / 4
            let tickHeight: CGFloat = 2

            // -90 throughout: addArc/rotate measure from 3 o'clock, this dial's
            // progress from 12.
            let arcPath = Path { path in
                path.addArc(center: center, radius: radius,
                           startAngle: .degrees(start * 360 - 90),
                           endAngle: .degrees(end * 360 - 90),
                           clockwise: false)
            }
            let strokedArc = arcPath.strokedPath(.init(lineWidth: lineWidth, lineCap: .round))

            var arcContext = context
            arcContext.fill(strokedArc, with: .color(config.selectionTint))
            // Ticks are drawn for the full circle and clipped to the arc here, so
            // only the highlighted span ends up showing any.
            arcContext.clip(to: strokedArc)

            for index in 0..<tickCount {
                var tickContext = arcContext
                let rotation = Double(index) / Double(tickCount) * 360 - 90
                tickContext.translateBy(x: center.x, y: center.y)
                tickContext.rotate(by: .degrees(rotation))

                let rect = CGRect(x: radius - tickWidth / 2, y: -tickHeight / 2,
                                  width: tickWidth, height: tickHeight)
                tickContext.fill(Path(roundedRect: rect, cornerRadius: tickHeight / 2),
                                 with: .color(config.tickTint))
            }
        }
        .frame(width: config.diameter, height: config.diameter)
        .allowsHitTesting(false)
    }
}

public extension CircularRangeSlider where Label == EmptyView {
    init(start: Binding<CGFloat>,
         end: Binding<CGFloat>,
         config: CircularRangeSliderConfig = .default,
         onInteractionChange: @escaping (_ isInteracting: Bool) -> Void = { _ in }) {
        self.init(start: start, end: end, config: config, onInteractionChange: onInteractionChange) {
            EmptyView()
        }
    }
}
