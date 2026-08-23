import Foundation
import Combine

public struct TimerModel: Equatable {
    public var id: String
    public var label: String
    public var totalDuration: TimeInterval
    public var remainingTime: TimeInterval
    public var isRunning: Bool
    public var isFinished: Bool
    
    public var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, 1.0 - (remainingTime / totalDuration)))
    }
    
    public var formattedTime: String {
        let totalSeconds = max(0, Int(ceil(remainingTime)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Service handling countdown timers and dynamic island timer activities.
public final class TimerService: ObservableObject {
    public static let shared = TimerService()
    
    @Published public private(set) var activeTimer: TimerModel?
    
    public var onTimerFinished: ((TimerModel) -> Void)?
    public var onTimerTick: ((TimerModel) -> Void)?
    public var onTimerStopped: (() -> Void)?
    
    private var ticker: Timer?
    
    private init() {}
    
    deinit {
        ticker?.invalidate()
    }
    
    public func startTimer(duration: TimeInterval, label: String = "Timer") {
        ticker?.invalidate()
        
        let newTimer = TimerModel(
            id: "activity.timer",
            label: label,
            totalDuration: duration,
            remainingTime: duration,
            isRunning: true,
            isFinished: false
        )
        
        self.activeTimer = newTimer
        
        // Notify immediately on start so UI updates in 0ms
        DispatchQueue.main.async { [weak self] in
            self?.onTimerTick?(newTimer)
        }
        
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Use .common run loop mode so ticks continue during mouse tracking/gestures
        RunLoop.main.add(timer, forMode: .common)
        self.ticker = timer
    }
    
    public func togglePauseResume() {
        guard var current = activeTimer, !current.isFinished else { return }
        current.isRunning.toggle()
        activeTimer = current
        onTimerTick?(current)
    }
    
    public func addMinute() {
        guard var current = activeTimer, !current.isFinished else { return }
        current.remainingTime += 60
        current.totalDuration += 60
        activeTimer = current
        onTimerTick?(current)
    }
    
    public func stopTimer() {
        ticker?.invalidate()
        ticker = nil
        activeTimer = nil
        onTimerStopped?()
    }
    
    private func tick() {
        guard var current = activeTimer, current.isRunning, !current.isFinished else { return }
        
        current.remainingTime -= 0.1
        
        if current.remainingTime <= 0 {
            current.remainingTime = 0
            current.isRunning = false
            current.isFinished = true
            activeTimer = current
            ticker?.invalidate()
            ticker = nil
            onTimerFinished?(current)
        } else {
            activeTimer = current
            onTimerTick?(current)
        }
    }
}
