import Foundation
import Cocoa
import AVFoundation
import Combine

public struct VoiceMemoInfo: Identifiable, Equatable {
    public let id: String
    public var title: String
    public var durationSeconds: Int
    public var isRecording: Bool
    public var isPaused: Bool
    
    public var formattedDuration: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

/// Service handling Voice Memos recording state and native macOS Voice Memos app monitoring.
public final class VoiceMemoService: ObservableObject {
    public static let shared = VoiceMemoService()
    
    @Published public private(set) var activeMemo: VoiceMemoInfo?
    public var onRecordingStarted: ((VoiceMemoInfo) -> Void)?
    public var onRecordingUpdated: ((VoiceMemoInfo) -> Void)?
    public var onRecordingEnded: (() -> Void)?
    
    private var durationTimer: Timer?
    private var appCheckTimer: Timer?
    private var isSystemVoiceMemoRunning: Bool = false
    private var audioRecorder: AVAudioRecorder?
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        durationTimer?.invalidate()
        appCheckTimer?.invalidate()
    }
    
    public func startMonitoring() {
        appCheckTimer?.invalidate()
        
        // Fast 0.5s check for macOS Voice Memos app (com.apple.VoiceMemos)
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkSystemVoiceMemosApp()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.appCheckTimer = timer
    }
    
    private func checkSystemVoiceMemosApp() {
        guard audioRecorder == nil else { return } // If currently doing in-app recording, let that handle state
        
        let apps = NSWorkspace.shared.runningApplications
        let isRunning = apps.contains { $0.bundleIdentifier == "com.apple.VoiceMemos" }
        
        if !isRunning && isSystemVoiceMemoRunning {
            isSystemVoiceMemoRunning = false
            stopDurationTracker()
            self.activeMemo = nil
            DispatchQueue.main.async { [weak self] in
                self?.onRecordingEnded?()
            }
        }
    }
    
    public func toggleRecording() {
        if let current = activeMemo, current.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    public func startRecording() {
        let memo = VoiceMemoInfo(
            id: UUID().uuidString,
            title: "Voice Memo",
            durationSeconds: 0,
            isRecording: true,
            isPaused: false
        )
        self.activeMemo = memo
        startDurationTracker()
        
        DispatchQueue.main.async { [weak self] in
            self?.onRecordingStarted?(memo)
        }
    }
    
    public func togglePauseResume() {
        guard var memo = activeMemo else { return }
        memo.isPaused.toggle()
        self.activeMemo = memo
        self.onRecordingUpdated?(memo)
    }
    
    public func stopRecording() {
        stopDurationTracker()
        self.activeMemo = nil
        DispatchQueue.main.async { [weak self] in
            self?.onRecordingEnded?()
        }
    }
    
    private func startDurationTracker() {
        durationTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, var memo = self.activeMemo else { return }
            if !memo.isPaused {
                memo.durationSeconds += 1
                self.activeMemo = memo
                DispatchQueue.main.async {
                    self.onRecordingUpdated?(memo)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.durationTimer = timer
    }
    
    private func stopDurationTracker() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
