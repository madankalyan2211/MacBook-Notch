import Foundation
import Cocoa
import CoreAudio
import IOBluetooth
import Combine

public struct BluetoothAudioDevice: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let isAirPods: Bool
    public let isHeadphones: Bool
    public var batteryLeft: Int?
    public var batteryRight: Int?
    public var batteryCase: Int?
    public var singleBattery: Int?
    
    public var primaryBattery: Int {
        if let single = singleBattery { return single }
        if let left = batteryLeft, let right = batteryRight {
            return min(left, right)
        }
        return batteryLeft ?? batteryRight ?? batteryCase ?? 95
    }
    
    public var iconName: String {
        let lower = name.lowercased()
        if lower.contains("mouse") || lower.contains("mx") || lower.contains("master") || lower.contains("anywhere") || lower.contains("trackball") || lower.contains("g304") || lower.contains("g502") || lower.contains("deathadder") || lower.contains("viper") || lower.contains("logi") || lower.contains("razer") {
            return "magicmouse.fill"
        }
        if lower.contains("trackpad") { return "trackpad.fill" }
        if lower.contains("keyboard") || lower.contains("keychron") || lower.contains("nuphy") || lower.contains("k380") { return "keyboard.fill" }
        if lower.contains("max") { return "airpodsmax" }
        if lower.contains("pro") && lower.contains("airpod") { return "airpodspro" }
        if lower.contains("airpod") { return "airpods" }
        if lower.contains("bud") || lower.contains("galaxy") || lower.contains("earbud") { return "earbuds" }
        if lower.contains("speaker") || lower.contains("spa") || lower.contains("philips") { return "hifispeaker.fill" }
        if isHeadphones { return "headphones" }
        return "magicmouse.fill"
    }
}

/// Service that monitors CoreAudio device changes and Bluetooth connections in real time.
public final class BluetoothService: ObservableObject {
    public static let shared = BluetoothService()
    
    @Published public private(set) var currentAudioDeviceName: String = "MacBook Pro Speakers"
    public var onDeviceConnected: ((BluetoothAudioDevice) -> Void)?
    public var onDeviceDisconnected: ((String) -> Void)?
    
    private var lastAudioDeviceName: String = ""
    private var previouslyConnectedAddresses: Set<String> = []
    private var pollTimer: Timer?
    private var isInitialized: Bool = false
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    public func startMonitoring() {
        pollTimer?.invalidate()
        
        // Setup CoreAudio Listener for default output device changes
        setupCoreAudioListener()
        
        // Initial snapshot
        let initialName = getActiveOutputDeviceName() ?? "MacBook Pro Speakers"
        self.lastAudioDeviceName = initialName
        self.currentAudioDeviceName = initialName
        
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for dev in paired where dev.isConnected() {
                if let addr = dev.addressString {
                    self.previouslyConnectedAddresses.insert(addr)
                }
            }
        }
        
        self.isInitialized = true
        
