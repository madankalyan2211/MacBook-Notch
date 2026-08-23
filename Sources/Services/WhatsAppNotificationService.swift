import Foundation
import Cocoa
import Combine

public struct WhatsAppMessage: Identifiable, Equatable, Sendable {
    public let id: String
    public let senderName: String
    public let messageText: String
    public let timestamp: Date
    public let isGroup: Bool
    public let groupName: String?
    
    public init(
        id: String = UUID().uuidString,
        senderName: String,
        messageText: String,
        timestamp: Date = Date(),
        isGroup: Bool = false,
        groupName: String? = nil
    ) {
        self.id = id
        self.senderName = senderName
        self.messageText = messageText
        self.timestamp = timestamp
        self.isGroup = isGroup
        self.groupName = groupName
    }
    
    public var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

/// Service managing incoming WhatsApp notifications and desktop deep linking
public final class WhatsAppNotificationService: ObservableObject {
    public static let shared = WhatsAppNotificationService()
    
    @Published public private(set) var currentMessage: WhatsAppMessage?
    @Published public var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "macbooknotch.whatsapp.enabled")
        }
    }
    
    public var onMessageReceived: ((WhatsAppMessage) -> Void)?
    public var onMessageDismissed: (() -> Void)?
    
    private var dismissTimer: Timer?
    private var sampleIndex: Int = 0
    
    private let sampleMessages: [(sender: String, text: String, isGroup: Bool, group: String?)] = [
        ("Sarah Jenkins", "Hey! Are you free for a quick call? ☕️", false, nil),
        ("Design Team", "Madan: The new Dynamic Island designs look fantastic! 🔥", true, "Design Team"),
        ("David Miller", "Sent you the project files over AirDrop 📁", false, nil),
        ("Family Group", "Mom: Don't forget dinner at 7 PM tonight! 🍕", true, "Family Group"),
        ("Alex Rivera", "Just pushed the latest updates to GitHub 🚀", false, nil)
    ]
    
    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "macbooknotch.whatsapp.enabled") as? Bool ?? true
    }
    
    public func postMessage(_ message: WhatsAppMessage) {
        guard isEnabled else { return }
        
        dismissTimer?.invalidate()
        self.currentMessage = message
        
        DispatchQueue.main.async { [weak self] in
            self?.onMessageReceived?(message)
        }
        
        // Auto-dismiss after 7 seconds
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { [weak self] _ in
            self?.dismissMessage()
        }
    }
    
    public func dismissMessage() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        self.currentMessage = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.onMessageDismissed?()
        }
    }
    
    public func openWhatsApp() {
        // Try opening WhatsApp desktop application
        if let whatsappURL = URL(string: "whatsapp://") {
            if NSWorkspace.shared.open(whatsappURL) {
                dismissMessage()
                return
            }
        }
        
        // Fallback to activating running app
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: {
            ($0.bundleIdentifier ?? "").lowercased().contains("whatsapp") ||
            ($0.localizedName ?? "").lowercased().contains("whatsapp")
        }) {
            app.activate(options: [.activateIgnoringOtherApps])
        } else {
            // Open WhatsApp Web in browser as ultimate fallback
            if let webURL = URL(string: "https://web.whatsapp.com") {
                NSWorkspace.shared.open(webURL)
            }
        }
        dismissMessage()
    }
    
    public func copyMessageText() {
        guard let msg = currentMessage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(msg.messageText, forType: .string)
    }
    
    /// Trigger a sample message for testing and demonstrations
    public func simulateIncomingMessage() {
        let sample = sampleMessages[sampleIndex % sampleMessages.count]
        sampleIndex += 1
        
        let msg = WhatsAppMessage(
            senderName: sample.sender,
            messageText: sample.text,
            isGroup: sample.isGroup,
            groupName: sample.group
        )
        postMessage(msg)
    }
}
