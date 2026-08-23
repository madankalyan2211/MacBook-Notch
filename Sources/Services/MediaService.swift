import Foundation
import AppKit
import Combine
import CoreAudio

public struct MediaTrackInfo: Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var isPlaying: Bool
    public var duration: TimeInterval
    public var elapsedTime: TimeInterval
    public var artwork: NSImage?
    public var artworkUrl: String?
    public var sourceApp: String
    
    public init(
        title: String = "Not Playing",
        artist: String = "No Artist",
        album: String = "",
        isPlaying: Bool = false,
        duration: TimeInterval = 180,
        elapsedTime: TimeInterval = 0,
        artwork: NSImage? = nil,
        artworkUrl: String? = nil,
        sourceApp: String = "Spotify"
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.artwork = artwork
        self.artworkUrl = artworkUrl
        self.sourceApp = sourceApp
    }
}

/// Service managing macOS media detection, album artwork download, and direct PID media controls for Spotify, Apple Music, and Chrome YouTube.
public final class MediaService: ObservableObject {
    public static let shared = MediaService()
    
    @Published public private(set) var currentTrack: MediaTrackInfo = MediaTrackInfo()
    @Published public private(set) var isPlaybackActive: Bool = false
    
    private var observers: [NSObjectProtocol] = []
    private var syncTimer: Timer?
    private var artworkCache: [String: NSImage] = [:]
    private var youtubeDurationCache: [String: TimeInterval] = [:]
    
    private init() {
        setupDistributedObservers()
        checkActiveMediaOnLaunch()
        
        // Polling sync timer (every 1.0s) for real-time track updates
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkActiveMediaOnLaunch()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.syncTimer = timer
    }
    
    deinit {
        syncTimer?.invalidate()
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }
    
    private func setupDistributedObservers() {
        let center = DistributedNotificationCenter.default()
        
        let spotifyNames = [
            "com.spotify.client.PlaybackStateChanged",
            "com.spotify.client.playbackStateChanged"
        ]
        
        for name in spotifyNames {
            let obs = center.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.checkActiveMediaOnLaunch()
            }
            observers.append(obs)
        }
        
        let appleMusicNames = [
            "com.apple.Music.playerInfo",
            "com.apple.iTunes.playerInfo"
        ]
        
