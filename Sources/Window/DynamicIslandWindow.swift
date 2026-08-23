import AppKit
import SwiftUI

/// Custom content hosting view that fits the Dynamic Island window exactly and captures trackpad swipes.
public final class DynamicIslandHostingView<Content: View>: NSHostingView<Content> {
    private var trackingArea: NSTrackingArea?
    private var lastScrollTime: Date = Date.distantPast
    
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
    
    // Precise shape hit testing: passes clicks through to desktop & underlying apps
    // whenever the mouse is outside the active island capsule / bubble.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let controller = DynamicIslandController.shared
        let geometry = controller.currentGeometry
        
        // In AppKit, (0,0) is bottom-left of the view.
        // View bounds: width = bounds.width, height = bounds.height
        // Island is attached flush to the top edge (y = bounds.height)
        let topY = bounds.height
        let bottomY = topY - max(geometry.height, 30.5) - 10 // cushion for hover / click
        
        let mainWidth = max(geometry.width, 160)
        let hasSecondary = (controller.state == .compact && controller.activityManager.secondaryActivity != nil)
        let bubbleExtraRight: CGFloat = hasSecondary ? (geometry.height + 30.0) : 0
        
        // Main island is centered at bounds.width / 2.0
        let minX = (bounds.width - mainWidth) / 2.0 - 10
        let maxX = (bounds.width + mainWidth) / 2.0 + bubbleExtraRight + 10
        
        let activeRect = NSRect(x: minX, y: bottomY, width: maxX - minX, height: topY - bottomY + 10)
        
        if activeRect.contains(point) {
            return super.hitTest(point)
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
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
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
        self.ignoresMouseEvents = true
    }
    
    // Never steal keyboard or window focus from user's active apps
    public override var canBecomeKey: Bool {
        return false
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
}
