import SwiftUI

/// Dynamic Island Activity representing active voice & video calls (FaceTime, WhatsApp, Zoom, Teams, Meet).
public final class CallActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .call
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = nil
    
    @Published public var callInfo: CallInfo
    
    public var title: String { callInfo.callerName }
    public var subtitle: String { "\(callInfo.formattedDuration) • \(callInfo.appName)" }
    public var iconName: String { callInfo.isVideo ? "video.fill" : "phone.fill" }
    public var tintColor: Color { Color(red: 0.22, green: 0.85, blue: 0.42) }
    public var progress: Double? { nil }
    
    public var compactPreferredWidth: CGFloat { 370 }
    public var expandedPreferredSize: CGSize { CGSize(width: 380, height: 135) }
    
    public init(callInfo: CallInfo) {
        self.id = "activity.call.\(callInfo.id)"
        self.callInfo = callInfo
    }
    
    public func updateCallInfo(_ newInfo: CallInfo) {
        objectWillChange.send()
        self.callInfo = newInfo
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            CallCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            CallCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            CallExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
    
    public var minimalBubbleView: AnyView {
        AnyView(
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tintColor)
        )
    }
}

public struct CallCompactLeadingView: View {
    @ObservedObject public var activity: CallActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Image(systemName: activity.iconName)
            .font(.system(size: 13.5, weight: .bold))
            .foregroundColor(activity.tintColor)
            .padding(.leading, 8)
            .matchedGeometryIfAvailable(id: "call_icon_\(activity.id)", in: namespace)
            .fixedSize()
    }
}

public struct CallCompactTrailingView: View {
    @ObservedObject public var activity: CallActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 7) {
            Text(activity.callInfo.formattedDuration)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(activity.tintColor)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .matchedGeometryIfAvailable(id: "call_duration_\(activity.id)", in: namespace)
            
            CallWaveformBars(isActive: true)
        }
        .padding(.trailing, 8)
        .fixedSize()
        .matchedGeometryIfAvailable(id: "call_trailing_\(activity.id)", in: namespace)
    }
}

public struct CallExpandedCardView: View {
    @ObservedObject public var activity: CallActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    private var call: CallInfo { activity.callInfo }
    private let callGreen = Color(red: 0.22, green: 0.85, blue: 0.42)
    private let endRed = Color(red: 1.0, green: 0.23, blue: 0.19)
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header Row: Icon + Caller / App Name + Live Duration
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(callGreen.opacity(0.18))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: activity.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(callGreen)
                }
                .matchedGeometryIfAvailable(id: "call_icon_\(activity.id)", in: namespace)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(call.callerName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("\(call.formattedDuration) • \(call.appName)")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                CallWaveformBars(isActive: true)
            }
            
            // Interactive Call Controls Row: Mute + Audio Route + End Call
            HStack(spacing: 12) {
                // Mute Microphone Button
                Button(action: {
                    CallMonitorService.shared.toggleMute()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: call.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(call.isMuted ? "Unmute" : "Mute")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(call.isMuted ? .orange : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // End Call Button
                Button(action: {
                    CallMonitorService.shared.endCall()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("End Call")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(endRed)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
    }
}

/// Mini Animated Voice Equalizer Bars for the Live Call HUD
public struct CallWaveformBars: View {
    public let isActive: Bool
    
    @State private var barHeights: [CGFloat] = [0.35, 0.75, 1.0, 0.55]
    private let timer = Timer.publish(every: 0.18, on: .main, in: .common).autoconnect()
    
    public var body: some View {
        HStack(spacing: 2.2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color(red: 0.22, green: 0.85, blue: 0.42))
                    .frame(width: 2.4, height: isActive ? max(3.5, 15.0 * barHeights[index]) : 3.5)
                    .animation(.spring(response: 0.18, dampingFraction: 0.65), value: isActive ? barHeights[index] : 0)
            }
        }
        .onReceive(timer) { _ in
            if isActive {
                barHeights = [
                    CGFloat.random(in: 0.25...1.0),
                    CGFloat.random(in: 0.2...0.9),
                    CGFloat.random(in: 0.35...1.0),
                    CGFloat.random(in: 0.2...0.85)
                ]
            }
        }
    }
}