        for name in appleMusicNames {
            let obs = center.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.checkActiveMediaOnLaunch()
            }
            observers.append(obs)
        }
    }
    
    public func checkActiveMediaOnLaunch() {
        let apps = NSWorkspace.shared.runningApplications
        let isSpotifyRunning = apps.contains { $0.bundleIdentifier == "com.spotify.client" }
        let isMusicRunning = apps.contains { $0.bundleIdentifier == "com.apple.Music" }
        let isChromeRunning = apps.contains { $0.bundleIdentifier == "com.google.Chrome" }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Check Spotify first
            if isSpotifyRunning, let spotTrack = self.querySpotifyDirectly() {
                if spotTrack.isPlaying {
                    DispatchQueue.main.async {
                        self.updateTrackState(spotTrack)
                    }
                    return
                }
            }
            
            // 2. Check Apple Music
            if isMusicRunning, let musicTrack = self.queryAppleMusicDirectly() {
                if musicTrack.isPlaying {
                    DispatchQueue.main.async {
                        self.updateTrackState(musicTrack)
                    }
                    return
                }
            }
            
            // 3. Check Google Chrome YouTube
            if isChromeRunning, let ytTrack = self.queryChromeYouTubeDirectly() {
                if ytTrack.isPlaying {
                    DispatchQueue.main.async {
                        self.updateTrackState(ytTrack)
                    }
                    return
                }
            }
            
            // 4. Nothing active
            if self.isPlaybackActive {
                DispatchQueue.main.async {
                    self.isPlaybackActive = false
                }
            }
        }
    }
    
    private func updateTrackState(_ newTrack: MediaTrackInfo) {
        let shouldFetchArtwork = (newTrack.artworkUrl != nil && newTrack.artworkUrl != self.currentTrack.artworkUrl) || (self.currentTrack.artwork == nil && newTrack.artworkUrl != nil)
        
        var trackToSet = newTrack
        if let cached = artworkCache[newTrack.artworkUrl ?? ""] {
            trackToSet.artwork = cached
        }
        
        self.currentTrack = trackToSet
        self.isPlaybackActive = trackToSet.isPlaying
        
        if shouldFetchArtwork, let urlString = newTrack.artworkUrl, let url = URL(string: urlString) {
            downloadArtwork(from: url, forUrlKey: urlString)
        }
    }
    
    private func downloadArtwork(from url: URL, forUrlKey: String) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, let image = NSImage(data: data) else { return }
            
            DispatchQueue.main.async {
                self?.artworkCache[forUrlKey] = image
                if self?.currentTrack.artworkUrl == forUrlKey {
                    self?.currentTrack.artwork = image
                }
            }
        }.resume()
    }
    
    private func fetchYouTubeDuration(videoID: String) {
        guard youtubeDurationCache[videoID] == nil else { return }
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else { return }
        
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self, let data = data, let str = String(data: data, encoding: .utf8) else { return }
            
            var durationSecs: Double? = nil
            if let range = str.range(of: "\"lengthSeconds\":\"") {
                let sub = str[range.upperBound...]
                if let endRange = sub.range(of: "\"") {
                    let secondsStr = String(sub[..<endRange.lowerBound])
                    durationSecs = Double(secondsStr)
                }
            } else if let range = str.range(of: "\"approxDurationMs\":\"") {
                let sub = str[range.upperBound...]
                if let endRange = sub.range(of: "\"") {
                    let msStr = String(sub[..<endRange.lowerBound])
                    if let msNum = Double(msStr) {
                        durationSecs = msNum / 1000
                    }
                }
            }
            
            if let duration = durationSecs, duration > 0 {
                DispatchQueue.main.async {
                    self.youtubeDurationCache[videoID] = duration
                    if self.currentTrack.sourceApp == "YouTube" && self.currentTrack.duration != duration {
                        var updated = self.currentTrack
                        updated.duration = duration
                        self.currentTrack = updated
                    }
                }
            }
        }.resume()
    }
    
    private func querySpotifyDirectly() -> MediaTrackInfo? {
        let script = """
        tell application "Spotify"
            set pState to player state as string
            set isPlay to (pState is "playing")
            set tName to name of current track
            set tArtist to artist of current track
            set tAlbum to album of current track
            set tDuration to (duration of current track) / 1000
            set tPosition to player position
            set tArt to ""
            try
                set tArt to artwork url of current track
            end try
            return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (isPlay as string) & "|||" & (tDuration as string) & "|||" & (tPosition as string) & "|||" & tArt
        end tell
        """
        
        guard let output = executeAppleScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let artUrl = parts.count >= 7 ? parts[6].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        let isPlaying = parts[3].lowercased().contains("true")
        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        
        let exactDuration = Double(parts[4]) ?? 180
        let exactElapsedTime = Double(parts[5]) ?? 0
        
        return MediaTrackInfo(
            title: title,
            artist: parts[1].trimmingCharacters(in: .whitespacesAndNewlines),
            album: parts[2].trimmingCharacters(in: .whitespacesAndNewlines),
            isPlaying: isPlaying,
            duration: exactDuration,
            elapsedTime: exactElapsedTime,
            artwork: nil,
            artworkUrl: artUrl?.isEmpty == false ? artUrl : nil,
            sourceApp: "Spotify"
        )
    }
    
    private func queryAppleMusicDirectly() -> MediaTrackInfo? {
        let script = """
        tell application "Music"
            set pState to player state as string
            set isPlay to (pState is "playing")
            set tName to name of current track
            set tArtist to artist of current track
            set tAlbum to album of current track
            set tDuration to duration of current track
            set tPosition to player position
            return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (isPlay as string) & "|||" & (tDuration as string) & "|||" & (tPosition as string)
        end tell
        """
        
        guard let output = executeAppleScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let isPlaying = parts[3].lowercased().contains("true")
        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        
        let exactDuration = Double(parts[4]) ?? 180
        let exactElapsedTime = Double(parts[5]) ?? 0
        
        return MediaTrackInfo(
            title: title,
            artist: parts[1].trimmingCharacters(in: .whitespacesAndNewlines),
            album: parts[2].trimmingCharacters(in: .whitespacesAndNewlines),
            isPlaying: isPlaying,
            duration: exactDuration,
            elapsedTime: exactElapsedTime,
            artwork: nil,
            artworkUrl: nil,
            sourceApp: "Apple Music"
        )
    }
    
    private func isSystemAudioPlaying() -> Bool {
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
        guard status == noErr, defaultOutputDeviceID != 0 else { return true }
        
        var isRunning: UInt32 = 0
        var isRunningSize = UInt32(MemoryLayout<UInt32>.size)
        var isRunningAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectGetPropertyData(defaultOutputDeviceID, &isRunningAddr, 0, nil, &isRunningSize, &isRunning) == noErr {
            return isRunning != 0
        }
        return true
    }
    
    private func queryChromeYouTubeDirectly() -> MediaTrackInfo? {
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    set tabUrl to URL of t
                    if tabUrl contains "youtube.com" then
                        set tabTitle to title of t
                        return tabTitle & "|||" & tabUrl
                    end if
                end repeat
            end repeat
        end tell
        return "NONE"
        """
        
        guard let output = executeAppleScript(script), !output.isEmpty, output != "NONE" else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 2 else { return nil }
        
        let isPlaying = isSystemAudioPlaying()
        
        var rawTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        if rawTitle.hasSuffix(" - YouTube") {
            rawTitle = String(rawTitle.dropLast(" - YouTube".count))
        }
        if rawTitle.hasPrefix("▶ ") {
            rawTitle = String(rawTitle.dropFirst("▶ ".count))
        }
        if rawTitle.hasPrefix("▶") {
            rawTitle = String(rawTitle.dropFirst("▶".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !rawTitle.isEmpty else { return nil }
        
        let urlStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        var thumbUrl: String? = nil
        var videoID: String? = nil
        if let url = URL(string: urlStr),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            videoID = components.queryItems?.first(where: { $0.name == "v" })?.value
            if let vID = videoID {
                thumbUrl = "https://img.youtube.com/vi/\(vID)/hqdefault.jpg"
            }
        }
        
        var exactDurTime: Double = 240
        if let vID = videoID {
            if let cached = youtubeDurationCache[vID] {
                exactDurTime = cached
            } else {
                fetchYouTubeDuration(videoID: vID)
            }
        }
        
        return MediaTrackInfo(
            title: rawTitle,
            artist: "YouTube",
            album: "Google Chrome",
            isPlaying: isPlaying,
            duration: exactDurTime,
            elapsedTime: 0,
            artwork: nil,
            artworkUrl: thumbUrl,
            sourceApp: "YouTube"
        )
    }
    
    // MARK: - Direct PID & Keystroke Control (Works 100% reliably without JavaScript permissions)
    
    private func sendKeyToChromePID(keyCode: CGKeyCode, shift: Bool = false) {
        let chromeApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome")
        guard let chrome = chromeApps.first else { return }
        let pid = chrome.processIdentifier
        
        let src = CGEventSource(stateID: .hidSystemState)
        if let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
            if shift {
                keyDown.flags = .maskShift
                keyUp.flags = .maskShift
            }
            keyDown.postToPid(pid)
            usleep(40000)
            keyUp.postToPid(pid)
        }
    }
    
    // MARK: - Playback & Seeking Controls
    
    public func seek(to position: TimeInterval) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if self.currentTrack.sourceApp == "YouTube" {
                let targetSecs = Int(position)
                let ytScript = """
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            set curUrl to URL of t
                            if curUrl contains "youtube.com/watch" then
                                set text item delimiters to "&t="
                                set urlParts to text items of curUrl
                                set basePart to item 1 of urlParts
                                set text item delimiters to ""
                                set newUrl to basePart & "&t=\(targetSecs)s"
                                set URL of t to newUrl
                                return
                            end if
                        end repeat
                    end repeat
                end tell
                """
                _ = self.executeAppleScript(ytScript)
                return
            }
            
            let isSpotifyRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.spotify.client" }
            let isMusicRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
            
            if isSpotifyRunning && self.currentTrack.sourceApp == "Spotify" {
                _ = self.executeAppleScript("tell application \"Spotify\" to set player position to \(position)")
            } else if isMusicRunning && self.currentTrack.sourceApp == "Apple Music" {
                _ = self.executeAppleScript("tell application \"Music\" to set player position to \(position)")
            }
        }
    }
    
    public func togglePlayPause() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let isSpotifyRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.spotify.client" }
            let isMusicRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
            
            if isSpotifyRunning && self.currentTrack.sourceApp == "Spotify" {
                _ = self.executeAppleScript("tell application \"Spotify\" to playpause")
            } else if isMusicRunning && self.currentTrack.sourceApp == "Apple Music" {
                _ = self.executeAppleScript("tell application \"Music\" to playpause")
            } else {
                // Post 'k' key directly to Chrome process PID
                self.sendKeyToChromePID(keyCode: 40) // 40 = "k" key (YouTube Play/Pause toggle)
            }
            
            DispatchQueue.main.async {
                self.currentTrack.isPlaying.toggle()
                self.isPlaybackActive = self.currentTrack.isPlaying
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.checkActiveMediaOnLaunch()
            }
        }
    }
    
    public func nextTrack() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let isSpotifyRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.spotify.client" }
            let isMusicRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
            
            if isSpotifyRunning && self.currentTrack.sourceApp == "Spotify" {
                _ = self.executeAppleScript("tell application \"Spotify\" to next track")
            } else if isMusicRunning && self.currentTrack.sourceApp == "Apple Music" {
                _ = self.executeAppleScript("tell application \"Music\" to next track")
            } else {
                // Post Shift + N directly to Chrome process PID (YouTube Next Video)
                self.sendKeyToChromePID(keyCode: 45, shift: true) // 45 = "n" key
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.checkActiveMediaOnLaunch()
            }
        }
    }
    
    public func previousTrack() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let isSpotifyRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.spotify.client" }
            let isMusicRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
            
            if isSpotifyRunning && self.currentTrack.sourceApp == "Spotify" {
                _ = self.executeAppleScript("tell application \"Spotify\" to previous track")
            } else if isMusicRunning && self.currentTrack.sourceApp == "Apple Music" {
                _ = self.executeAppleScript("tell application \"Music\" to previous track")
            } else {
                // Post Shift + P directly to Chrome process PID (YouTube Previous Video)
                self.sendKeyToChromePID(keyCode: 35, shift: true) // 35 = "p" key
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.checkActiveMediaOnLaunch()
            }
        }
    }
    
    private func executeAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil, let val = output.stringValue, !val.isEmpty {
                return val
            }
        }
        return nil
    }
}
