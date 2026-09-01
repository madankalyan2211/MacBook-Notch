import AppKit
import SwiftUI

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu bar accessory / status bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize window manager & island
        _ = WindowManager.shared
        
        // Start Native HUD Interceptor for system volume & brightness suppression
        NativeHUDInterceptor.shared.start()
        
        // Automatically play the iconic Apple "hello" signature animation upon startup only if idle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if DynamicIslandController.shared.activityManager.activeActivity == nil {
                DynamicIslandController.shared.triggerHelloSignature()
            }
        }
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        NativeHUDInterceptor.shared.stop()
    }
}
