import SwiftUI
import Combine

/// Manages active activities, priority queues, preemption, interruptions, auto-timeouts, and multi-activity swiping.
public final class ActivityManager: ObservableObject {
    @Published public private(set) var activeActivity: (any DynamicIslandActivity)?
    @Published public private(set) var activityStack: [any DynamicIslandActivity] = []
    @Published public private(set) var currentIndex: Int = 0
    
    public var onActivityChanged: ((_ old: (any DynamicIslandActivity)?, _ new: (any DynamicIslandActivity)?) -> Void)?
    
    private var timeoutTimers: [String: Timer] = [:]
    
    public init() {}
    
    /// Retrieves an existing activity by ID from the active stack without modifying priority or selection.
    public func getActivity(id: String) -> (any DynamicIslandActivity)? {
        return activityStack.first(where: { $0.id == id })
    }
    
    /// The secondary concurrent activity displayed in the detached bubble (strictly for persistent tasks like Music and Timers)
    public var secondaryActivity: (any DynamicIslandActivity)? {
        // If current active activity is a temporary HUD (Volume, Brightness, Battery, Clipboard, Focus), suppress secondary bubble
        if let current = activeActivity, current.priority == .critical || current.type == .volume || current.type == .brightness || current.type == .battery || current.type == .clipboard || current.id == "activity.focus" {
            return nil
        }
        
        // Filter stack for persistent multi-activity candidates only (Music, Timer, Downloads, AI)
        let eligibleStack = activityStack.filter {
            $0.type != .volume && $0.type != .brightness && $0.type != .battery && $0.type != .clipboard && $0.id != "activity.focus"
        }
        
        guard eligibleStack.count > 1 else { return nil }
        
        if let current = activeActivity, let idx = eligibleStack.firstIndex(where: { $0.id == current.id }) {
            let nextIdx = (idx + 1) % eligibleStack.count
            return eligibleStack[nextIdx]
        }
        return eligibleStack.count > 1 ? eligibleStack[1] : nil
    }
    
    /// Presents or queues an activity according to priority.
    public func presentActivity(_ activity: any DynamicIslandActivity) {
        // Invalidate any existing timer for this activity ID
        timeoutTimers[activity.id]?.invalidate()
        timeoutTimers.removeValue(forKey: activity.id)
        
        let previousActive = activeActivity
        
        // Remove existing instance if present
        activityStack.removeAll { $0.id == activity.id }
        
        // Insert into stack maintaining priority order
        activityStack.append(activity)
        activityStack.sort { $0.priority > $1.priority }
        
        // If the newly presented activity has equal or higher priority than previous, make it active
        if let previous = previousActive {
            if activity.priority >= previous.priority {
                self.currentIndex = activityStack.firstIndex(where: { $0.id == activity.id }) ?? 0
            } else {
                // Keep the higher-priority active activity in foreground
                self.currentIndex = activityStack.firstIndex(where: { $0.id == previous.id }) ?? 0
            }
        } else {
            self.currentIndex = activityStack.firstIndex(where: { $0.id == activity.id }) ?? 0
        }
        
        let newActive = activityStack.indices.contains(currentIndex) ? activityStack[currentIndex] : activityStack.first
        
        self.activeActivity = newActive
        if previousActive?.id != newActive?.id {
            self.onActivityChanged?(previousActive, newActive)
        }
        
        // Schedule auto-timeout if configured using .common RunLoop mode
        if let timeout = activity.timeoutDuration {
            let timer = Timer(timeInterval: timeout, repeats: false) { [weak self] _ in
                self?.removeActivity(id: activity.id)
            }
            RunLoop.main.add(timer, forMode: .common)
            timeoutTimers[activity.id] = timer
        }
    }
    
    /// Sets the active primary activity by ID without re-inserting or recreating the activity instance.
    public func setActiveActivity(id: String) {
        guard let idx = activityStack.firstIndex(where: { $0.id == id }) else { return }
        let previousActive = activeActivity
        self.currentIndex = idx
        let newActive = activityStack[idx]
        self.activeActivity = newActive
        if previousActive?.id != newActive.id {
            self.onActivityChanged?(previousActive, newActive)
        }
    }
    
    /// Temporarily makes an activity the active foreground activity for `duration` seconds,
    /// then cleanly removes it and smoothly restores foreground focus to `fallbackId` (e.g. Music).
    public func promoteTemporarily(activity: any DynamicIslandActivity, duration: TimeInterval, fallbackId: String?) {
        // Invalidate any existing timeout timer for this activity
        timeoutTimers[activity.id]?.invalidate()
        timeoutTimers.removeValue(forKey: activity.id)
        
        let previousActive = activeActivity
        activityStack.removeAll { $0.id == activity.id }
        
        // Insert into stack
        activityStack.append(activity)
        activityStack.sort { $0.priority > $1.priority }
        
        // Force newly promoted activity to be the foreground activeActivity immediately!
        self.currentIndex = activityStack.firstIndex(where: { $0.id == activity.id }) ?? 0
        let newActive = activityStack[currentIndex]
        self.activeActivity = newActive
        self.objectWillChange.send()
        
        if previousActive?.id != newActive.id {
            self.onActivityChanged?(previousActive, newActive)
        }
        
        // Schedule the switch-back timer: cleanly remove the temporary activity
        let switchTimer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.removeActivity(id: activity.id)
        }
        RunLoop.main.add(switchTimer, forMode: .common)
        timeoutTimers[activity.id] = switchTimer
    }
    
    /// Cycles to the next live activity in the stack (Swipe Left).
    public func cycleNext() {
        guard activityStack.count > 1 else { return }
        let previousActive = activeActivity
        currentIndex = (currentIndex + 1) % activityStack.count
        let newActive = activityStack[currentIndex]
        
        self.activeActivity = newActive
        self.onActivityChanged?(previousActive, newActive)
    }
    
    /// Cycles to the previous live activity in the stack (Swipe Right).
    public func cyclePrevious() {
        guard activityStack.count > 1 else { return }
        let previousActive = activeActivity
        currentIndex = (currentIndex - 1 + activityStack.count) % activityStack.count
        let newActive = activityStack[currentIndex]
        
        self.activeActivity = newActive
        self.onActivityChanged?(previousActive, newActive)
    }
    
    /// Removes an activity from the active stack and gracefully resumes previous activity.
    public func removeActivity(id: String) {
        timeoutTimers[id]?.invalidate()
        timeoutTimers.removeValue(forKey: id)
        
        let previousActive = activeActivity
        activityStack.removeAll { $0.id == id }
        
        if currentIndex >= activityStack.count {
            currentIndex = max(0, activityStack.count - 1)
        }
        
        let newActive = activityStack.indices.contains(currentIndex) ? activityStack[currentIndex] : nil
        
        self.activeActivity = newActive
        self.objectWillChange.send()
        
        if previousActive?.id != newActive?.id {
            self.onActivityChanged?(previousActive, newActive)
        }
    }
    
    /// Clears all activities and returns to idle.
    public func clearAllActivities() {
        for timer in timeoutTimers.values {
            timer.invalidate()
        }
        timeoutTimers.removeAll()
        
        let previousActive = activeActivity
        activityStack.removeAll()
        currentIndex = 0
        self.activeActivity = nil
        
        if previousActive != nil {
            self.onActivityChanged?(previousActive, nil)
        }
    }
}
