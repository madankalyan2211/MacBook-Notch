import SwiftUI

public final class VolumeActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .volume
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 2.5
    
    @Published public var title: String
    @Published public var subtitle: String
    @Published public var level: Double
    @Published public var isMuted: Bool
    
    public var isSilent: Bool {
        isMuted || level <= 0.001
    }
    
    public var iconName: String {
        if isSilent { return "bell.slash.fill" }
        if level < 0.33 { return "speaker.wave.1.fill" }
        if level < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
    
    public var tintColor: Color {
        isSilent ? Color(red: 1.0, green: 0.28, blue: 0.24) : .white
    }
    
    public var progress: Double? { isSilent ? 0 : level }
    
    public var compactPreferredWidth: CGFloat {
        isSilent ? 280 : 256
    }
    
    public var expandedPreferredSize: CGSize { CGSize(width: 350, height: 120) }
    
    public init(
        id: String = "hud.volume",
        level: Double = 0.65,
        isMuted: Bool = false
    ) {
        self.id = id
        self.level = level
        self.isMuted = isMuted
        self.title = isMuted || level <= 0.001 ? "Silent" : "Volume"
        self.subtitle = "\(Int(level * 100))%"
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            VolumeCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            VolumeCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            VolumeExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
}

public struct VolumeCompactLeadingView: View {
    @ObservedObject public var activity: VolumeActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Image(systemName: activity.iconName)
            .font(.system(size: 13.5, weight: .bold))
            .foregroundColor(activity.tintColor)
            .padding(.leading, activity.isSilent ? 7 : 1.5)
            .matchedGeometryIfAvailable(id: "hud_vol_icon_\(activity.id)", in: namespace)
    }
}

public struct VolumeCompactTrailingView: View {
    @ObservedObject public var activity: VolumeActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Group {
            if activity.isSilent {
                Text("Silent")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(activity.tintColor)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.trailing, 7)
                    .matchedGeometryIfAvailable(id: "hud_vol_ring_\(activity.id)", in: namespace)
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 2.8)
                    
                    Circle()
                        .trim(from: 0.0, to: CGFloat(max(0.01, min(1.0, activity.progress ?? 0))))
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 16, height: 16)
                .padding(.trailing, 2)
                .matchedGeometryIfAvailable(id: "hud_vol_ring_\(activity.id)", in: namespace)
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: activity.level)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: activity.isMuted)
    }
}

public struct VolumeExpandedCardView: View {
    @ObservedObject public var activity: VolumeActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: activity.iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(activity.tintColor)
                    .matchedGeometryIfAvailable(id: "hud_vol_icon_\(activity.id)", in: namespace)
                Text(activity.isSilent ? "Muted" : "Volume")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(activity.isSilent ? "0%" : "\(Int(activity.level * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(activity.tintColor)
            }
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 10)
                Capsule()
                    .fill(activity.tintColor)
                    .frame(width: max(10, 300 * CGFloat(activity.progress ?? 0)), height: 10)
            }
            .frame(height: 10)
            .matchedGeometryIfAvailable(id: "hud_vol_bar_\(activity.id)", in: namespace)
        }
        .padding(.horizontal, 8)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: activity.level)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: activity.isMuted)
    }
}