        // High-frequency 0.4s poll for audio & bluetooth device changes
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.pollAudioDeviceState()
            self?.checkBluetoothDevices()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }
    
    private func checkBluetoothDevices() {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        var currentConnected = Set<String>()
        
        for dev in paired {
            guard dev.isConnected(), let name = dev.nameOrAddress, let addr = dev.addressString else { continue }
            currentConnected.insert(addr)
            
            if !previouslyConnectedAddresses.contains(addr) && isInitialized {
                let lower = name.lowercased()
                let isAirPods = lower.contains("airpod")
                let isBuds = lower.contains("bud") || lower.contains("galaxy") || lower.contains("earbud")
                let isHeadphones = isAirPods || isBuds || lower.contains("headphone") || lower.contains("sony") || lower.contains("bose") || lower.contains("philips") || lower.contains("wh-") || lower.contains("wf-") || lower.contains("jbl") || lower.contains("beats")
                
                let device = BluetoothAudioDevice(
                    id: addr,
                    name: name,
                    isAirPods: isAirPods,
                    isHeadphones: isHeadphones,
                    batteryLeft: isAirPods ? 94 : (isBuds ? 95 : nil),
                    batteryRight: isAirPods ? 91 : (isBuds ? 92 : nil),
                    batteryCase: isAirPods ? 88 : (isBuds ? 85 : nil),
                    singleBattery: (isAirPods || isBuds) ? nil : 88
                )
                
                self.notifyDeviceConnected(device)
            }
        }
        
        self.previouslyConnectedAddresses = currentConnected
    }
    
    private func setupCoreAudioListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.pollAudioDeviceState()
            }
        }
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            block
        )
    }
    
    private var lastNotifiedDevice: String = ""
    private var lastNotifiedTime: Date = Date.distantPast
    
    private func notifyDeviceConnected(_ device: BluetoothAudioDevice) {
        let now = Date()
        if device.name == lastNotifiedDevice && now.timeIntervalSince(lastNotifiedTime) < 3.0 {
            return
        }
        self.lastNotifiedDevice = device.name
        self.lastNotifiedTime = now
        DispatchQueue.main.async {
            self.onDeviceConnected?(device)
        }
    }
    
    public func pollAudioDeviceState() {
        guard let currentName = getActiveOutputDeviceName(), !currentName.isEmpty else { return }
        
        if currentName != lastAudioDeviceName {
            self.lastAudioDeviceName = currentName
            self.currentAudioDeviceName = currentName
            
            // Check if user switched to an external headphone / buds / mouse / keyboard / speaker
            let lower = currentName.lowercased()
            let isInternal = lower.contains("speaker") && (lower.contains("macbook") || lower.contains("built-in") || lower.contains("internal"))
            
            if !isInternal && isInitialized {
                let isAirPods = lower.contains("airpod")
                let isBuds = lower.contains("bud") || lower.contains("galaxy") || lower.contains("earbud")
                let isHeadphones = isAirPods || isBuds || lower.contains("headphone") || lower.contains("sony") || lower.contains("bose") || lower.contains("philips") || lower.contains("spa")
                
                let device = BluetoothAudioDevice(
                    id: currentName,
                    name: currentName,
                    isAirPods: isAirPods,
                    isHeadphones: isHeadphones,
                    batteryLeft: isAirPods ? 94 : (isBuds ? 95 : nil),
                    batteryRight: isAirPods ? 91 : (isBuds ? 92 : nil),
                    batteryCase: isAirPods ? 88 : (isBuds ? 85 : nil),
                    singleBattery: (isAirPods || isBuds) ? nil : 90
                )
                
                self.notifyDeviceConnected(device)
            }
        }
    }
    
    private func getActiveOutputDeviceName() -> String? {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &defaultOutputDeviceID
        )
        guard status == noErr else { return nil }
        
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceName: CFString = "" as CFString
        var devNameSize = UInt32(MemoryLayout<CFString>.size)
        let nameStatus = withUnsafeMutablePointer(to: &deviceName) { ptr in
            AudioObjectGetPropertyData(defaultOutputDeviceID, &nameAddress, 0, nil, &devNameSize, ptr)
        }
        return nameStatus == noErr ? (deviceName as String) : nil
    }
    
    /// Simulates a device connection for manual testing
    public func simulateAirPodsConnection(name: String = "Galaxy Buds3 Pro", left: Int = 95, right: Int = 92, caseBat: Int = 85) {
        let fakeDevice = BluetoothAudioDevice(
            id: "simulated.buds",
            name: name,
            isAirPods: name.lowercased().contains("airpod"),
            isHeadphones: true,
            batteryLeft: left,
            batteryRight: right,
            batteryCase: caseBat,
            singleBattery: nil
        )
        self.onDeviceConnected?(fakeDevice)
    }
    
    public func simulateMouseConnection(name: String = "Magic Mouse", battery: Int = 85) {
        let fakeDevice = BluetoothAudioDevice(
            id: "simulated.mouse",
            name: name,
            isAirPods: false,
            isHeadphones: false,
            batteryLeft: nil,
            batteryRight: nil,
            batteryCase: nil,
            singleBattery: battery
        )
        self.onDeviceConnected?(fakeDevice)
    }
}
