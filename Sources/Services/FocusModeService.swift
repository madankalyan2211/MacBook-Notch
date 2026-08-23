import Foundation
import SwiftUI
import Combine

public struct FocusModeEvent: Equatable {
    public let name: String
    public let iconName: String
    public let tintColor: Color
    public let isEnabled: Bool
}

/// Service monitoring macOS Do Not Disturb & Focus Modes with direct low-level property list parsing.
public final class FocusModeService: ObservableObject {
    public static let shared = FocusModeService()
    
    @Published public private(set) var isFocusEnabled: Bool = false
    @Published public private(set) var currentFocusName: String = "Do Not Disturb"
    
    public var onFocusModeTriggered: ((FocusModeEvent) -> Void)?
    
    private var pollTimer: Timer?
    private var lastPublishTime: String?
    private var lastRapidPublishCount: Int?
    private var lastTriggerTime: Date = Date.distantPast
    
    private let statusKitPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Preferences/com.apple.StatusKitAgent.plist")
    
    private init() {
        readInitialBaseline()
        startMonitoring()
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    private func readInitialBaseline() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: statusKitPath)),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            let count = dict["rapidPublishCount"] as? Int ?? (dict["rapidPublishCount"] as? NSNumber)?.intValue
            self.lastRapidPublishCount = count
            if let timeObj = dict["lastPublishTime"] {
                self.lastPublishTime = String(describing: timeObj)
            }
        }
    }
    
    public func startMonitoring() {
        pollTimer?.invalidate()
        
        // High-frequency 50ms direct file inspector
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkForStatusKitUpdates()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
        
        // Distributed notifications
        let center = DistributedNotificationCenter.default()
        let notifs = [
            "com.apple.donotdisturb.mode.changed",
            "com.apple.controlcenter.focus.changed",
            "com.apple.StatusKit.statusChanged"
        ]
        for name in notifs {
            center.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.checkForStatusKitUpdates()
            }
        }
    }
    
    private func checkForStatusKitUpdates() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: statusKitPath)),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return
        }
        
        let count = dict["rapidPublishCount"] as? Int ?? (dict["rapidPublishCount"] as? NSNumber)?.intValue
        let timeObj = dict["lastPublishTime"]
        let timeStr = timeObj != nil ? String(describing: timeObj!) : nil
        
        var hasChanged = false
        
        if let prevCount = lastRapidPublishCount, let currCount = count, prevCount != currCount {
            lastRapidPublishCount = currCount
            hasChanged = true
        } else if lastRapidPublishCount == nil && count != nil {
            lastRapidPublishCount = count
        }
        
        if let prevTime = lastPublishTime, let currTime = timeStr, prevTime != currTime {
            lastPublishTime = currTime
            hasChanged = true
        } else if lastPublishTime == nil && timeStr != nil {
            lastPublishTime = timeStr
        }
        
        if hasChanged {
            triggerFocusToggle()
        }
    }
    
    public func triggerFocusToggle() {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > 0.35 else { return }
        lastTriggerTime = now
        
        isFocusEnabled.toggle()
        
        let focusName = "Do Not Disturb"
        let icon = "moon.fill"
        let tint = Color(red: 0.65, green: 0.45, blue: 0.98)
        
        let event = FocusModeEvent(
            name: focusName,
            iconName: icon,
            tintColor: tint,
            isEnabled: isFocusEnabled
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.onFocusModeTriggered?(event)
        }
    }
    
    public func toggleFocusMode() {
        triggerFocusToggle()
    }
}
