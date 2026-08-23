import Foundation
import Cocoa
import Combine
import SQLite3

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

/// Service managing live incoming WhatsApp notifications from native WhatsApp SQLite and deep linking
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
    private var dbPollTimer: Timer?
    private var dbFileSource: DispatchSourceFileSystemObject?
    private var lastMaxPK: Int64 = 0
    private var sampleIndex: Int = 0
    
    private let dbPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite"
    }()
    
    private let sampleMessages: [(sender: String, text: String, isGroup: Bool, group: String?)] = [
        ("Sarah Jenkins", "Hey! Are you free for a quick call? ☕️", false, nil),
        ("Design Team", "Madan: The new Dynamic Island designs look fantastic! 🔥", true, "Design Team"),
        ("David Miller", "Sent you the project files over AirDrop 📁", false, nil),
        ("Family Group", "Mom: Don't forget dinner at 7 PM tonight! 🍕", true, "Family Group"),
        ("Alex Rivera", "Just pushed the latest updates to GitHub 🚀", false, nil)
    ]
    
    private init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "macbooknotch.whatsapp.enabled") as? Bool ?? true
        initializeLastMaxPK()
        startLiveMonitoring()
    }
    
    private func initializeLastMaxPK() {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return
        }
        defer { sqlite3_close(db) }
        
        let query = "SELECT MAX(Z_PK) FROM ZWAMESSAGE;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                self.lastMaxPK = sqlite3_column_int64(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
    }
    
    private func startLiveMonitoring() {
        // Fast 0.8-second poller to capture new WhatsApp messages
        dbPollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkForNewWhatsAppMessages()
        }
        
        // File descriptor monitoring on WhatsApp shared container
        let walPath = "\(dbPath)-wal"
        let targetPath = FileManager.default.fileExists(atPath: walPath) ? walPath : dbPath
        let fd = open(targetPath, O_EVTONLY)
        if fd >= 0 {
            let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .attrib], queue: .main)
            src.setEventHandler { [weak self] in
                self?.checkForNewWhatsAppMessages()
            }
            src.setCancelHandler {
                close(fd)
            }
            src.resume()
            self.dbFileSource = src
        }
    }
    
    public func checkForNewWhatsAppMessages() {
        guard isEnabled else { return }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return
        }
        defer { sqlite3_close(db) }
        
        let query = """
        SELECT 
            m.Z_PK, 
            COALESCE(NULLIF(s.ZPARTNERNAME, ''), p.ZPUSHNAME, s.ZCONTACTJID, 'WhatsApp'), 
            m.ZTEXT, 
            s.ZSESSIONTYPE,
            s.ZPARTNERNAME
        FROM ZWAMESSAGE m
        LEFT JOIN ZWACHATSESSION s ON m.ZCHATSESSION = s.Z_PK
        LEFT JOIN ZWAPROFILEPUSHNAME p ON (m.ZFROMJID = p.ZJID OR s.ZCONTACTJID = p.ZJID)
        WHERE m.ZISFROMME = 0 AND m.Z_PK > ?
        ORDER BY m.Z_PK ASC;
        """
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_int64(stmt, 1, lastMaxPK)
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let pk = sqlite3_column_int64(stmt, 0)
            let rawSender = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "WhatsApp"
            let text = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "New Message"
            let sessionType = sqlite3_column_int(stmt, 3)
            let groupPartnerName = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            
            let isGroup = (sessionType == 1)
            let sender = cleanSenderName(rawSender)
            
            if pk > self.lastMaxPK {
                self.lastMaxPK = pk
                let message = WhatsAppMessage(
                    id: "\(pk)",
                    senderName: sender,
                    messageText: text,
                    timestamp: Date(),
                    isGroup: isGroup,
                    groupName: isGroup ? (groupPartnerName ?? sender) : nil
                )
                DispatchQueue.main.async { [weak self] in
                    self?.postMessage(message)
                }
            }
        }
    }
    
    private func cleanSenderName(_ rawName: String) -> String {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasSuffix("@s.whatsapp.net") {
            name = String(name.dropLast("@s.whatsapp.net".count))
            if name.count >= 10 {
                name = "+\(name)"
            }
        } else if name.hasSuffix("@g.us") {
            name = "Group Chat"
        } else if name.hasSuffix("@lid") {
            name = "WhatsApp Contact"
        }
        
        // Filter out base64 / encoded hash strings that are not human names
        if name.contains("==") || (name.count > 25 && !name.contains(" ")) {
            name = "WhatsApp Contact"
        }
        
        return name
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
    
    public func sendReply(text: String, completion: (() -> Void)? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 1. Copy reply text to clipboard for instant access
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(trimmed, forType: .string)
        
        // 2. Open WhatsApp conversation with text
        if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "whatsapp://send?text=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
        
        completion?()
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
