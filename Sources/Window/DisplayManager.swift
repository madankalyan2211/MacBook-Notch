import AppKit
import Combine

/// Monitors screen configuration changes, spaces, sleep/wake, and display resolution updates.
public final class DisplayManager: ObservableObject {
    public static let shared = DisplayManager()
    
    @Published public private(set) var currentNotchInfo: NotchPositioning.NotchInfo
    @Published public private(set) var activeScreen: NSScreen
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let initialScreen = NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        self.activeScreen = initialScreen
        self.currentNotchInfo = NotchPositioning.shared.detectNotch(for: initialScreen)
        
        setupObservers()
    }
    
    private func setupObservers() {
        // Display parameter changes (resolution, connect/disconnect external monitor)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculateDisplay()
            }
            .store(in: &cancellables)
            
        // System wake notification
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculateDisplay()
            }
            .store(in: &cancellables)
            
        // Active space changed
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.activeSpaceDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recalculateDisplay()
            }
            .store(in: &cancellables)
    }
    
    public func recalculateDisplay() {
        let screen = NSScreen.main ?? NSScreen.screens.first ?? activeScreen
        self.activeScreen = screen
        self.currentNotchInfo = NotchPositioning.shared.detectNotch(for: screen)
    }
}
