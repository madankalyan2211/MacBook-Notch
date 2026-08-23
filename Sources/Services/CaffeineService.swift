import Foundation
import SwiftUI
import Combine
import IOKit.pwr_mgt

public struct CaffeineState: Equatable {
    public let isActive: Bool
    public let remainingSeconds: TimeInterval?
    public let label: String
}

/// Service that prevents macOS display and system sleep (Keep Awake / Caffeine module).
public final class CaffeineService: ObservableObject {
    public static let shared = CaffeineService()
    
    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var durationSeconds: TimeInterval? = nil // nil = indefinite
    @Published public private(set) var remainingSeconds: TimeInterval? = nil
    
    public var onStateChanged: ((CaffeineState) -> Void)?
    
    private var assertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?
    
    private init() {}
    
    deinit {
        deactivate()
    }
    
    /// Toggle Caffeine state (Indefinite by default if activating)
    public func toggle(duration: TimeInterval? = nil) {
        if isActive {
            deactivate()
        } else {
            activate(duration: duration)
        }
    }
    
    /// Activate Caffeine sleep prevention for a specific duration or indefinitely
    public func activate(duration: TimeInterval? = nil) {
        // Release any existing assertion first
        releaseAssertion()
        
        let reason = "MacBookNotch Caffeine Active" as CFString
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        
        if success == kIOReturnSuccess {
            self.isActive = true
            self.durationSeconds = duration
            self.remainingSeconds = duration
            
            countdownTimer?.invalidate()
            if let duration = duration, duration > 0 {
                countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    if let remaining = self.remainingSeconds, remaining > 1 {
                        self.remainingSeconds = remaining - 1
                    } else {
                        self.deactivate()
                    }
                }
                RunLoop.main.add(countdownTimer!, forMode: .common)
            }
            
            notifyState()
        }
    }
    
    /// Deactivate Caffeine sleep prevention
    public func deactivate() {
        releaseAssertion()
        countdownTimer?.invalidate()
        countdownTimer = nil
        self.isActive = false
        self.durationSeconds = nil
        self.remainingSeconds = nil
        notifyState()
    }
    
    private func releaseAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
    
    private func notifyState() {
        let label: String
        if !isActive {
            label = "Sleep Allowed"
        } else if let rem = remainingSeconds {
            let mins = Int(rem) / 60
            let hrs = mins / 60
            if hrs > 0 {
                label = "\(hrs)h \(mins % 60)m remaining"
            } else {
                label = "\(mins)m remaining"
            }
        } else {
            label = "Indefinite Keep-Awake"
        }
        
        let state = CaffeineState(
            isActive: isActive,
            remainingSeconds: remainingSeconds,
            label: label
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.onStateChanged?(state)
        }
    }
}
