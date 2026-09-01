import SwiftUI

public final class SiriActivity: DynamicIslandActivity, ObservableObject {
    public let id: String = "activity.siri"
    public let type: ActivityType = .ai
    public let priority: ActivityPriority = .high
    public var timeoutDuration: TimeInterval? = 6.0
    
    public var title: String = "Siri"
    public var subtitle: String = "Listening..."
    public var iconName: String = "mic.fill"
    
    @Published public var text: String = "Listening..."
    
    public init() {}
    
    public var compactPreferredWidth: CGFloat { 44 }
    
    public var expandedPreferredSize: CGSize {
        CGSize(width: 200, height: 75)
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            SiriOrbView()
                .frame(width: 22, height: 22)
                .padding(.leading, 2)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(EmptyView())
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            HStack(spacing: 12) {
                SiriOrbView()
                    .frame(width: 44, height: 44)
                
                Text(text)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(0.8)
                Spacer()
            }
            .padding(.horizontal, 16)
        )
    }
    
    public var minimalBubbleView: AnyView {
        AnyView(
            SiriOrbView()
                .frame(width: 22, height: 22)
        )
    }
}

/// A vibrant, animated orb simulating the classic Apple Siri glowing orb.
public struct SiriOrbView: View {
    @State private var rotation: Double = 0.0
    @State private var scale: CGFloat = 1.0
    
    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    public var body: some View {
        ZStack {
            // Core Glow
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.2, green: 0.8, blue: 1.0), // Cyan
                            Color(red: 1.0, green: 0.1, blue: 0.5), // Pink
                            Color(red: 0.6, green: 0.1, blue: 1.0), // Purple
                            Color(red: 0.1, green: 0.3, blue: 1.0), // Deep Blue
                            Color(red: 0.2, green: 0.8, blue: 1.0)  // Cyan Wrap
                        ]),
                        center: .center,
                        angle: .degrees(rotation)
                    )
                )
                .blur(radius: 4)
                .scaleEffect(scale)
            
            // Inner Core
            Circle()
                .fill(Color.white.opacity(0.3))
                .scaleEffect(0.6)
                .blur(radius: 2)
                .scaleEffect(2.0 - scale)
        }
        .clipShape(Circle())
        .onReceive(timer) { _ in
            rotation += 3.0
            if rotation >= 360 {
                rotation -= 360
            }
            
            // Pulsing scale effect using sine wave
            let radians = rotation * .pi / 180.0
            scale = 1.0 + CGFloat(sin(radians * 2)) * 0.1
        }
    }
}
