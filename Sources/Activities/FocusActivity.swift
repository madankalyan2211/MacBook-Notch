import SwiftUI

/// Activity representing macOS Focus Mode & Do Not Disturb state changes.
public final class FocusActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .custom
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 5.0
    
    @Published public var title: String
    @Published public var subtitle: String
    @Published public var iconName: String
    @Published public var tintColor: Color
    @Published public var isEnabled: Bool
    
    public var progress: Double? { nil }
    public var compactPreferredWidth: CGFloat { 268 }
    public var expandedPreferredSize: CGSize { CGSize(width: 350, height: 130) }
    
    public init(
        id: String = "activity.focus",
        name: String = "Do Not Disturb",
        iconName: String = "moon.fill",
        tintColor: Color = Color(red: 0.65, green: 0.45, blue: 0.98),
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = name
        self.subtitle = isEnabled ? "On" : "Off"
        self.iconName = "moon.fill"
        self.tintColor = Color(red: 0.65, green: 0.45, blue: 0.98)
        self.isEnabled = isEnabled
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            Image(systemName: "moon.fill")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(tintColor)
                .lineLimit(1)
                .fixedSize()
                .matchedGeometryIfAvailable(id: "focus_icon_\(id)", in: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            Text(isEnabled ? "On" : "Off")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(tintColor)
                .lineLimit(1)
                .fixedSize()
                .matchedGeometryIfAvailable(id: "focus_title_\(id)", in: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            FocusExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
    
    public var minimalBubbleView: AnyView {
        AnyView(
            Image(systemName: "moon.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tintColor)
        )
    }
}

public struct FocusExpandedCardView: View {
    @ObservedObject public var activity: FocusActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(activity.tintColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "moon.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(activity.tintColor)
            }
            .matchedGeometryIfAvailable(id: "focus_icon_\(activity.id)", in: namespace)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .matchedGeometryIfAvailable(id: "focus_title_\(activity.id)", in: namespace)
                
                Text(activity.isEnabled ? "Focus Enabled" : "Focus Disabled")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            // Focus Status Capsule
            Text(activity.isEnabled ? "ON" : "OFF")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(activity.isEnabled ? activity.tintColor : Color.white.opacity(0.18))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 8)
    }
}
