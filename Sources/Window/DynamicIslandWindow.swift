import AppKit
import SwiftUI

/// Custom content hosting view that fits the Dynamic Island window exactly and captures trackpad swipes & drag-and-drop.
public final class DynamicIslandHostingView<Content: View>: NSHostingView<Content> {
    private var trackingArea: NSTrackingArea?
    private var lastScrollTime: Date = Date.distantPast
    
    @MainActor public required init(rootView: Content) {
        super.init(rootView: rootView)
        setupDragRegistration()
    }
    
    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragRegistration()
    }
    
    private func setupDragRegistration() {
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .fileContents,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")
        ])
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
    }
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupDragRegistration()
    }
    
    // MARK: - NSDraggingDestination
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        let urls = extractURLs(from: pasteboard)
        let hasFileTypes = pasteboard.types?.contains(.fileURL) == true ||
                           pasteboard.types?.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType")) == true ||
                           pasteboard.types?.contains(NSPasteboard.PasteboardType("public.file-url")) == true
        
        if !urls.isEmpty || hasFileTypes {
            DispatchQueue.main.async {
                FileShelfService.shared.isDropTargeted = true
                if DynamicIslandController.shared.state == .idle {
                    DynamicIslandController.shared.transition(to: .compact)
                }
            }
            return .copy
        }
        return []
    }
    
    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        let urls = extractURLs(from: pasteboard)
        let hasFileTypes = pasteboard.types?.contains(.fileURL) == true ||
                           pasteboard.types?.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType")) == true ||
                           pasteboard.types?.contains(NSPasteboard.PasteboardType("public.file-url")) == true
        
        if !urls.isEmpty || hasFileTypes {
            if !FileShelfService.shared.isDropTargeted {
                DispatchQueue.main.async {
                    FileShelfService.shared.isDropTargeted = true
                }
            }
            return .copy
        }
        return []
    }
    
    public override func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async {
            FileShelfService.shared.isDropTargeted = false
        }
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DispatchQueue.main.async {
            FileShelfService.shared.isDropTargeted = false
        }
        let pasteboard = sender.draggingPasteboard
        let urls = extractURLs(from: pasteboard)
        
        if !urls.isEmpty {
            DispatchQueue.main.async {
                FileShelfService.shared.addFiles(urls: urls)
                let shelfAct = FileShelfActivity(files: FileShelfService.shared.files)
                DynamicIslandController.shared.activityManager.presentActivity(shelfAct)
                DynamicIslandController.shared.transition(to: .expanded)
            }
            return true
        }
        return false
    }
    
    private func extractURLs(from pasteboard: NSPasteboard) -> [URL] {
        var results: [URL] = []
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            results.append(contentsOf: urls)
        }
        if results.isEmpty, let filenames = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            results.append(contentsOf: filenames.map { URL(fileURLWithPath: $0) })
        }
        return results
    }
    
    // Precise shape hit testing: passes clicks through to desktop & underlying apps
    // whenever the mouse is outside the active island capsule / bubble.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let controller = DynamicIslandController.shared
        let geometry = controller.currentGeometry
        
        // In AppKit, (0,0) is bottom-left of the view.
        // View bounds: width = bounds.width, height = bounds.height
        // Island is attached flush to the top edge (y = bounds.height)
        let topY = bounds.height
        let bottomY = topY - max(geometry.height, 30.5) - 20 // cushion for hover / click / drop
        
        let mainWidth = max(geometry.width, 160)
        let hasSecondary = (controller.state == .compact && controller.activityManager.secondaryActivity != nil)
        let bubbleExtraRight: CGFloat = hasSecondary ? (geometry.height + 30.0) : 0
        
        // Main island is centered at bounds.width / 2.0
        let minX = (bounds.width - mainWidth) / 2.0 - 20
        let maxX = (bounds.width + mainWidth) / 2.0 + bubbleExtraRight + 20
        
        let activeRect = NSRect(x: minX, y: bottomY, width: maxX - minX, height: topY - bottomY + 20)
        
        if activeRect.contains(point) {
            return super.hitTest(point) ?? self
        }
        
        return nil
    }
    
    // Native macOS Two-Finger Trackpad Horizontal Swipe Detection
    public override func scrollWheel(with event: NSEvent) {
        let now = Date()
        let deltaX = event.scrollingDeltaX
        
        if abs(deltaX) > 4.0 && now.timeIntervalSince(lastScrollTime) > 0.28 {
            lastScrollTime = now
            if deltaX < 0 {
                DynamicIslandController.shared.handleSwipeLeft()
            } else {
                DynamicIslandController.shared.handleSwipeRight()
            }
            return
        }
        
        super.scrollWheel(with: event)
    }
}

/// Borderless, non-activating floating overlay panel positioned at the top edge of the active screen.
public final class DynamicIslandWindow: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false
        
        registerForDraggedTypes([
            .fileURL,
            .URL,
            .string,
            .fileContents,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")
        ])
    }
    
    // Never steal keyboard or window focus from user's active apps
    public override var canBecomeKey: Bool {
        return false
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
}
