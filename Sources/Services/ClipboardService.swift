import AppKit
import Combine

public struct ClipboardItem: Equatable {
    public enum ItemType: Equatable {
        case text(String)
        case url(URL)
        case hexColor(String)
        case image
        case code(String)
    }
    
    public let type: ItemType
    public let previewText: String
    public let timestamp: Date
    public let characterCount: Int
}

/// Service that observes local pasteboard changes securely with privacy settings.
public final class ClipboardService: ObservableObject {
    public static let shared = ClipboardService()
    
    @Published public private(set) var latestItem: ClipboardItem?
    @Published public var isMonitoringEnabled: Bool = true
    
    public var onNewClipboardItem: ((ClipboardItem) -> Void)?
    
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    public func startMonitoring() {
        timer?.invalidate()
        lastChangeCount = NSPasteboard.general.changeCount
        
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkPasteboard() {
        guard isMonitoringEnabled else { return }
        
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        
        lastChangeCount = currentCount
        
        if let string = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
            let item: ClipboardItem
            
            if let url = URL(string: string), url.scheme != nil, url.host != nil {
                item = ClipboardItem(
                    type: .url(url),
                    previewText: string,
                    timestamp: Date(),
                    characterCount: string.count
                )
            } else if string.hasPrefix("#"), (string.count == 7 || string.count == 9 || string.count == 4) {
                item = ClipboardItem(
                    type: .hexColor(string),
                    previewText: string,
                    timestamp: Date(),
                    characterCount: string.count
                )
            } else if string.contains("\n") || string.contains("{") || string.contains("func ") || string.contains("import ") {
                let cleanPreview = string.components(separatedBy: .newlines).first ?? string
                item = ClipboardItem(
                    type: .code(string),
                    previewText: cleanPreview,
                    timestamp: Date(),
                    characterCount: string.count
                )
            } else {
                item = ClipboardItem(
                    type: .text(string),
                    previewText: string,
                    timestamp: Date(),
                    characterCount: string.count
                )
            }
            
            DispatchQueue.main.async {
                self.latestItem = item
                self.onNewClipboardItem?(item)
            }
        }
    }
    
    public func simulateCopy(text: String = "https://apple.com/macbook-pro") {
        let item = ClipboardItem(
            type: .url(URL(string: text)!),
            previewText: text,
            timestamp: Date(),
            characterCount: text.count
        )
        self.latestItem = item
        self.onNewClipboardItem?(item)
    }
}
