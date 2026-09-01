import SwiftUI

/// Debug Simulator: Interactive motion design testing panel.
public struct DebugControlView: View {
    @ObservedObject public var controller: DynamicIslandController
    @ObservedObject private var animConfig = IslandAnimationConfiguration.shared
    
    public init(controller: DynamicIslandController) {
        self.controller = controller
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Motion Speed Multiplier (Slow-Mo debugging)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Animation Speed")
                            .font(.headline)
                        Spacer()
                        Text("\(String(format: "%.2fx", animConfig.speedMultiplier))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        speedButton(label: "0.25x (Slow-Mo)", value: 0.25)
                        speedButton(label: "0.5x", value: 0.5)
                        speedButton(label: "1.0x (Normal)", value: 1.0)
                        speedButton(label: "2.0x (Fast)", value: 2.0)
                    }
                }
                
                Divider()
                
                // Spring Physics Tuning
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spring Physics Tuning")
                        .font(.headline)
                    
                    VStack(spacing: 6) {
                        HStack {
                            Text("Expansion Response: \(String(format: "%.2f", animConfig.expansionResponse))s")
                                .font(.caption)
                            Spacer()
                        }
                        Slider(value: $animConfig.expansionResponse, in: 0.15...0.70, step: 0.01)
                    }
                    
                    VStack(spacing: 6) {
                        HStack {
                            Text("Expansion Damping: \(String(format: "%.2f", animConfig.expansionDamping))")
                                .font(.caption)
                            Spacer()
                        }
                        Slider(value: $animConfig.expansionDamping, in: 0.40...1.0, step: 0.02)
                    }
                }
                
                Divider()
                
                // Manual State Control
                VStack(alignment: .leading, spacing: 8) {
                    Text("Direct State Transition")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Button("Idle") { controller.transition(to: .idle) }
                        Button("Peek") { controller.transition(to: .peek) }
                        Button("Compact") { controller.transition(to: .compact) }
                        Button("Expanded") { controller.transition(to: .expanded) }
                    }
                }
                
                Divider()
                
                // Activities Simulation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Morphing Activities")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        Button("🎙 Hey Siri Animation") {
                            let siri = SiriActivity()
                            controller.activityManager.presentActivity(siri)
                        }
                        
                        Button("🎵 Now Playing (Music)") {
                            let music = MusicActivity(
                                title: "Blinding Lights",
                                artist: "The Weeknd",
                                isPlaying: true
                            )
                            controller.activityManager.presentActivity(music)
                        }
                        
                        Button("⏱ Countdown Timer (5:00)") {
                            TimerService.shared.startTimer(duration: 300, label: "Tea Timer")
                        }
                        
                        Button("📋 Clipboard Copy") {
                            ClipboardService.shared.simulateCopy(text: "https://apple.com/macbook-pro-16")
                        }
                        
                        Button("🔊 Volume HUD 80%") {
                            SystemHUDService.shared.triggerVolumeHUD(level: 0.80)
                        }
                        
                        Button("☀️ Brightness HUD 75%") {
                            SystemHUDService.shared.triggerBrightnessHUD(level: 0.75)
                        }
                        
                        Button("⚡️ MagSafe Connected") {
                            BatteryService.shared.simulateBattery(percentage: 95, isCharging: true)
                        }
                        
                        Button("🪫 Low Battery Warning (15%)") {
                            BatteryService.shared.simulateBattery(percentage: 15, isCharging: false)
                        }
                        
                        Button("🚨 Critical Battery Warning (8%)") {
                            BatteryService.shared.simulateBattery(percentage: 8, isCharging: false)
                        }
                        
                        Button("🔤 Caps Lock Toggle HUD") {
                            CapsLockService.shared.simulateToggle()
                        }
                        
                        Button("🔒 Test Locked Symbol") {
                            LockStateService.shared.triggerManualState(isLocked: true)
                        }
                        
                        Button("🔓 Test Unlocked Symbol") {
                            LockStateService.shared.triggerManualState(isLocked: false)
                        }
                        
                        Button("☕️ Toggle Caffeine (Keep Awake)") {
                            CaffeineService.shared.toggle()
                        }
                    }
                }
                
                Divider()
                
                // Motion Transition Sequences
                VStack(alignment: .leading, spacing: 8) {
                    Text("Motion Sequence & Interruption Tests")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        Button("🔀 Music ➔ Timer Morph") {
                            let music = MusicActivity(title: "Starboy", artist: "The Weeknd")
                            controller.activityManager.presentActivity(music)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                TimerService.shared.startTimer(duration: 60, label: "Focus")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("⚡️ Music + Interrupted by Volume + Restore") {
                            let music = MusicActivity(title: "Blinding Lights", artist: "The Weeknd")
                            controller.activityManager.presentActivity(music)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                SystemHUDService.shared.triggerVolumeHUD(level: 0.65)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("🌪 Rapid Multi-Activity Stress Test") {
                            controller.activityManager.clearAllActivities()
                            
                            let music = MusicActivity(title: "Save Your Tears", artist: "The Weeknd")
                            controller.activityManager.presentActivity(music)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                ClipboardService.shared.simulateCopy(text: "swift build -c release")
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                                SystemHUDService.shared.triggerVolumeHUD(level: 0.9)
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                let bat = BatteryActivity(percentage: 100, isCharging: true)
                                controller.activityManager.presentActivity(bat)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button("🧹 Reset / Clear All") {
                            controller.activityManager.clearAllActivities()
                            TimerService.shared.stopTimer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func speedButton(label: String, value: Double) -> some View {
        Button(action: {
            animConfig.speedMultiplier = value
        }) {
            Text(label)
                .font(.system(size: 11, weight: animConfig.speedMultiplier == value ? .bold : .regular))
                .foregroundColor(animConfig.speedMultiplier == value ? .black : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(animConfig.speedMultiplier == value ? Color.accentColor : Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
