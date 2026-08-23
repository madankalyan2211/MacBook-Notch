import SwiftUI

/// Dynamic Island Activity representing MacBook Battery state (Charging, Normal, and Low Battery Warning).
public final class BatteryActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .battery
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 4.5
    
    @Published public var percentage: Int
    @Published public var isCharging: Bool
    
    public var isLowBattery: Bool {
        percentage <= 20 && !isCharging
    }
    
    public var isCritical: Bool {
        percentage <= 10 && !isCharging
    }
    
    public var title: String {
        if isCharging {
            return "Charging"
        } else if isCritical {
            return "Critical Battery"
        } else if isLowBattery {
            return "Low Battery"
        } else {
            return "Battery"
        }
    }
    
    public var subtitle: String {
        if isCharging {
            return "\(percentage)% • MagSafe Connected"
        } else if isLowBattery {
            return "\(percentage)% remaining • Connect Charger"
        } else {
            return "\(percentage)% remaining"
        }
    }
    
    public var iconName: String {
        if isCharging {
            return "bolt.fill"
        } else if isCritical {
            return "battery.0percent"
        } else if percentage <= 20 {
            return "battery.25percent"
        } else if percentage <= 50 {
            return "battery.50percent"
        } else if percentage <= 75 {
            return "battery.75percent"
        } else {
            return "battery.100percent"
        }
    }
    
    public var tintColor: Color {
        if isCharging {
            return Color(red: 0.25, green: 0.95, blue: 0.45)
        } else if isCritical {
            return Color(red: 1.0, green: 0.28, blue: 0.25)
        } else if isLowBattery {
            return Color(red: 1.0, green: 0.62, blue: 0.18)
        } else {
            return .white
        }
    }
    
    public var progress: Double? { Double(percentage) / 100.0 }
    
    public var compactPreferredWidth: CGFloat {
        if isLowBattery || isCritical {
            return 370
        } else {
            return 340
        }
    }
    
    public var expandedPreferredSize: CGSize {
        CGSize(width: 370, height: 130)
    }
    
    public init(
        id: String = "hud.battery",
        percentage: Int = 85,
        isCharging: Bool = true
    ) {
        self.id = id
        self.percentage = percentage
        self.isCharging = isCharging
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            BatteryCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            BatteryCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            BatteryExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
}

public struct BatteryCompactLeadingView: View {
    @ObservedObject public var activity: BatteryActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Text(activity.isLowBattery ? "Low Battery" : (activity.isCritical ? "Critical" : "Charging"))
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(activity.isLowBattery || activity.isCritical ? activity.tintColor : .white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.leading, 8)
            .matchedGeometryIfAvailable(id: "hud_bat_title_\(activity.id)", in: namespace)
    }
}

public struct BatteryCompactTrailingView: View {
    @ObservedObject public var activity: BatteryActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 5) {
            Text("\(activity.percentage)%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(activity.isCharging ? Color(red: 0.25, green: 0.95, blue: 0.45) : activity.tintColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            Image(systemName: activity.isCharging ? "battery.100percent" : activity.iconName)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundColor(activity.isCharging ? Color(red: 0.25, green: 0.95, blue: 0.45) : activity.tintColor)
        }
        .padding(.trailing, 8)
        .matchedGeometryIfAvailable(id: "hud_bat_icon_\(activity.id)", in: namespace)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: activity.percentage)
    }
}

public struct BatteryExpandedCardView: View {
    @ObservedObject public var activity: BatteryActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(activity.tintColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: activity.isCritical ? "exclamationmark.triangle.fill" : activity.iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(activity.tintColor)
                        .matchedGeometryIfAvailable(id: "hud_bat_icon_\(activity.id)", in: namespace)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.isLowBattery ? "Low Battery Warning" : (activity.isCharging ? "MagSafe Power" : "Battery Power"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(activity.subtitle)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Text("\(activity.percentage)%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(activity.tintColor)
            }
            .padding(.horizontal, 4)
            
            // Progress Bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 8)
                
                Capsule()
                    .fill(activity.tintColor)
                    .frame(width: max(8, 330 * CGFloat(Double(activity.percentage) / 100.0)), height: 8)
            }
            .frame(height: 8)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 8)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: activity.percentage)
    }
}
