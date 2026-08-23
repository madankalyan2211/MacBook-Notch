import AppKit
import SwiftUI

/// Utility responsible for discovering display dimensions, physical notch bounds, and safe areas.
public final class NotchPositioning {
    public static let shared = NotchPositioning()
    
    private init() {}
    
    public struct NotchInfo {
        public let hasPhysicalNotch: Bool
        public let notchSize: CGSize
        public let notchOrigin: CGPoint
        public let screenFrame: CGRect
        public let safeAreaTopInset: CGFloat
        
        public static var `default`: NotchInfo {
            NotchInfo(
                hasPhysicalNotch: false,
                notchSize: CGSize(width: 165, height: 32),
                notchOrigin: CGPoint(x: 0, y: 0),
                screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                safeAreaTopInset: 32
            )
        }
    }
    
    /// Detects notch info for the target screen (defaults to main screen).
    public func detectNotch(for screen: NSScreen? = NSScreen.main) -> NotchInfo {
        guard let screen = screen else {
            return .default
        }
        
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let topBarHeight = screenFrame.maxY - visibleFrame.maxY
        
        // On modern MacBooks with a physical notch:
        // `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` define the menu bar areas to the left and right of the notch.
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           leftArea.width > 0, rightArea.width > 0 {
            
            // The notch is the cutout between the left and right auxiliary areas (approx 185 pt on 14", 210 pt on 16")
            let notchWidth = rightArea.minX - leftArea.maxX
            let notchHeight = max(leftArea.height, rightArea.height)
            let notchX = leftArea.maxX
            let notchY = screenFrame.maxY - notchHeight
            
            return NotchInfo(
                hasPhysicalNotch: true,
                notchSize: CGSize(width: notchWidth > 0 ? notchWidth : 185, height: max(notchHeight, 32)),
                notchOrigin: CGPoint(x: notchX, y: notchY),
                screenFrame: screenFrame,
                safeAreaTopInset: max(notchHeight, topBarHeight)
            )
        }
        
        // Fallback for MacBooks / iMacs / External monitors without physical notch
        // Standard virtual notch pill positioned top-center of the screen
        let fallbackWidth: CGFloat = 165
        let fallbackHeight: CGFloat = max(topBarHeight > 0 ? topBarHeight : 32, 32)
        let fallbackX = screenFrame.midX - (fallbackWidth / 2.0)
        let fallbackY = screenFrame.maxY - fallbackHeight
        
        return NotchInfo(
            hasPhysicalNotch: false,
            notchSize: CGSize(width: fallbackWidth, height: fallbackHeight),
            notchOrigin: CGPoint(x: fallbackX, y: fallbackY),
            screenFrame: screenFrame,
            safeAreaTopInset: fallbackHeight
        )
    }
}
