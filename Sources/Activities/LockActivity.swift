import SwiftUI

/// Dynamic Island Activity representing macOS Lock / Unlock events.
public final class LockActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .lock
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval?
    
    @Published public var isLocked: Bool
    
    public var title: String {
        isLocked ? "MacBook Locked" : "MacBook Unlocked"
    }
    
    public var subtitle: String {
        isLocked ? "Touch ID or Password Required" : "Welcome Back"
    }
    
    public var iconName: String {
        isLocked ? "lock.fill" : "lock.open.fill"
    }
    
    public var tintColor: Color {
        isLocked ? Color(red: 1.0, green: 0.75, blue: 0.20) : Color(red: 0.30, green: 0.85, blue: 0.45)
    }
    
    public var progress: Double? { nil }
    
    public var compactPreferredWidth: CGFloat { 258 }
    public var expandedPreferredSize: CGSize { CGSize(width: 390, height: 120) }
    
    public init(id: String = "hud.lock", isLocked: Bool = false, timeout: TimeInterval? = 2.5) {
        self.id = id
        self.isLocked = isLocked
        self.timeoutDuration = timeout
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            LockCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            LockCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            LockExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
}

public struct LockCompactLeadingView: View {
    @ObservedObject public var activity: LockActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: activity.isLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(activity.tintColor)
                .matchedGeometryIfAvailable(id: "hud_lock_icon_\(activity.id)", in: namespace)
                .shadow(color: activity.tintColor.opacity(0.45), radius: 3)
        }
        .padding(.leading, 8)
    }
}

public struct LockCompactTrailingView: View {
    @ObservedObject public var activity: LockActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Text("Unlocked")
            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
            .foregroundColor(activity.tintColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing, 8)
            .matchedGeometryIfAvailable(id: "hud_lock_badge_\(activity.id)", in: namespace)
    }
}

public struct LockExpandedCardView: View {
    @ObservedObject public var activity: LockActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    @State private var isPulsing: Bool = false
    
    public var body: some View {
        HStack(spacing: 16) {
            // Lock Icon with glowing background circle
            ZStack {
                Circle()
                    .fill(activity.tintColor.opacity(0.18))
                    .frame(width: 48, height: 48)
                
                Image(systemName: activity.isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(activity.tintColor)
                    .scaleEffect(isPulsing ? 1.08 : 1.0)
                    .matchedGeometryIfAvailable(id: "hud_lock_icon_\(activity.id)", in: namespace)
            }
            .padding(.leading, 4)
            
            // Text Information
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(activity.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(activity.isLocked ? "Secure" : "Ready")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(activity.tintColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(activity.tintColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Text(activity.subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
