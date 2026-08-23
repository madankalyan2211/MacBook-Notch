import SwiftUI

/// Dynamic Island Activity representing active voice & video calls (FaceTime, WhatsApp, Zoom, Teams, Slack, Meet).
public final class CallActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .call
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = nil
    
    @Published public var callInfo: CallInfo
    
    public var title: String { callInfo.callerName }
    public var subtitle: String { "\(callInfo.formattedDuration) • \(callInfo.appName)" }
    public var iconName: String {
        if callInfo.isMuted {
            return "mic.slash.fill"
        }
        return callInfo.isVideo ? "video.fill" : "phone.fill"
    }
    public var tintColor: Color {
        if callInfo.isMuted {
            return Color.orange
        }
        return Color(red: 0.22, green: 0.85, blue: 0.42)
    }
    public var progress: Double? { nil }
    
    public var compactPreferredWidth: CGFloat {
        let nameCharCount = CGFloat(callInfo.callerName.count)
        let leftWingRequired = (nameCharCount * 9.0) + 44.0
        let rightWingRequired = 115.0 // Duration + Equalizer waveform bars
        let maxWing = max(leftWingRequired, rightWingRequired)
        
        let totalCalculated = 195.0 + (maxWing * 2.0)
        return max(390.0, min(600.0, totalCalculated))
    }
    
    public var expandedPreferredSize: CGSize {
        let nameCharCount = CGFloat(callInfo.callerName.count)
        let cardWidth = max(420.0, min(540.0, 380.0 + (nameCharCount * 5.0)))
        return CGSize(width: cardWidth, height: 145)
    }
    
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
        HStack(spacing: 6) {
            Image(systemName: activity.iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(activity.tintColor)
            
            Text(activity.callInfo.callerName)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, 8)
        .matchedGeometryIfAvailable(id: "call_leading_\(activity.id)", in: namespace)
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
            
            CallWaveformBars(isActive: !activity.callInfo.isMuted)
        }
        .padding(.trailing, 8)
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
        VStack(spacing: 14) {
            // Header Row: Avatar / Icon + Caller Name + Live Status & Equalizer
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(call.isMuted ? Color.orange.opacity(0.2) : callGreen.opacity(0.18))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: activity.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(call.isMuted ? .orange : callGreen)
                }
                .matchedGeometryIfAvailable(id: "call_icon_\(activity.id)", in: namespace)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(call.callerName)
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(call.appName)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text(call.formattedDuration)
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(call.isMuted ? .orange : callGreen)
                    }
                }
                
                Spacer()
                
                CallWaveformBars(isActive: !call.isMuted)
            }
            
            // Interactive Call Controls Row: Mute + End Call
            HStack(spacing: 12) {
                // Interactive Microphone Mute Button
                Button(action: {
                    CallMonitorService.shared.toggleMute()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: call.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(call.isMuted ? "Unmute Mic" : "Mute Mic")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(call.isMuted ? .orange : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8.5)
                    .background(call.isMuted ? Color.orange.opacity(0.18) : Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(call.isMuted ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // End Call Button
                Button(action: {
                    CallMonitorService.shared.endCall()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("End Call")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8.5)
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
        HStack(spacing: 2.5) {
            ForEach(0..<4, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive ? Color(red: 0.22, green: 0.85, blue: 0.42) : Color.orange.opacity(0.6))
                    .frame(width: 3, height: isActive ? (14.0 * barHeights[idx]) : 4)
            }
        }
        .frame(height: 14)
        .onReceive(timer) { _ in
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 0.16)) {
                barHeights = [
                    CGFloat.random(in: 0.25...0.9),
                    CGFloat.random(in: 0.4...1.0),
                    CGFloat.random(in: 0.3...0.95),
                    CGFloat.random(in: 0.2...0.85)
                ]
            }
        }
    }
}
