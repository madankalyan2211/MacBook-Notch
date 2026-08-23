import Foundation
import Cocoa
import CoreAudio
import CoreMediaIO
import Combine

public struct CallInfo: Identifiable, Equatable {
    public let id: String
    public var callerName: String
    public var appName: String
    public var isVideo: Bool
    public var durationSeconds: Int
    public var isMuted: Bool
    
    public var formattedDuration: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
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
            // Call started
            isMicActive = true
            callStartTime = Date()
            
            let detectedApp = detectActiveCallingApp()
            let info = CallInfo(
                id: UUID().uuidString,
                callerName: detectedApp.appName,
                appName: detectedApp.appName,
                isVideo: detectedApp.isVideo,
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
    
    private func detectActiveCallingApp() -> (appName: String, isVideo: Bool) {
        let isVideo = queryCameraRunningState()
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            let bundle = app.bundleIdentifier ?? ""
            let name = app.localizedName ?? ""
            
            if bundle == "com.apple.FaceTime" || name.contains("FaceTime") {
                return (isVideo ? "FaceTime Video" : "FaceTime Audio", isVideo)
            }
            if bundle.contains("whatsapp") || name.contains("WhatsApp") {
                return (isVideo ? "WhatsApp Video" : "WhatsApp Call", isVideo)
            }
            if bundle.contains("zoom") || name.contains("zoom") {
                return (isVideo ? "Zoom Video" : "Zoom Audio", isVideo)
            }
            if bundle.contains("teams") || name.contains("Teams") {
                return (isVideo ? "Teams Video" : "Microsoft Teams", isVideo)
            }
            if bundle.contains("slack") || name.contains("Slack") {
                return (isVideo ? "Slack Video" : "Slack Huddle", isVideo)
            }
            if bundle.contains("google.Chrome") || bundle.contains("Safari") {
                return (isVideo ? "Meet Video" : "Web Audio Call", isVideo)
            }
        }
        return (isVideo ? "Video Call" : "Audio Call", isVideo)
    }
    
    private func startDurationTracker() {
        durationTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, var call = self.activeCall else { return }
            call.durationSeconds += 1
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
            callStartTime = Date()
            let info = CallInfo(
                id: "simulated.call",
                callerName: "FaceTime Audio",
                appName: "FaceTime",
                isVideo: false,
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
        stopDurationTracker()
        self.activeCall = nil
        self.onCallEnded?()
    }
}
