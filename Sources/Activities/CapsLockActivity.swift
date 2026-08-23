import SwiftUI

/// Dynamic Island Activity representing real-time Caps Lock key toggling.
public final class CapsLockActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .capsLock
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 2.0
    
    @Published public var isOn: Bool
    
    public var title: String {
        isOn ? "Caps Lock ON" : "Caps Lock OFF"
    }
    
    public var subtitle: String {
        isOn ? "All-Caps Mode Active" : "Standard Input Mode"
    }
    
    public var iconName: String {
        "capslock.fill"
    }
    
    public var tintColor: Color {
        isOn ? Color(red: 0.20, green: 0.88, blue: 0.45) : Color.white.opacity(0.8)
    }
    
    public var compactPreferredWidth: CGFloat { 268 }
    public var expandedPreferredSize: CGSize { CGSize(width: 350, height: 110) }
    
    public init(id: String = "hud.capslock", isOn: Bool) {
        self.id = id
        self.isOn = isOn
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            CapsLockCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            CapsLockCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            CapsLockExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
}

public struct CapsLockCompactLeadingView: View {
    @ObservedObject public var activity: CapsLockActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Image(systemName: "capslock.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(activity.tintColor)
            .lineLimit(1)
            .fixedSize()
            .padding(.leading, 8)
            .matchedGeometryIfAvailable(id: "hud_caps_icon_\(activity.id)", in: namespace)
    }
}

public struct CapsLockCompactTrailingView: View {
    @ObservedObject public var activity: CapsLockActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Text(activity.isOn ? "On" : "Off")
            .font(.system(size: 12.5, weight: .bold, design: .rounded))
            .foregroundColor(activity.isOn ? Color(red: 0.20, green: 0.88, blue: 0.45) : .white.opacity(0.75))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing, 8)
            .matchedGeometryIfAvailable(id: "hud_caps_badge_\(activity.id)", in: namespace)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: activity.isOn)
    }
}

public struct CapsLockExpandedCardView: View {
    @ObservedObject public var activity: CapsLockActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 16) {
            // Key Icon with Glowing LED
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "capslock.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(activity.tintColor)
                
                if activity.isOn {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.88, blue: 0.45))
                        .frame(width: 5, height: 5)
                        .offset(y: 7)
                        .shadow(color: Color(red: 0.20, green: 0.88, blue: 0.45), radius: 5)
                }
            }
            .matchedGeometryIfAvailable(id: "hud_caps_icon_\(activity.id)", in: namespace)
            
            // Text Information
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.isOn ? "Caps Lock is ON" : "Caps Lock is OFF")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(activity.isOn ? .white : .white.opacity(0.85))
                
                Text(activity.isOn ? "ALL CAPITAL LETTERS ACTIVE" : "Standard lowercase typing active")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(activity.isOn ? Color(red: 0.20, green: 0.88, blue: 0.45) : .white.opacity(0.45))
            }
            
            Spacer()
            
            // Status Pill
            Text(activity.isOn ? "LOCKED" : "UNLOCKED")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundColor(activity.isOn ? Color(red: 0.20, green: 0.88, blue: 0.45) : .white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(activity.isOn ? Color(red: 0.20, green: 0.88, blue: 0.45).opacity(0.2) : Color.white.opacity(0.08))
                .clipShape(Capsule())
                .matchedGeometryIfAvailable(id: "hud_caps_badge_\(activity.id)", in: namespace)
        }
        .padding(.horizontal, 12)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: activity.isOn)
    }
}
