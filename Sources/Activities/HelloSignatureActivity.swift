import SwiftUI
import AppKit

/// Dynamic Island Activity representing Apple's iconic cursive "hello" signature welcome greeting.
public final class HelloSignatureActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .custom
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 4.5
    
    public var title: String { "hello" }
    public var subtitle: String { "Welcome to Dynamic Island" }
    public var iconName: String { "sparkles" }
    public var tintColor: Color { Color(red: 0.95, green: 0.45, blue: 0.75) }
    public var progress: Double? { nil }
    
    public var compactPreferredWidth: CGFloat { 282 }
    public var expandedPreferredSize: CGSize { CGSize(width: 390, height: 165) }
    
    public init(id: String = "activity.hello") {
        self.id = id
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.4, blue: 0.6), Color(red: 0.6, green: 0.4, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .matchedGeometryIfAvailable(id: "hello_icon_\(id)", in: namespace)
                
                Text("hello")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundColor(.white)
            }
            .padding(.leading, 6)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            Text("MacBook Notch")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .padding(.trailing, 8)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            HelloSignatureExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
}

/// Expanded Card with animated cursive "hello" stroke drawing, rainbow sheen, and sparkles
public struct HelloSignatureExpandedCardView: View {
    @ObservedObject public var activity: HelloSignatureActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    @State private var strokeProgress: CGFloat = 0.0
    @State private var gradientOffset: CGFloat = -1.0
    @State private var subtitleOpacity: Double = 0.0
    @State private var buttonScale: CGFloat = 0.8
    @State private var sparklesActive: Bool = false
    
    // Apple Vintage / Modern Gradient Colors
    private let rainbowColors: [Color] = [
        Color(red: 1.0, green: 0.35, blue: 0.45),  // Coral / Red
        Color(red: 1.0, green: 0.65, blue: 0.20),  // Orange / Gold
        Color(red: 0.30, green: 0.85, blue: 0.45),  // Mint / Green
        Color(red: 0.25, green: 0.65, blue: 1.00),  // Sky / Cyan
        Color(red: 0.70, green: 0.40, blue: 0.95),  // Purple / Violet
        Color(red: 1.0, green: 0.35, blue: 0.75)   // Pink / Magenta
    ]
    
    public var body: some View {
        VStack(spacing: 8) {
            // Header Sparkle & Title
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text("MacBook Notch")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.3))
                        .scaleEffect(sparklesActive ? 1.2 : 0.85)
                        .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: sparklesActive)
                    
                    Text("Welcome")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.3))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2.5)
                .background(Color(red: 1.0, green: 0.8, blue: 0.3).opacity(0.15))
                .clipShape(Capsule())
            }
            
            // Iconic Animated Cursive "hello" Signature
            ZStack {
                // Background Soft Glowing Aura
                HelloCursiveShape()
                    .stroke(
                        LinearGradient(
                            colors: rainbowColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 8)
                    .opacity(0.55 * strokeProgress)
                
                // Animated Drawing Stroke
                HelloCursiveShape()
                    .trim(from: 0.0, to: strokeProgress)
                    .stroke(
                        LinearGradient(
                            colors: rainbowColors,
                            startPoint: UnitPoint(x: gradientOffset, y: 0),
                            endPoint: UnitPoint(x: gradientOffset + 1.2, y: 1)
                        ),
                        style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.white.opacity(0.4), radius: 3)
            }
            .frame(height: 52)
            .padding(.horizontal, 10)
            
            // Subtitle & Action Button (Persists until user clicks Enjoy)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Your dynamic workspace is ready.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text("Music, Calls, Voice Memos & Clipboard live in your notch")
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .opacity(subtitleOpacity)
                
                Spacer()
                
                Button(action: {
                    controller.activityManager.removeActivity(id: activity.id)
                    if controller.activeActivity != nil {
                        controller.transition(to: .compact)
                    } else {
                        controller.transition(to: .idle)
                    }
                }) {
                    HStack(spacing: 5) {
                        Text("Enjoy")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6.5)
                    .background(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.white.opacity(0.25), radius: 5, y: 1)
                }
                .buttonStyle(.plain)
                .scaleEffect(buttonScale)
                .opacity(subtitleOpacity)
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            // 1. Draw out the cursive stroke smoothly over 1.8s
            withAnimation(.easeInOut(duration: 1.8)) {
                strokeProgress = 1.0
            }
            
            // 2. Animate the gradient shimmer across the word
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                gradientOffset = 1.0
            }
            
            // 3. Fade in subtitle and button
            withAnimation(.easeOut(duration: 0.6).delay(1.2)) {
                subtitleOpacity = 1.0
                buttonScale = 1.0
                sparklesActive = true
            }
        }
    }
}

/// Custom Vector Path tracing out the iconic cursive "hello" signature
public struct HelloCursiveShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let scaleX = rect.width / 240.0
        let scaleY = rect.height / 50.0
        
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }
        
        // --- 'h' ---
        path.move(to: pt(10, 38))
        path.addCurve(to: pt(28, 6), control1: pt(14, 25), control2: pt(22, 10))
        path.addCurve(to: pt(26, 42), control1: pt(32, 2), control2: pt(26, 28))
        path.addCurve(to: pt(46, 26), control1: pt(26, 30), control2: pt(36, 22))
        path.addCurve(to: pt(52, 42), control1: pt(50, 30), control2: pt(52, 38))
        
        // --- 'e' ---
        path.addCurve(to: pt(76, 26), control1: pt(56, 38), control2: pt(68, 28))
        path.addCurve(to: pt(72, 42), control1: pt(82, 24), control2: pt(80, 42))
        path.addCurve(to: pt(92, 34), control1: pt(65, 42), control2: pt(86, 36))
        
        // --- 'l' (first) ---
        path.addCurve(to: pt(112, 4), control1: pt(96, 32), control2: pt(106, 12))
        path.addCurve(to: pt(116, 42), control1: pt(116, -1), control2: pt(114, 28))
        
        // --- 'l' (second) ---
        path.addCurve(to: pt(138, 4), control1: pt(122, 36), control2: pt(132, 12))
        path.addCurve(to: pt(142, 42), control1: pt(142, -1), control2: pt(140, 28))
        
        // --- 'o' ---
        path.addCurve(to: pt(168, 25), control1: pt(148, 38), control2: pt(158, 24))
        path.addCurve(to: pt(186, 34), control1: pt(178, 24), control2: pt(186, 28))
        path.addCurve(to: pt(168, 43), control1: pt(186, 40), control2: pt(176, 44))
        path.addCurve(to: pt(166, 26), control1: pt(160, 42), control2: pt(160, 28))
        path.addCurve(to: pt(205, 24), control1: pt(176, 24), control2: pt(192, 22))
        
        // --- signature swirl / flourish ---
        path.addCurve(to: pt(230, 28), control1: pt(212, 25), control2: pt(222, 26))
        
        return path
    }
}
