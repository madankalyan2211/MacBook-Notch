import SwiftUI

public final class BrightnessActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .brightness
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 2.5
    
    @Published public var title: String
    @Published public var subtitle: String
    @Published public var level: Double
    
    public var iconName: String {
        if level <= 0.4 {
            return "sun.min.fill"
        } else {
            return "sun.max.fill"
        }
    }
    
    public var tintColor: Color { .white }
    public var progress: Double? { level }
    
    public var compactPreferredWidth: CGFloat { 256 }
    public var expandedPreferredSize: CGSize { CGSize(width: 350, height: 120) }
    
    public init(
        id: String = "hud.brightness",
        level: Double = 0.7
    ) {
        self.id = id
        self.level = level
        self.title = "Brightness"
        self.subtitle = "\(Int(level * 100))%"
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            BrightnessCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            BrightnessCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            BrightnessExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
}

public struct BrightnessCompactLeadingView: View {
    @ObservedObject public var activity: BrightnessActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Image(systemName: activity.iconName)
            .font(.system(size: 13.5, weight: .bold))
            .foregroundColor(.white)
            .padding(.leading, 5)
            .matchedGeometryIfAvailable(id: "hud_bri_icon_\(activity.id)", in: namespace)
    }
}

public struct BrightnessCompactTrailingView: View {
    @ObservedObject public var activity: BrightnessActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 2.8)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(max(0.01, min(1.0, activity.level))))
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 16, height: 16)
        .padding(.trailing, 5)
        .matchedGeometryIfAvailable(id: "hud_bri_ring_\(activity.id)", in: namespace)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: activity.level)
    }
}

public struct BrightnessExpandedCardView: View {
    @ObservedObject public var activity: BrightnessActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: activity.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .matchedGeometryIfAvailable(id: "hud_bri_icon_\(activity.id)", in: namespace)
                Text("Display Brightness")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(activity.level * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 10)
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(10, 300 * CGFloat(activity.level)), height: 10)
            }
            .frame(height: 10)
            .matchedGeometryIfAvailable(id: "hud_bri_bar_\(activity.id)", in: namespace)
        }
        .padding(.horizontal, 8)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: activity.level)
    }
}

