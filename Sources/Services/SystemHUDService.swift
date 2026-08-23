import Foundation
import AppKit
import CoreAudio
import AudioToolbox
import CoreGraphics

public struct SystemHUDEvent: Equatable {
    public enum EventType: Equatable {
        case volume(level: Double, isMuted: Bool)
        case brightness(level: Double)
        case airPodsConnected(name: String, battery: Int)
        case downloadProgress(filename: String, progress: Double)
    }
    
    public let type: EventType
    public let timestamp: Date = Date()
}

typealias DisplayServicesGetBrightnessFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias DisplayServicesSetBrightnessFunction = @convention(c) (CGDirectDisplayID, Float) -> Int32

/// Service handling system HUD notifications (Real-Time Dynamic CoreAudio Volume & Hardware Brightness Listeners).
public final class SystemHUDService: ObservableObject {
    public static let shared = SystemHUDService()
    
    @Published public private(set) var latestEvent: SystemHUDEvent?
    public var onHUDTriggered: ((SystemHUDEvent) -> Void)?
    
    private var currentActiveDeviceID: AudioObjectID = 0
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    
    private var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private var pollTimer: Timer?
    private var lastVolume: Float32 = -1.0
    private var lastMute: Bool = false
    
    private var brightnessTimer: Timer?
    private var lastBrightness: Float = -1.0
    private var lastBrightnessKeyPressTime: Date = Date.distantPast
    private var globalMediaKeyMonitor: Any?
    private var localMediaKeyMonitor: Any?
    private var displayServicesFunction: DisplayServicesGetBrightnessFunction?
    private var displayServicesSetFunction: DisplayServicesSetBrightnessFunction?
    
    private init() {
        setupCoreAudioVolumeListener()
        setupDisplayBrightnessListener()
    }
    
    deinit {
        removeCoreAudioVolumeListener()
        pollTimer?.invalidate()
        brightnessTimer?.invalidate()
        if let g = globalMediaKeyMonitor {
            NSEvent.removeMonitor(g)
        }
        if let l = localMediaKeyMonitor {
            NSEvent.removeMonitor(l)
        }
    }
    
    // MARK: - Real-Time Display Brightness Hardware Listener
    
