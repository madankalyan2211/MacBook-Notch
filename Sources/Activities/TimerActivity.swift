import SwiftUI

public final class TimerActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .timer
    public let priority: ActivityPriority
    public var timeoutDuration: TimeInterval? = nil
    
    @Published public var title: String
    @Published public var subtitle: String
    @Published public var totalDuration: TimeInterval
    @Published public var remainingTime: TimeInterval
    @Published public var isRunning: Bool
    @Published public var isFinished: Bool
    
    public var iconName: String { "timer" }
    public var tintColor: Color { Color.orange }
    
    public var progress: Double? {
        guard totalDuration > 0 else { return 0 }
        // Countdown direction: Starts at 1.0 (full) and drains in reverse down to 0.0
        return max(0, min(1.0, remainingTime / totalDuration))
    }
    
    public var formattedRemainingTime: String {
        let total = max(0, Int(ceil(remainingTime)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
    
    public var compactPreferredWidth: CGFloat {
        let total = max(0, Int(ceil(remainingTime)))
        if total >= 3600 {
            // Hours format (e.g. 1:25:30 or 10:00:00) -> Dynamic expansion
            return total >= 36000 ? 350 : 340
        } else {
            // Minutes & seconds format (e.g. 05:00)
            return 305
        }
    }
    public var expandedPreferredSize: CGSize { CGSize(width: 390, height: 160) }
    
    public init(
        id: String = "activity.timer",
        title: String = "Timer",
        totalDuration: TimeInterval = 300,
        remainingTime: TimeInterval = 300,
        isRunning: Bool = true,
        isFinished: Bool = false,
        priority: ActivityPriority = .standard
    ) {
        self.id = id
        self.title = title
        self.subtitle = "Countdown"
        self.totalDuration = totalDuration
        self.remainingTime = remainingTime
        self.isRunning = isRunning
        self.isFinished = isFinished
        self.priority = isFinished ? .critical : priority
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            TimerCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            TimerCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            TimerExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
    
    public var minimalBubbleView: AnyView {
        AnyView(
            TimerMinimalBubbleView(activity: self)
        )
    }
}

public struct TimerMinimalBubbleView: View {
    @ObservedObject public var activity: TimerActivity
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.18))
                .frame(width: 24, height: 24)
            
            Image(systemName: activity.isFinished ? "bell.badge.fill" : "timer")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(activity.isFinished ? .yellow : .orange)
        }
        .clipShape(Circle())
    }
}

public struct TimerCompactLeadingView: View {
    @ObservedObject public var activity: TimerActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Image(systemName: activity.isFinished ? "bell.badge.fill" : "timer")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(activity.isFinished ? .yellow : .orange)
            .padding(.leading, 8)
            .matchedGeometryIfAvailable(id: "timer_icon_\(activity.id)", in: namespace)
    }
}

public struct TimerCompactTrailingView: View {
    @ObservedObject public var activity: TimerActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        Text(activity.formattedRemainingTime)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundColor(activity.isFinished ? .yellow : .orange)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.trailing, 8)
            .matchedGeometryIfAvailable(id: "timer_digits_\(activity.id)", in: namespace)
    }
}

public struct TimerExpandedCardView: View {
    @ObservedObject public var activity: TimerActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: activity.isFinished ? "bell.badge.fill" : "timer")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(activity.isFinished ? .yellow : .orange)
                    }
                    .matchedGeometryIfAvailable(id: "timer_icon_\(activity.id)", in: namespace)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(activity.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .matchedGeometryIfAvailable(id: "timer_title_\(activity.id)", in: namespace)
                        
                        Text(activity.isFinished ? "Completed" : (activity.isRunning ? "Running" : "Paused"))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Text(activity.formattedRemainingTime)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(activity.isFinished ? .yellow : .white)
                    .matchedGeometryIfAvailable(id: "timer_digits_\(activity.id)", in: namespace)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(activity.isFinished ? Color.yellow : Color.orange)
                        .frame(width: geo.size.width * CGFloat(activity.progress ?? 0), height: 5)
                }
            }
            .frame(height: 5)
            .matchedGeometryIfAvailable(id: "timer_ring_\(activity.id)", in: namespace)
            
            // Action Buttons
            HStack(spacing: 14) {
                // Stop Button
                Button(action: {
                    TimerService.shared.stopTimer()
                    controller.activityManager.removeActivity(id: activity.id)
                }) {
                    Text("Stop")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // +1 Min Button
                Button(action: {
                    TimerService.shared.addMinute()
                }) {
                    Text("+1 Min")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // Pause/Resume Button
                Button(action: {
                    TimerService.shared.togglePauseResume()
                }) {
                    Text(activity.isRunning ? "Pause" : "Resume")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(activity.isRunning ? Color.orange : Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}
