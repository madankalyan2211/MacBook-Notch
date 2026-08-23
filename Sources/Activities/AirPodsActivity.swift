import SwiftUI

/// Dynamic Island Activity representing connected AirPods and Bluetooth accessories (Icon-Only Compact Display).
public final class AirPodsActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .airpods
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 8.0
    
    @Published public var device: BluetoothAudioDevice
    
    public var title: String { device.name }
    public var subtitle: String { "Connected" }
    public var iconName: String { device.iconName }
    public var tintColor: Color { .white }
    public var progress: Double? { Double(device.primaryBattery) / 100.0 }
    
    public var compactPreferredWidth: CGFloat { 340 }
    public var expandedPreferredSize: CGSize { CGSize(width: 410, height: 145) }
    
    public init(device: BluetoothAudioDevice) {
        self.id = "hud.bluetooth.\(device.id)"
        self.device = device
    }
    
    public convenience init(title: String, batteryPercentage: Int) {
        let dev = BluetoothAudioDevice(
            id: UUID().uuidString,
            name: title,
            isAirPods: title.lowercased().contains("airpod"),
            isHeadphones: true,
            batteryLeft: batteryPercentage,
            batteryRight: max(0, batteryPercentage - 3),
            batteryCase: max(0, batteryPercentage - 6),
            singleBattery: batteryPercentage
        )
        self.init(device: dev)
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.leading, 8)
                .matchedGeometryIfAvailable(id: "airpods_icon_\(id)", in: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            HStack(spacing: 5) {
                Text("\(device.primaryBattery)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.25, green: 0.95, blue: 0.45))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                Image(systemName: "battery.100percent")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(Color(red: 0.25, green: 0.95, blue: 0.45))
            }
            .padding(.trailing, 8)
            .matchedGeometryIfAvailable(id: "airpods_bat_\(id)", in: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            AirPodsExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
    
    public var minimalBubbleView: AnyView {
        AnyView(
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        )
    }
}

public struct AirPodsExpandedCardView: View {
    @ObservedObject public var activity: AirPodsActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    private var device: BluetoothAudioDevice { activity.device }
    private let neonGreen = Color(red: 0.25, green: 0.95, blue: 0.45)
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header Row: Icon + Device Name + Connected Status
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: device.iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .matchedGeometryIfAvailable(id: "airpods_icon_\(activity.id)", in: namespace)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Connected • Battery Level")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Text("CONNECTED")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(neonGreen)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(neonGreen.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            // Battery Indicators Row (Left, Right, Case or Single Device)
            if let left = device.batteryLeft, let right = device.batteryRight, let caseBat = device.batteryCase {
                HStack(spacing: 12) {
                    // Left Earbud
                    AirPodsBatteryPill(
                        icon: device.isAirPods ? "airpod.left" : "earbuds",
                        title: "Left",
                        percentage: left,
                        tintColor: neonGreen
                    )
                    
                    // Right Earbud
                    AirPodsBatteryPill(
                        icon: device.isAirPods ? "airpod.right" : "earbuds",
                        title: "Right",
                        percentage: right,
                        tintColor: neonGreen
                    )
                    
                    // Case
                    AirPodsBatteryPill(
                        icon: "airpodspro.chargingcase.fill",
                        title: "Case",
                        percentage: caseBat,
                        tintColor: neonGreen
                    )
                }
            } else {
                // Generic Bluetooth Headphone / Mouse Battery Bar
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "battery.100percent")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(neonGreen)
                        Text("\(device.primaryBattery)% Battery")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 150, height: 8)
                        Capsule()
                            .fill(neonGreen)
                            .frame(width: 150 * CGFloat(device.primaryBattery) / 100.0, height: 8)
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 6)
    }
}

/// Helper subview for individual AirPods / Earbud / Case battery pills
public struct AirPodsBatteryPill: View {
    public let icon: String
    public let title: String
    public let percentage: Int
    public let tintColor: Color
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                Text("\(percentage)%")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundColor(tintColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

public final class DownloadActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .download
    public let priority: ActivityPriority = .ambient
    public var timeoutDuration: TimeInterval? = 8.0
    
    @Published public var title: String
    @Published public var subtitle: String
    @Published public var filename: String
    @Published public var downloadProgress: Double
    
    public var iconName: String { "arrow.down.circle.fill" }
    public var tintColor: Color { .blue }
    public var progress: Double? { downloadProgress }
    
    public var compactPreferredWidth: CGFloat { 276 }
    public var expandedPreferredSize: CGSize { CGSize(width: 360, height: 120) }
    
    public init(
        id: String = "activity.download",
        filename: String = "File.zip",
        progress: Double = 0.45
    ) {
        self.id = id
        self.filename = filename
        self.downloadProgress = progress
        self.title = filename
        self.subtitle = "\(Int(progress * 100))%"
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.blue)
                .matchedGeometryIfAvailable(id: "down_icon_\(id)", in: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.25), lineWidth: 3)
                    .frame(width: 16, height: 16)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(max(0.01, min(1.0, downloadProgress))))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 16, height: 16)
            }
            .matchedGeometryIfAvailable(id: "down_ring_\(id)", in: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    Text(filename)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 10)
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: 300 * CGFloat(downloadProgress), height: 10)
                }
                .frame(height: 10)
            }
            .padding(.horizontal, 8)
        )
    }
}
