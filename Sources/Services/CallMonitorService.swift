import Foundation
import Cocoa
import CoreAudio
import CoreMediaIO
import Combine

public enum CallState: String, Sendable {
    case ringing = "Ringing..."
    case connecting = "Connecting..."
    case active = "Active"
    case ended = "Ended"
}

public struct CallInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public var callerName: String
    public var appName: String
    public var isVideo: Bool
    public var state: CallState
    public var durationSeconds: Int
    public var isMuted: Bool
    
    public var formattedDuration: String {
        switch state {
        case .ringing, .connecting:
            return state.rawValue
        case .active:
            let mins = durationSeconds / 60
            let secs = durationSeconds % 60
            return String(format: "%02d:%02d", mins, secs)
        case .ended:
            return "Call Ended"
        }
    }
}

/// Service that monitors live microphone activity and call applications (FaceTime, WhatsApp, Zoom, Teams, Slack).
public final class CallMonitorService: ObservableObject {
    public static let shared = CallMonitorService()
    
    @Published public private(set) var activeCall: CallInfo?
    public var onCallStarted: ((CallInfo) -> Void)?
    public var onCallUpdated: ((CallInfo) -> Void)?
    public var onCallEnded: (() -> Void)?
    
    private var pollTimer: Timer?
    private var durationTimer: Timer?
    private var isMicActive: Bool = false
    private var callStartTime: Date?
    private var isSimulated: Bool = false
    private var pendingRingTicks: Int = 0
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        pollTimer?.invalidate()
        durationTimer?.invalidate()
    }
    
    public func startMonitoring() {
        pollTimer?.invalidate()
        
        // Fast 0.5s microphone activity poller
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkMicrophoneAndCallState()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }
    
    public func checkMicrophoneAndCallState() {
        guard !isSimulated else { return }
        
        let micActive = queryMicrophoneRunningState()
        
        if micActive && !isMicActive {
            // Check if this is an actual calling application before triggering Call HUD
            let detected = detectActiveCallingApp()
            guard detected.isKnownCallApp else { return }
            
            isMicActive = true
            callStartTime = nil // Duration only starts when call is answered
            pendingRingTicks = 3 // 3 ticks (approx 3 seconds) of ringing/connecting state
            
            let info = CallInfo(
                id: UUID().uuidString,
                callerName: detected.appName,
                appName: detected.appName,
                isVideo: detected.isVideo,
                state: .ringing,
                durationSeconds: 0,
                isMuted: false
            )
            
            self.activeCall = info
            startDurationTracker()
            
            DispatchQueue.main.async { [weak self] in
                self?.onCallStarted?(info)
            }
        } else if !micActive && isMicActive {
            // Call ended
            isMicActive = false
            callStartTime = nil
            pendingRingTicks = 0
            stopDurationTracker()
            self.activeCall = nil
            
            DispatchQueue.main.async { [weak self] in
                self?.onCallEnded?()
            }
        }
    }
    
    public func queryCameraRunningState() -> Bool {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        
        var dataSize: UInt32 = 0
        var dataUsed: UInt32 = 0
        let status = CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr, dataSize > 0 else { return false }
        
        let deviceCount = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
        var devices = [CMIODeviceID](repeating: 0, count: deviceCount)
        
        let getStatus = CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            dataSize,
            &dataUsed,
            &devices
        )
        
        guard getStatus == noErr else { return false }
        
        for device in devices {
            var isRunning: UInt32 = 0
            let isRunningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            
            var runDataUsed: UInt32 = 0
            let runStatus = CMIOObjectGetPropertyData(
                device,
                &runningAddress,
                0,
                nil,
                isRunningSize,
                &runDataUsed,
                &isRunning
            )
            
            if runStatus == noErr && isRunning != 0 {
                return true
            }
        }
        
        return false
    }
    
    private func queryMicrophoneRunningState() -> Bool {
        var defaultInputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultInputDeviceID
        )
        guard status == noErr, defaultInputDeviceID != 0 else { return false }
        
        var isRunning: UInt32 = 0
        var isRunningSize = UInt32(MemoryLayout<UInt32>.size)
        var isRunningAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(defaultInputDeviceID, &isRunningAddr, 0, nil, &isRunningSize, &isRunning) == noErr {
            return isRunning != 0
        }
        return false
    }
    
    private func detectActiveCallingApp() -> (appName: String, isVideo: Bool, isKnownCallApp: Bool) {
        let isVideo = queryCameraRunningState()
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            let bundle = (app.bundleIdentifier ?? "").lowercased()
            let name = (app.localizedName ?? "").lowercased()
            
            if bundle.contains("facetime") || name.contains("facetime") {
                return (isVideo ? "FaceTime Video" : "FaceTime Audio", isVideo, true)
            }
            if bundle.contains("whatsapp") || name.contains("whatsapp") {
                return (isVideo ? "WhatsApp Video" : "WhatsApp Call", isVideo, true)
            }
            if bundle.contains("zoom") || name.contains("zoom") {
                return (isVideo ? "Zoom Video" : "Zoom Audio", isVideo, true)
            }
            if bundle.contains("teams") || name.contains("teams") {
                return (isVideo ? "Teams Video" : "Microsoft Teams", isVideo, true)
            }
            if bundle.contains("slack") || name.contains("slack") {
                return (isVideo ? "Slack Video" : "Slack Huddle", isVideo, true)
            }
            if bundle.contains("skype") || name.contains("skype") {
                return (isVideo ? "Skype Video" : "Skype Call", isVideo, true)
            }
            if bundle.contains("discord") || name.contains("discord") {
                return (isVideo ? "Discord Video" : "Discord Voice", isVideo, true)
            }
            if bundle.contains("webex") || name.contains("webex") {
                return (isVideo ? "Webex Video" : "Webex Call", isVideo, true)
            }
        }
        return (isVideo ? "Video Call" : "Audio Call", isVideo, false)
    }
    
    private func startDurationTracker() {
        durationTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, var call = self.activeCall else { return }
            
            if self.pendingRingTicks > 0 {
                self.pendingRingTicks -= 1
                if self.pendingRingTicks == 0 {
                    // Call is now answered and active
                    call.state = .active
                    call.durationSeconds = 0
                    self.callStartTime = Date()
                }
            } else {
                call.state = .active
                call.durationSeconds += 1
            }
            
            if !self.isSimulated {
                call.isVideo = self.queryCameraRunningState()
            }
            self.activeCall = call
            DispatchQueue.main.async {
                self.onCallUpdated?(call)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.durationTimer = timer
    }
    
    private func stopDurationTracker() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    /// Simulates / Toggles a live call for testing & demonstrations
    public func toggleSimulatedCall() {
        if isSimulated {
            // End simulated call
            isSimulated = false
            stopDurationTracker()
            self.activeCall = nil
            self.onCallEnded?()
        } else {
            // Start simulated call
            isSimulated = true
            pendingRingTicks = 2
            let info = CallInfo(
                id: "simulated.call",
                callerName: "FaceTime Audio",
                appName: "FaceTime",
                isVideo: false,
                state: .ringing,
                durationSeconds: 0,
                isMuted: false
            )
            self.activeCall = info
            startDurationTracker()
            self.onCallStarted?(info)
        }
    }
    
    public func toggleMute() {
        guard var call = activeCall else { return }
        call.isMuted.toggle()
        self.activeCall = call
        self.onCallUpdated?(call)
    }
    
    public func endCall() {
        isSimulated = false
        isMicActive = false
        pendingRingTicks = 0
        stopDurationTracker()
        self.activeCall = nil
        self.onCallEnded?()
    }
}
