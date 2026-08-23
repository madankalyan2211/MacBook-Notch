import Foundation
import SQLite3
import Combine

/// Service monitoring macOS Clock app (mobiletimerd) SQLite database for active timers in real time.
public final class SystemClockMonitorService: ObservableObject {
    public static let shared = SystemClockMonitorService()
    
    public struct MacClockTimer: Equatable {
        public let id: String
        public let title: String
        public let totalDuration: TimeInterval
        public let remainingTime: TimeInterval
        public let isRunning: Bool
        public let isPaused: Bool
    }
    
    @Published public private(set) var activeMacTimer: MacClockTimer?
    
    public var onTimerUpdated: ((MacClockTimer) -> Void)?
    public var onTimerEnded: (() -> Void)?
    
    private var pollTimer: Timer?
    private let dbPath: String
    private var missingCount: Int = 0
    
    private init() {
        self.dbPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Group Containers/group.com.apple.mobiletimerd/local.sqlite")
        startMonitoring()
    }
    
    deinit {
        pollTimer?.invalidate()
    }
    
    public func startMonitoring() {
        pollTimer?.invalidate()
        
        // Fast lightweight check every 0.25s
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.checkDatabaseForActiveTimers()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }
    
    private func checkDatabaseForActiveTimers() {
        guard FileManager.default.fileExists(atPath: dbPath) else { return }
        
        var db: OpaquePointer?
        let openFlags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(dbPath, &db, openFlags, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        let sql = "SELECT Z_PK, ZSTATE, ZDURATION, ZFIRETIME, ZTITLE, ZFIREDDATE FROM ZMTCDTIMER WHERE ZSTATE IN (2, 3, 4) ORDER BY ZLASTMODIFIEDDATE DESC LIMIT 1;"
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            let pk = sqlite3_column_int(stmt, 0)
            let state = sqlite3_column_int(stmt, 1)
            let duration = sqlite3_column_double(stmt, 2)
            let titleText = sqlite3_column_text(stmt, 4).flatMap { String(cString: $0) }
            
            var fireTimestamp: TimeInterval = 0
            
            // Decode binary plist ZFIRETIME
            if let blobBytes = sqlite3_column_blob(stmt, 3) {
                let blobLength = sqlite3_column_bytes(stmt, 3)
                let data = Data(bytes: blobBytes, count: Int(blobLength))
                if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let objects = plist["$objects"] as? [Any] {
                    for obj in objects {
                        if let dict = obj as? [String: Any] {
                            if let time = dict["NS.time"] as? Double {
                                fireTimestamp = time
                                break
                            } else if let interval = dict["MTTimerTimeInterval"] as? Double {
                                fireTimestamp = Date().timeIntervalSinceReferenceDate + interval
                                break
                            }
                        }
                    }
                }
            }
            
            // Fallback to ZFIREDDATE
            if fireTimestamp == 0 {
                let colFired = sqlite3_column_double(stmt, 5)
                if colFired > 0 {
                    fireTimestamp = colFired
                }
            }
            
            let nowRef = Date().timeIntervalSinceReferenceDate
            let remaining = fireTimestamp > 0 ? max(0, fireTimestamp - nowRef) : duration
            
            // In macOS MobileTimer:
            // State 3 = MTTimerStateRunning
            // State 4 = MTTimerStatePaused
            // State 2 = MTTimerStateStopped
            let isRunning = (state == 3 || (state != 4 && fireTimestamp > nowRef)) && remaining > 0
            let isPaused = (state == 4)
            
            let timerTitle = (titleText?.isEmpty == false) ? titleText! : "Timer"
            let timerId = "clock.timer.\(pk)"
            
            if isRunning || isPaused {
                self.missingCount = 0
                let timer = MacClockTimer(
                    id: timerId,
                    title: timerTitle,
                    totalDuration: max(duration, 1),
                    remainingTime: remaining,
                    isRunning: isRunning,
                    isPaused: isPaused
                )
                
                self.activeMacTimer = timer
                self.onTimerUpdated?(timer)
                return
            }
        }
        
        // Immediate removal detection when macOS timer stops
        if activeMacTimer != nil {
            self.activeMacTimer = nil
            self.missingCount = 0
            self.onTimerEnded?()
        }
    }
}
