import Foundation
import IOKit.ps

public struct BatteryInfo: Equatable {
    public var percentage: Int
    public var isCharging: Bool
    public var isPluggedIn: Bool
    public var isLowBattery: Bool { percentage <= 20 && !isCharging }
    public var isCriticalBattery: Bool { percentage <= 10 && !isCharging }
    
    public init(percentage: Int = 100, isCharging: Bool = false, isPluggedIn: Bool = false) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
    }
}

/// Service that monitors MacBook battery percentage, AC adapter connection, and triggers Low Battery warnings.
public final class BatteryService: ObservableObject {
    public static let shared = BatteryService()
    
    @Published public private(set) var currentBattery: BatteryInfo = BatteryInfo()
    public var onPowerSourceChanged: ((BatteryInfo) -> Void)?
    public var onLowBatteryWarning: ((BatteryInfo) -> Void)?
    
    private var lastPluggedIn: Bool?
    private var lastWarnedThreshold: Int?
    private var lastNotificationTime: Date = Date.distantPast
    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?
    
    private init() {
        // Read initial state without notifying
        updateBatteryInfo(shouldNotify: false)
        setupRealtimePowerSourceObserver()
        startPolling()
    }
    
    deinit {
        pollTimer?.invalidate()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
    
    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo(shouldNotify: true)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }
    
    private func setupRealtimePowerSourceObserver() {
        let callback: IOPowerSourceCallbackType = { _ in
            DispatchQueue.main.async {
                BatteryService.shared.updateBatteryInfo(shouldNotify: true)
            }
        }
        
        let source = IOPSNotificationCreateRunLoopSource(callback, nil)
        if let sourceRef = source?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), sourceRef, .commonModes)
            self.runLoopSource = sourceRef
        }
    }
    
    public func updateBatteryInfo(shouldNotify: Bool = true) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        for ps in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            let currentCapacity = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 100
            let maxCapacity = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let isCharging = (desc[kIOPSIsChargingKey as String] as? Bool ?? false) || ((desc["Is Charging"] as? Int ?? 0) == 1)
            let powerSourceState = desc[kIOPSPowerSourceStateKey as String] as? String ?? ""
            let isPluggedIn = (powerSourceState == (kIOPSACPowerValue as String))
            
            let percent = maxCapacity > 0 ? Int((Double(currentCapacity) / Double(maxCapacity)) * 100) : currentCapacity
            let newInfo = BatteryInfo(percentage: percent, isCharging: isCharging, isPluggedIn: isPluggedIn)
            
            let prevPlugged = self.lastPluggedIn
            self.currentBattery = newInfo
            self.lastPluggedIn = isPluggedIn
            
            if isCharging {
                self.lastWarnedThreshold = nil
            }
            
            // 1. Check if adapter connection state ACTUALLY flips (plugged <-> unplugged)
            if shouldNotify, let prev = prevPlugged, prev != isPluggedIn {
                let now = Date()
                if now.timeIntervalSince(lastNotificationTime) > 1.5 {
                    lastNotificationTime = now
                    self.onPowerSourceChanged?(newInfo)
                }
            }
            
            // 2. Check Low Battery Thresholds (20%, 10%, 5%) when on battery power
            if shouldNotify && !isCharging {
                if percent <= 5 {
                    if lastWarnedThreshold != 5 {
                        lastWarnedThreshold = 5
                        self.onLowBatteryWarning?(newInfo)
                    }
                } else if percent <= 10 {
                    if lastWarnedThreshold == nil || lastWarnedThreshold! > 10 {
                        lastWarnedThreshold = 10
                        self.onLowBatteryWarning?(newInfo)
                    }
                } else if percent <= 20 {
                    if lastWarnedThreshold == nil || lastWarnedThreshold! > 20 {
                        lastWarnedThreshold = 20
                        self.onLowBatteryWarning?(newInfo)
                    }
                }
            }
            
            break
        }
    }
    
    /// Trigger a simulated battery state for manual testing or debug preview
    public func simulateBattery(percentage: Int, isCharging: Bool) {
        let simulated = BatteryInfo(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isCharging
        )
        self.currentBattery = simulated
        if simulated.isLowBattery {
            self.onLowBatteryWarning?(simulated)
        } else {
            self.onPowerSourceChanged?(simulated)
        }
    }
}
