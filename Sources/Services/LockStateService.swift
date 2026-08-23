import Foundation
import AppKit
import Combine
import CoreGraphics

/// Service that monitors macOS Lock and Unlock states via system polling and distributed notifications.
public final class LockStateService: ObservableObject {
    public static let shared = LockStateService()
    
    @Published public private(set) var isLocked: Bool = false
    
    public var onLockStateChanged: ((Bool) -> Void)?
    
    private var observers: [Any] = []
    private var pollTimer: Timer?
    
    private init() {
        // Initial state check
        self.isLocked = checkCurrentLockStatus()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    public func startMonitoring() {
        stopMonitoring()
        
        let distCenter = DistributedNotificationCenter.default()
        
        // 1. Distributed screen locked notification
        let lockObserver = distCenter.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLockStateChange(isLocked: true)
        }
        observers.append(lockObserver)
        
        // 2. Distributed screen unlocked notification
        let unlockObserver = distCenter.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLockStateChange(isLocked: false)
        }
        observers.append(unlockObserver)
        
        // 3. Distributed session resign / become active
        let sessionResignDist = distCenter.addObserver(
            forName: NSNotification.Name("com.apple.sessionDidResignActive"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLockStateChange(isLocked: true)
        }
        observers.append(sessionResignDist)
        
        let sessionActiveDist = distCenter.addObserver(
            forName: NSNotification.Name("com.apple.sessionDidBecomeActive"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLockStateChange(isLocked: false)
        }
        observers.append(sessionActiveDist)
        
        // 4. Workspace session notifications
        let wsCenter = NSWorkspace.shared.notificationCenter
        let sessionResignObserver = wsCenter.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLockStateChange(isLocked: true)
        }
        observers.append(sessionResignObserver)
        
        let sessionActiveObserver = wsCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLockStateChange(isLocked: false)
        }
        observers.append(sessionActiveObserver)
        
        // 5. Screen sleep (lock) and wake
        let screenSleepObserver = wsCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLockStateChange(isLocked: true)
        }
        observers.append(screenSleepObserver)
        
        let screenWakeObserver = wsCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLockStateChange(isLocked: false)
        }
        observers.append(screenWakeObserver)
    }
    
    public func stopMonitoring() {
        observers.forEach {
            DistributedNotificationCenter.default().removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        observers.removeAll()
    }
    
    private func checkCurrentLockStatus() -> Bool {
        if let sessionInfo = CGSessionCopyCurrentDictionary() as? [String: Any] {
            if let isLocked = sessionInfo["CGSSessionScreenIsLocked"] as? Bool, isLocked {
                return true
            }
            if let isLockedNum = sessionInfo["CGSSessionScreenIsLocked"] as? NSNumber, isLockedNum.boolValue {
                return true
            }
        }
        return false
    }
    
    private func pollSessionLockState() {
        let isLockedNow = checkCurrentLockStatus()
        if isLockedNow != self.isLocked {
            handleLockStateChange(isLocked: isLockedNow)
        }
    }
    
    private func handleLockStateChange(isLocked: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isLocked != isLocked else { return }
            self.isLocked = isLocked
            self.onLockStateChanged?(isLocked)
        }
    }
    
    /// Trigger a manual lock or unlock notification for testing
    public func triggerManualState(isLocked: Bool) {
        handleLockStateChange(isLocked: isLocked)
    }
}
