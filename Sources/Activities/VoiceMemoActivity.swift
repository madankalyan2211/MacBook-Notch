import SwiftUI

/// Dynamic Island Activity representing active Voice Memos and audio recordings.
public final class VoiceMemoActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .voiceMemo
    public let priority: ActivityPriority = .high
    public var timeoutDuration: TimeInterval? = nil
    
    @Published public var memoInfo: VoiceMemoInfo
    
    public var title: String { memoInfo.title }
    public var subtitle: String { "\(memoInfo.formattedDuration) • Recording" }
    public var iconName: String { "mic.fill" }
    public var tintColor: Color { Color(red: 1.0, green: 0.23, blue: 0.19) }
    public var progress: Double? { nil }
    
    public var compactPreferredWidth: CGFloat { 365 }
    public var expandedPreferredSize: CGSize { CGSize(width: 380, height: 135) }
    
    public init(memoInfo: VoiceMemoInfo) {
        self.id = "activity.voiceMemo.\(memoInfo.id)"
        self.memoInfo = memoInfo
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            VoiceMemoCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            VoiceMemoCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            VoiceMemoExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
    
    public var minimalBubbleView: AnyView {
        AnyView(
            Circle()
                .fill(tintColor)
                .frame(width: 10, height: 10)
        )
    }
}

public struct VoiceMemoCompactLeadingView: View {
    @ObservedObject public var activity: VoiceMemoActivity
    public let namespace: Namespace.ID?
    
    @State private var isPulsing: Bool = false
    
    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(activity.tintColor)
                .frame(width: 9, height: 9)
                .opacity(activity.memoInfo.isPaused ? 0.4 : (isPulsing ? 1.0 : 0.35))
                .animation(
                    activity.memoInfo.isPaused ? .default : Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                    value: isPulsing
                )
            
            Image(systemName: "mic.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(activity.tintColor)
        }
        .padding(.leading, 6)
        .fixedSize()
        .matchedGeometryIfAvailable(id: "memo_icon_\(activity.id)", in: namespace)
        .onAppear {
            isPulsing = true
        }
    }
}

public struct VoiceMemoCompactTrailingView: View {
    @ObservedObject public var activity: VoiceMemoActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 8) {
            Text(activity.memoInfo.formattedDuration)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .foregroundColor(activity.tintColor)
            
            VoiceMemoWaveformBars(isRecording: !activity.memoInfo.isPaused)
        }
        .padding(.trailing, 8)
        .fixedSize()
        .matchedGeometryIfAvailable(id: "memo_trailing_\(activity.id)", in: namespace)
    }
}

public struct VoiceMemoExpandedCardView: View {
    @ObservedObject public var activity: VoiceMemoActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    private var memo: VoiceMemoInfo { activity.memoInfo }
    private let memoRed = Color(red: 1.0, green: 0.23, blue: 0.19)
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header Info & Status
            HStack(spacing: 12) {
                // Recording Icon Badge
                ZStack {
                    Circle()
                        .fill(memoRed.opacity(0.18))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(memoRed)
                }
                .matchedGeometryIfAvailable(id: "memo_icon_\(activity.id)", in: namespace)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(memo.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(memoRed)
                            .frame(width: 7, height: 7)
                        
                        Text(memo.isPaused ? "Paused" : "Recording Audio")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                    }
                }
                
                Spacer()
                
                // Duration Counter & Waveform
                VStack(alignment: .trailing, spacing: 4) {
                    Text(memo.formattedDuration)
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(memoRed)
                    
                    VoiceMemoWaveformBars(isRecording: !memo.isPaused)
                }
                .matchedGeometryIfAvailable(id: "memo_trailing_\(activity.id)", in: namespace)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Pause / Resume Button
                Button(action: {
                    VoiceMemoService.shared.togglePauseResume()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: memo.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(memo.isPaused ? "Resume" : "Pause")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // Stop / Finish Button
                Button(action: {
                    VoiceMemoService.shared.stopRecording()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(memoRed)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Dynamic 5-Bar Waveform for Voice Memos
public struct VoiceMemoWaveformBars: View {
    public let isRecording: Bool
    
    @State private var barHeights: [CGFloat] = [0.35, 0.75, 1.0, 0.65, 0.4]
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    public var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.23, blue: 0.19))
                    .frame(width: 2.5, height: isRecording ? max(3, 14 * barHeights[index]) : 3)
                    .animation(.spring(response: 0.15, dampingFraction: 0.6), value: barHeights[index])
            }
        }
        .onReceive(timer) { _ in
            if isRecording {
                barHeights = [
                    CGFloat.random(in: 0.2...0.9),
                    CGFloat.random(in: 0.35...1.0),
                    CGFloat.random(in: 0.4...1.0),
                    CGFloat.random(in: 0.25...0.95),
                    CGFloat.random(in: 0.15...0.7)
                ]
            }
        }
    }
}