    private func setupDisplayBrightnessListener() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
                self.displayServicesFunction = unsafeBitCast(sym, to: DisplayServicesGetBrightnessFunction.self)
                var initialBri: Float = 0
                if displayServicesFunction?(CGMainDisplayID(), &initialBri) == 0 {
                    self.lastBrightness = initialBri
                }
            }
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
                self.displayServicesSetFunction = unsafeBitCast(setSym, to: DisplayServicesSetBrightnessFunction.self)
            }
        }
        
        // Monitor hardware media keys for manual brightness changes (F1/F2, Touch Bar, Magic Keyboard)
        globalMediaKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handleSystemDefinedEvent(event)
        }
        localMediaKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handleSystemDefinedEvent(event)
            return event
        }
        
        // Fast polling timer (0.05s) on common run loop mode for instant hardware tracking
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkBrightnessChange()
        }
        RunLoop.main.add(timer, forMode: .common)
        brightnessTimer = timer
    }
    
    private func handleSystemDefinedEvent(_ event: NSEvent) {
        guard event.subtype.rawValue == 8 else { return } // 8 is NX_SUBTYPE_AUX_CONTROL_BUTTONS
        let keyCode = Int((event.data1 & 0xFFFF0000) >> 16)
        let keyFlags = (event.data1 & 0x0000FFFF)
        let keyState = (keyFlags & 0xFF00) >> 8
        let isKeyDown = (keyState == 0xA || keyState == 0x1) // NX_KEYDOWN or repeat
        
        // 2: NX_KEYTYPE_BRIGHTNESS_UP, 3: NX_KEYTYPE_BRIGHTNESS_DOWN
        if keyCode == 2 || keyCode == 3 {
            if isKeyDown {
                lastBrightnessKeyPressTime = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                    self?.checkBrightnessChange(forceTrigger: true)
                }
            }
        }
    }
    
    private func checkBrightnessChange(forceTrigger: Bool = false) {
        guard let fn = displayServicesFunction else { return }
        var currentBri: Float = 0
        let status = fn(CGMainDisplayID(), &currentBri)
        guard status == 0 else { return }
        
        if lastBrightness < 0 {
            lastBrightness = currentBri
            return
        }
        
        let delta = abs(currentBri - lastBrightness)
        let isRecentKeyPress = Date().timeIntervalSince(lastBrightnessKeyPressTime) < 1.0
        
        // Only trigger HUD if manual key press was detected or forced, preventing auto-brightness from showing HUD
        if forceTrigger || (isRecentKeyPress && delta >= 0.005) {
            lastBrightness = currentBri
            let clamped = max(0.0, min(1.0, Double(currentBri)))
            triggerBrightnessHUD(level: clamped)
        } else {
            // Silently sync lastBrightness so ambient light sensor changes do not trigger the HUD
            lastBrightness = currentBri
        }
    }
    
    // MARK: - Real-Time CoreAudio Hardware Volume Listener with Dynamic Device Re-binding
    
    private func setupCoreAudioVolumeListener() {
        // 1. Listen for default output device changes (Headphones/Buds connected or disconnected)
        let devBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.rebindActiveOutputDevice()
            }
        }
        self.defaultDeviceListenerBlock = devBlock
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            DispatchQueue.main,
            devBlock
        )
        
        // 2. Initial binding
        rebindActiveOutputDevice()
        
        // 3. Fast 0.05s polling for ultra-responsive volume tracking across Bluetooth & internal DACs
        pollTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.pollActiveVolume()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }
    
    private func rebindActiveOutputDevice() {
        var newDeviceID = AudioObjectID(0)
        var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            0,
            nil,
            &propertySize,
            &newDeviceID
        )
        
        guard status == noErr, newDeviceID != 0 else { return }
        
        // If device changed, re-attach listener
        if newDeviceID != currentActiveDeviceID {
            removeCurrentDeviceVolumeListener()
            self.currentActiveDeviceID = newDeviceID
            
            var volumeAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.handleVolumeChanged(deviceID: newDeviceID)
                }
            }
            self.volumeListenerBlock = block
            
            AudioObjectAddPropertyListenerBlock(
                newDeviceID,
                &volumeAddress,
                DispatchQueue.main,
                block
            )
            
            // Sync initial volume for new device
            if let vol = readVolume(for: newDeviceID) {
                self.lastVolume = vol
            }
            self.lastMute = readMute(for: newDeviceID)
        }
    }
    
    private func removeCurrentDeviceVolumeListener() {
        guard let block = volumeListenerBlock, currentActiveDeviceID != 0 else { return }
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            currentActiveDeviceID,
            &volumeAddress,
            DispatchQueue.main,
            block
        )
        self.volumeListenerBlock = nil
    }
    
    private func removeCoreAudioVolumeListener() {
        removeCurrentDeviceVolumeListener()
        if let devBlock = defaultDeviceListenerBlock {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultDeviceAddress,
                DispatchQueue.main,
                devBlock
            )
            self.defaultDeviceListenerBlock = nil
        }
    }
    
    private func pollActiveVolume() {
        guard currentActiveDeviceID != 0 else {
            rebindActiveOutputDevice()
            return
        }
        
        guard let currVol = readVolume(for: currentActiveDeviceID) else { return }
        let currMute = readMute(for: currentActiveDeviceID)
        
        if lastVolume < 0 {
            lastVolume = currVol
            lastMute = currMute
            return
        }
        
        if abs(currVol - lastVolume) > 0.005 || currMute != lastMute {
            self.lastVolume = currVol
            self.lastMute = currMute
            triggerVolumeHUD(level: Double(currVol), isMuted: currMute)
        }
    }
    
    private func handleVolumeChanged(deviceID: AudioObjectID) {
        guard let currVol = readVolume(for: deviceID) else { return }
        let currMute = readMute(for: deviceID)
        self.lastVolume = currVol
        self.lastMute = currMute
        triggerVolumeHUD(level: Double(currVol), isMuted: currMute)
    }
    
    private func readVolume(for deviceID: AudioObjectID) -> Float32? {
        var volume = Float32(0.0)
        var volumeSize = UInt32(MemoryLayout<Float32>.size)
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &volumeSize, &volume) == noErr {
            return max(0.0, min(1.0, volume))
        }
        
        // Fallback to scalar volume (Main element)
        var scalarAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &scalarAddr, 0, nil, &volumeSize, &volume) == noErr {
            return max(0.0, min(1.0, volume))
        }
        
        // Fallback to channel 1 (Left / Master)
        var ch1Addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 1
        )
        if AudioObjectGetPropertyData(deviceID, &ch1Addr, 0, nil, &volumeSize, &volume) == noErr {
            return max(0.0, min(1.0, volume))
        }
        
        return nil
    }
    
    private func readMute(for deviceID: AudioObjectID) -> Bool {
        var isMuted: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &isMuted) == noErr {
            return isMuted != 0
        }
        return false
    }
    
    public func triggerVolumeHUD(level: Double, isMuted: Bool = false) {
        let event = SystemHUDEvent(type: .volume(level: level, isMuted: isMuted))
        DispatchQueue.main.async { [weak self] in
            self?.latestEvent = event
            self?.onHUDTriggered?(event)
        }
    }
    
    public func triggerBrightnessHUD(level: Double) {
        let event = SystemHUDEvent(type: .brightness(level: level))
        DispatchQueue.main.async { [weak self] in
            self?.latestEvent = event
            self?.onHUDTriggered?(event)
        }
    }
    
    // MARK: - Programmatic Volume & Brightness Adjustments
    
    public func getCurrentBrightness() -> Float {
        if let fn = displayServicesFunction {
            var bri: Float = 0
            if fn(CGMainDisplayID(), &bri) == 0 {
                return bri
            }
        }
        return lastBrightness >= 0 ? lastBrightness : 0.5
    }
    
    public func setBrightness(level: Float) {
        let clamped = max(0.0, min(1.0, level))
        self.lastBrightness = clamped
        self.lastBrightnessKeyPressTime = Date()
        _ = displayServicesSetFunction?(CGMainDisplayID(), clamped)
        triggerBrightnessHUD(level: Double(clamped))
    }
    
    public func getCurrentVolume() -> Float {
        guard currentActiveDeviceID != 0, let vol = readVolume(for: currentActiveDeviceID) else {
            return lastVolume >= 0 ? lastVolume : 0.5
        }
        return vol
    }
    
    public func setVolume(level: Float) {
        guard currentActiveDeviceID != 0 else { return }
        let clamped = max(0.0, min(1.0, level))
        self.lastVolume = clamped
        var vol = clamped
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let propertySize = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(currentActiveDeviceID, &volumeAddress, 0, nil, propertySize, &vol)
        triggerVolumeHUD(level: Double(clamped), isMuted: lastMute)
    }
    
    public func toggleMute() {
        guard currentActiveDeviceID != 0 else { return }
        let newMute = !readMute(for: currentActiveDeviceID)
        self.lastMute = newMute
        var isMuted: UInt32 = newMute ? 1 : 0
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let propertySize = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(currentActiveDeviceID, &muteAddress, 0, nil, propertySize, &isMuted)
        triggerVolumeHUD(level: Double(getCurrentVolume()), isMuted: newMute)
    }
}
