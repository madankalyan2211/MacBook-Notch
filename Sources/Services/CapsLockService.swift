import Foundation
import Cocoa
import Combine
import CoreGraphics

/// Service monitoring macOS Caps Lock key state transitions in real time.
public final class CapsLockService: ObservableObject {
    public static let shared = CapsLockService()
    
    @Published public private(set) var isCapsLockOn: Bool = false
    public var onCapsLockToggled: ((Bool) -> Void)?
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastState: Bool = false
    private var pollTimer: Timer?
    
    private init() {
        // Initial state query
        let initial = queryHardwareCapsLockState()
        self.isCapsLockOn = initial
        self.lastState = initial
        
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    public func startMonitoring() {
        stopMonitoring()
        
        // 1. Global Monitor for background keystrokes
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event: event)
        }
        
        // 2. Local Monitor for in-app keystrokes
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event: event)
            return event
        }
        
        // 3. Fast polling backup (0.2s) to guarantee 100% detection even across fast switching
        pollTimer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkHardwareState()
        }
        if let timer = pollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    public func stopMonitoring() {
        if let g = globalMonitor {
            NSEvent.removeMonitor(g)
            globalMonitor = nil
        }
        if let l = localMonitor {
            NSEvent.removeMonitor(l)
            localMonitor = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func handleFlagsChanged(event: NSEvent) {
        let current = event.modifierFlags.contains(.capsLock)
        notifyIfChanged(newState: current)
    }
    
    private func checkHardwareState() {
        let current = queryHardwareCapsLockState()
        notifyIfChanged(newState: current)
    }
    
    private func notifyIfChanged(newState: Bool) {
        guard newState != lastState else { return }
        self.lastState = newState
        self.isCapsLockOn = newState
        
        DispatchQueue.main.async { [weak self] in
            self?.onCapsLockToggled?(newState)
        }
    }
    
    private func queryHardwareCapsLockState() -> Bool {
        return CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
    }
    
    /// Simulates a Caps Lock toggle for testing and simulator panel
    public func simulateToggle() {
        let newState = !isCapsLockOn
        self.lastState = newState
        self.isCapsLockOn = newState
        DispatchQueue.main.async { [weak self] in
            self?.onCapsLockToggled?(newState)
        }
    }
}
