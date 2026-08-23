import SwiftUI

/// Dynamic Island Activity representing Caffeine / Keep-Awake state with duration presets and interactive controls.
public final class CaffeineActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .caffeine
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 4.0
    
    @Published public var isActive: Bool
    @Published public var remainingSeconds: TimeInterval?
    @Published public var labelText: String
    
    public var title: String {
        isActive ? "Caffeine Active" : "Caffeine Inactive"
    }
    
    public var subtitle: String {
        isActive ? labelText : "Standard Sleep Mode"
    }
    
    public var iconName: String {
        isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
    }
    
    public var tintColor: Color {
        isActive ? Color(red: 1.0, green: 0.62, blue: 0.20) : Color.white.opacity(0.6)
    }
    
    public var progress: Double? { nil }
    
    public var compactPreferredWidth: CGFloat {
        if remainingSeconds != nil {
            return 310
        } else {
            return 295
        }
    }
    public var expandedPreferredSize: CGSize { CGSize(width: 380, height: 140) }
    
    public init(
        id: String = "activity.caffeine",
        isActive: Bool = true,
        remainingSeconds: TimeInterval? = nil,
        labelText: String = "Indefinite Keep-Awake",
        timeout: TimeInterval? = 4.0
    ) {
        self.id = id
        self.isActive = isActive
        self.remainingSeconds = remainingSeconds
        self.labelText = labelText
        self.timeoutDuration = timeout
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            CaffeineCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            CaffeineCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            CaffeineExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
}

public struct CaffeineCompactLeadingView: View {
    @ObservedObject public var activity: CaffeineActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: activity.iconName)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(activity.tintColor)
                .matchedGeometryIfAvailable(id: "hud_caffeine_icon_\(activity.id)", in: namespace)
                .shadow(color: activity.tintColor.opacity(activity.isActive ? 0.5 : 0), radius: 3)
        }
        .padding(.leading, 8)
    }
}

public struct CaffeineCompactTrailingView: View {
    @ObservedObject public var activity: CaffeineActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(activity.tintColor)
                .frame(width: 5, height: 5)
            
            Text(activity.isActive ? (activity.remainingSeconds != nil ? formattedTime(activity.remainingSeconds!) : "Awake") : "Off")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(activity.tintColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.trailing, 8)
        .matchedGeometryIfAvailable(id: "hud_caffeine_badge_\(activity.id)", in: namespace)
    }
    
    private func formattedTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let hrs = mins / 60
        if hrs > 0 {
            return "\(hrs)h \(mins % 60)m"
        }
        return "\(mins)m"
    }
}

public struct CaffeineExpandedCardView: View {
    @ObservedObject public var activity: CaffeineActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    @State private var steamOffset: CGFloat = 0.0
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Glowing Coffee Icon
                ZStack {
                    Circle()
                        .fill(activity.tintColor.opacity(activity.isActive ? 0.20 : 0.08))
                        .frame(width: 46, height: 46)
                    
                    Image(systemName: activity.iconName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(activity.tintColor)
                        .matchedGeometryIfAvailable(id: "hud_caffeine_icon_\(activity.id)", in: namespace)
                }
                .padding(.leading, 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Caffeine (Keep Awake)")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(activity.isActive ? "Active" : "Disabled")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(activity.tintColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(activity.tintColor.opacity(0.16))
                            .clipShape(Capsule())
                    }
                    
                    Text(activity.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }
                
                Spacer()
                
                // Toggle Button
                Button(action: {
                    CaffeineService.shared.toggle()
                }) {
                    Text(activity.isActive ? "Sleep" : "Awake")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5.5)
                        .background(activity.isActive ? Color(red: 1.0, green: 0.62, blue: 0.20) : Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            
            // Preset Duration Buttons
            HStack(spacing: 6) {
                PresetButton(title: "15m", seconds: 15 * 60, currentSeconds: activity.remainingSeconds, isActive: activity.isActive)
                PresetButton(title: "30m", seconds: 30 * 60, currentSeconds: activity.remainingSeconds, isActive: activity.isActive)
                PresetButton(title: "1 Hour", seconds: 60 * 60, currentSeconds: activity.remainingSeconds, isActive: activity.isActive)
                PresetButton(title: "2 Hours", seconds: 120 * 60, currentSeconds: activity.remainingSeconds, isActive: activity.isActive)
                PresetButton(title: "∞ Indefinite", seconds: nil, currentSeconds: activity.remainingSeconds, isActive: activity.isActive)
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 6)
    }
}

private struct PresetButton: View {
    let title: String
    let seconds: TimeInterval?
    let currentSeconds: TimeInterval?
    let isActive: Bool
    
    private var isSelected: Bool {
        if !isActive { return false }
        if seconds == nil && currentSeconds == nil { return true }
        if let s = seconds, let c = currentSeconds {
            return abs(s - c) <= 3.0
        }
        return false
    }
    
    var body: some View {
        Button(action: {
            CaffeineService.shared.activate(duration: seconds)
        }) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(
                    isSelected
                    ? Color(red: 1.0, green: 0.62, blue: 0.20)
                    : Color.white.opacity(0.12)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
