import Foundation
import SwiftUI
import AppKit
import CoreAudio

@MainActor
public final class SiriMonitorService: ObservableObject {
    public static let shared = SiriMonitorService()
    
    private var timer: Timer?
    private let controller = DynamicIslandController.shared
    
    @Published public private(set) var isSiriActive: Bool = false
    
    private init() {}
    
    public func startMonitoring() {
        // Prompt for Accessibility permissions (required for deep Siri window detection)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSiriStatus()
            }
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }
    
    private func checkSiriStatus() {
        var siriDetected = false
        
        // 1. Accessibility API Detection (Most reliable for hidden system overlays)
        let apps = NSWorkspace.shared.runningApplications
        if let siriApp = apps.first(where: { $0.bundleIdentifier?.lowercased().contains("siri") == true || $0.localizedName?.lowercased() == "siri" }) {
            let appElement = AXUIElementCreateApplication(siriApp.processIdentifier)
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
            
            if result == .success, let windows = value as? [AXUIElement], !windows.isEmpty {
                // If Siri process has active accessibility windows, it's visible on screen
                siriDetected = true
            }
        }
        
        // 2. Fallback: Window-based detection (if triggered via icon)
        if !siriDetected {
            if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
                for windowInfo in windowList {
                    if let owner = windowInfo[kCGWindowOwnerName as String] as? String, owner.lowercased().contains("siri") {
                        siriDetected = true
                        break
                    }
                }
            }
        }
        
        // 3. Fallback: Microphone-based detection (for "Hey Siri" voice trigger)
        // If the mic is active, and there is no active call, we assume it's Siri or Dictation.
        if !siriDetected {
            let micActive = queryMicrophoneRunningState()
            if micActive && CallMonitorService.shared.activeCall == nil && VoiceMemoService.shared.activeMemo == nil {
                siriDetected = true
            }
        }
        
        if siriDetected && !isSiriActive {
            isSiriActive = true
            showSiriActivity()
        } else if !siriDetected && isSiriActive {
            isSiriActive = false
            hideSiriActivity()
        }
    }
    
    private func queryMicrophoneRunningState() -> Bool {
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize) == noErr else { return false }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &devices) == noErr else { return false }
        
        var isRunningAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        for device in devices {
            var isRunning: UInt32 = 0
            var isRunningSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &isRunningAddr, 0, nil, &isRunningSize, &isRunning) == noErr {
                if isRunning != 0 {
                    var streamAddr = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyStreams,
                        mScope: kAudioDevicePropertyScopeInput,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    var streamSize: UInt32 = 0
                    if AudioObjectGetPropertyDataSize(device, &streamAddr, 0, nil, &streamSize) == noErr && streamSize > 0 {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    private func showSiriActivity() {
        let siriActivity = SiriActivity()
        controller.activityManager.presentActivity(siriActivity)
    }
    
    private func hideSiriActivity() {
        controller.activityManager.removeActivity(id: "activity.siri")
    }
}
