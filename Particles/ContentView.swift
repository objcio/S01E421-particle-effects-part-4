//

import SwiftUI

extension Animatable {
    static func *(lhs: Self, rhs: Double) -> Self {
        var copy = lhs
        copy.animatableData.scale(by: rhs)
        return copy
    }
}

struct KeyframeModifier: ViewModifier, Animatable {
    var progress: Double // 0...1
    var endOffset: CGSize

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    struct Value {
        var offset: CGSize
        var opacity: CGFloat
        var angle: Angle = .zero
    }
    func body(content: Content) -> some View {
        let timeline = KeyframeTimeline(initialValue: Value(offset: .zero, opacity: 0)) {
            KeyframeTrack(\.offset) {
                CubicKeyframe(endOffset * 0.5, duration: 0.3)
                CubicKeyframe(endOffset * 0.2, duration: 0.2)
                CubicKeyframe(endOffset, duration: 0.5)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(1, duration: 0.2)
                CubicKeyframe(0, duration: 0.8)
            }
            KeyframeTrack(\.angle) {
                CubicKeyframe(.degrees(360), duration: 0.7)
            }
        }
        let value = timeline.value(progress: progress)
        content
            .rotationEffect(value.angle)
            .offset(value.offset)
            .opacity(value.opacity)
    }
}

extension AnyTransition {
    static func keyframe(offset: CGSize) -> AnyTransition {
        modifier(active: KeyframeModifier(progress: 1, endOffset: offset), identity: KeyframeModifier(progress: 0, endOffset: offset))
    }
}

struct ParticleModifier<T: Hashable>: ViewModifier {
    var trigger: T

    @State var angle = Angle.degrees(.random(in: 0...360))

    @State var distance: Double = .random(in: 10...50)
    var offset: CGSize {
        .init(width: cos(angle.radians) * distance, height: sin(angle.radians) * distance)
    }

    var t: AnyTransition {
        .asymmetric(insertion: .identity, removal: .keyframe(offset: offset))
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .transition(t)
                .id(trigger)
        }
        .animation(.default.speed(0.1), value: trigger)
        .onChange(of: trigger) {
            angle = Angle.degrees(.random(in: 0...360))
        }
    }
}

struct SprayParticle {
    var endOffset: CGSize

    init() {
        let angle = Angle.degrees(.random(in: 0..<360))
        let length = Double.random(in: 25..<100)
        endOffset = CGSize(width: cos(angle.radians) * length, height: sin(angle.radians) * length)
    }

    struct Value {
        var offset: CGSize
        var opacity: CGFloat
        var angle: Angle = .zero
    }

    func value(at progress: Double) -> Value {
        let timeline = KeyframeTimeline(initialValue: Value(offset: .zero, opacity: 0)) {
            KeyframeTrack(\.offset) {
//                CubicKeyframe(endOffset * 0.5, duration: 0.3)
//                CubicKeyframe(endOffset * 0.2, duration: 0.2)
                CubicKeyframe(endOffset, duration: 1)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(1, duration: 0.2)
                CubicKeyframe(0, duration: 0.8)
            }
            KeyframeTrack(\.angle) {
                CubicKeyframe(.zero, duration: 0.7)
                CubicKeyframe(.degrees(45), duration: 0.3)
            }
        }
        return timeline.value(progress: progress)
    }

    func draw(symbol: GraphicsContext.ResolvedSymbol, in context: inout GraphicsContext, progress: Double) {
        let value = self.value(at: progress)
        context.opacity = value.opacity
        context.translateBy(x: value.offset.width, y: value.offset.height)
        context.rotate(by: value.angle)
        context.draw(symbol, at: .zero)
    }
}

struct SprayEffect<T: Equatable>: ViewModifier {
    var trigger: T
    var numberOfParticles = 30
    var duration: TimeInterval = 1.5
    @State private var triggerDate: Date? = nil
    @State private var particles: [(particle: SprayParticle, startTime: Date)] = []

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: triggerDate == nil)) { timelineCtx in
            Canvas { context, size in
                let symbol = context.resolveSymbol(id: "particle")!
                context.translateBy(x: size.width/2, y: size.height/2)

                for (particle, particleStart) in particles {
                    guard timelineCtx.date >= particleStart else { continue }
                    let diff = timelineCtx.date.timeIntervalSince(particleStart)
                    let progress = diff/duration
                    guard progress < 1 else { continue }
                    var copy = context
                    particle.draw(symbol: symbol, in: &copy, progress: progress)
                }
            } symbols: {
                content.tag("particle")
            }
            .frame(width: 200, height: 200)
        }
        .onChange(of: trigger) {
            triggerDate = .now
            particles = (0..<numberOfParticles).map { _ in
                (particle: .init(), startTime: .now.addingTimeInterval(.random(in: 0..<1)))
            }
        }
    }
}

extension View {
    func sprayEffect<Trigger: Hashable>(trigger: Trigger) -> some View {
        self.background {
            self.modifier(SprayEffect(trigger: trigger))
        }
    }
}

struct ContentView: View {
    @ScaledMetric var dividerHeight = 18
    @State private var trigger = 0
    var body: some View {
        VStack {
            Button(action: {
                trigger += 1
            }, label: {
                HStack {
                    Image(systemName: "star.fill")
                        .sprayEffect(trigger: trigger)
                    Divider()
                        .frame(height: dividerHeight)
                    Text("Favorite")
                }
                .contentShape(.rect)
            })
        }
        .buttonStyle(.link)
        .padding()
    }
}

#Preview {
    ContentView()
        .padding(50)
}
