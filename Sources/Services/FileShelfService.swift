import Foundation
import Cocoa
import SwiftUI
import Combine
import UniformTypeIdentifiers

public struct ShelvedFileItem: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let fileSizeString: String
    public let isImage: Bool
    public let thumbnail: NSImage?
    public let fileIcon: NSImage
    
    public init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        
        // Calculate file size
        var sizeStr = "--"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        self.fileSizeString = sizeStr
        
        // File type check
        let ext = url.pathExtension.lowercased()
        let imageExts = ["png", "jpg", "jpeg", "webp", "gif", "heic", "tiff", "svg"]
        let isImg = imageExts.contains(ext)
        self.isImage = isImg
        
        // Load icon / thumbnail
        if isImg, let img = NSImage(contentsOf: url) {
            self.thumbnail = img
            self.fileIcon = img
        } else {
            self.thumbnail = nil
            self.fileIcon = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
    
    public static func == (lhs: ShelvedFileItem, rhs: ShelvedFileItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}

/// Service managing the Notch Drop Shelf, auto-capture of new screenshots/downloads, and AirDrop sharing engine
public final class FileShelfService: ObservableObject {
    public static let shared = FileShelfService()
    
    @Published public private(set) var files: [ShelvedFileItem] = []
    @Published public var isDropTargeted: Bool = false {
        didSet {
            onDropTargetedChanged?(isDropTargeted)
        }
    }
    
    @Published public var isAutoCaptureEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isAutoCaptureEnabled, forKey: "macbooknotch.shelf.autocapture")
        }
    }
    
    public var onFilesUpdated: (([ShelvedFileItem]) -> Void)?
    public var onDropTargetedChanged: ((Bool) -> Void)?
    
    private var desktopSource: DispatchSourceFileSystemObject?
    private var downloadsSource: DispatchSourceFileSystemObject?
    private var knownDesktopFiles: Set<String> = []
    private var knownDownloadFiles: Set<String> = []
    
    private init() {
        self.isAutoCaptureEnabled = UserDefaults.standard.object(forKey: "macbooknotch.shelf.autocapture") as? Bool ?? true
        snapshotInitialDirectories()
        startFolderWatchers()
    }
    
    private func snapshotInitialDirectories() {
        let fm = FileManager.default
        let desktop = fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let downloads = fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        
        if let contents = try? fm.contentsOfDirectory(atPath: desktop.path) {
            knownDesktopFiles = Set(contents)
        }
        if let contents = try? fm.contentsOfDirectory(atPath: downloads.path) {
            knownDownloadFiles = Set(contents)
        }
    }
    
    private func startFolderWatchers() {
        let fm = FileManager.default
        let desktop = fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let downloads = fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        
        // Watch Desktop for new Screenshots
        let desktopFD = open(desktop.path, O_EVTONLY)
        if desktopFD >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: desktopFD, eventMask: .write, queue: .main)
            src.setEventHandler { [weak self] in
                self?.checkForNewFiles(in: desktop, knownSet: &self!.knownDesktopFiles)
            }
            src.setCancelHandler {
                close(desktopFD)
            }
            src.resume()
            self.desktopSource = src
        }
        
        // Watch Downloads for new Downloads
        let downloadsFD = open(downloads.path, O_EVTONLY)
        if downloadsFD >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: downloadsFD, eventMask: .write, queue: .main)
            src.setEventHandler { [weak self] in
                self?.checkForNewFiles(in: downloads, knownSet: &self!.knownDownloadFiles)
            }
            src.setCancelHandler {
                close(downloadsFD)
            }
            src.resume()
            self.downloadsSource = src
        }
    }
    
    private func checkForNewFiles(in dir: URL, knownSet: inout Set<String>) {
        guard isAutoCaptureEnabled else { return }
        let fm = FileManager.default
        guard let current = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
        let currentSet = Set(current)
        let newlyAdded = currentSet.subtracting(knownSet)
        knownSet = currentSet
        
        var newURLs: [URL] = []
        for filename in newlyAdded {
            if filename.hasPrefix(".") || filename.hasSuffix(".crdownload") || filename.hasSuffix(".download") {
                continue
            }
            let fileURL = dir.appendingPathComponent(filename)
            // Verify file exists and has size
            if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64, size > 0 {
                newURLs.append(fileURL)
            }
        }
        
        if !newURLs.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.addFiles(urls: newURLs)
            }
        }
    }
    
    public func addFiles(urls: [URL]) {
        var updated = files
        for url in urls {
            // Avoid duplicate paths
            if !updated.contains(where: { $0.url == url }) {
                updated.append(ShelvedFileItem(url: url))
            }
        }
        DispatchQueue.main.async {
            self.files = updated
            self.onFilesUpdated?(updated)
        }
    }
    
    public func removeFile(id: UUID) {
        var updated = files
        updated.removeAll { $0.id == id }
        DispatchQueue.main.async {
            self.files = updated
            self.onFilesUpdated?(updated)
        }
    }
    
    public func clearAll() {
        DispatchQueue.main.async {
            self.files.removeAll()
            self.onFilesUpdated?([])
        }
    }
    
    public func airDropAllFiles() {
        guard !files.isEmpty else { return }
        let urls = files.map { $0.url as NSURL }
        if let service = NSSharingService(named: .sendViaAirDrop) {
            service.perform(withItems: urls)
        }
    }
    
    public func airDropSingleFile(url: URL) {
        if let service = NSSharingService(named: .sendViaAirDrop) {
            service.perform(withItems: [url as NSURL])
        }
    }
    
    public func copyAllFilesToClipboard() {
        guard !files.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(files.map { $0.url as NSURL })
    }
    
    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    public func openFile(url: URL) {
        NSWorkspace.shared.open(url)
    }
}
