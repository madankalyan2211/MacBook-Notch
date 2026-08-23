import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var controller: DynamicIslandController
    @State private var selectedTab: Int = 0
    
    public init(controller: DynamicIslandController = .shared) {
        self.controller = controller
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(controller: controller)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)
            
            ActivitiesSettingsTab(controller: controller)
                .tabItem {
                    Label("Activities", systemImage: "square.stack.3d.up")
                }
                .tag(1)
            
            NotchPetSettingsTab(controller: controller)
                .tabItem {
                    Label("Notch Pet", systemImage: "pawprint.fill")
                }
                .tag(2)
            
            PrivacySettingsTab(controller: controller)
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised.fill")
                }
                .tag(3)
            
            DebugSimulatorTab(controller: controller)
                .tabItem {
                    Label("Simulator", systemImage: "play.circle")
                }
                .tag(4)
        }
        .frame(width: 530, height: 460)
        .padding()
    }
}

public struct GeneralSettingsTab: View {
    @ObservedObject public var controller: DynamicIslandController
    
    public var body: some View {
        Form {
            Section(header: Text("Status & Behavior").font(.headline)) {
                Toggle("Enable Dynamic Island", isOn: $controller.isEnabled)
                
                Slider(
                    value: $controller.autoCollapseDelay,
                    in: 2.0...15.0,
                    step: 0.5
                ) {
                    Text("Auto-collapse delay: \(String(format: "%.1f", controller.autoCollapseDelay))s")
                }
            }
            
            Section(header: Text("Display Information").font(.headline)) {
                let info = controller.displayManager.currentNotchInfo
                HStack {
                    Text("Physical Notch Detected:")
                    Spacer()
                    Text(info.hasPhysicalNotch ? "Yes" : "Virtual Notch (Centered)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Notch Size:")
                    Spacer()
                    Text("\(Int(info.notchSize.width)) × \(Int(info.notchSize.height)) pt")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

public struct ActivitiesSettingsTab: View {
    @ObservedObject public var controller: DynamicIslandController
    
    public var body: some View {
        Form {
            Section(header: Text("Dynamic Island HUDs & Indicators").font(.headline)) {
                Toggle("Enable System HUDs", isOn: $controller.isHUDEnabled)
                
                Group {
                    Toggle("Show Volume HUD in Dynamic Island", isOn: $controller.isVolumeHUDEnabled)
                    Toggle("Show Brightness HUD in Dynamic Island", isOn: $controller.isBrightnessHUDEnabled)
                    Toggle("Show Battery & Low Battery Warning in Dynamic Island", isOn: $controller.isBatteryHUDEnabled)
                    Toggle("Show Do Not Disturb (Focus) in Dynamic Island", isOn: $controller.isFocusModeHUDEnabled)
                    Toggle("Show Caps Lock HUD in Dynamic Island", isOn: $controller.isCapsLockHUDEnabled)
                    Toggle("Show Unlock Symbol in Dynamic Island", isOn: $controller.isLockHUDEnabled)
                    Toggle("Show Caffeine (Keep Awake) in Dynamic Island", isOn: $controller.isCaffeineHUDEnabled)
                    
                    Divider()
                        .padding(.vertical, 2)
                    
                    Toggle("Hide Stock macOS Volume & Brightness Overlays", isOn: $controller.isNativeHUDSuppressionEnabled)
                        .onChange(of: controller.isNativeHUDSuppressionEnabled) { enabled in
                            NativeHUDInterceptor.shared.setEnabled(enabled)
                        }
                }
                .padding(.leading, 16)
                .disabled(!controller.isHUDEnabled)
            }
            
            Section(header: Text("Other Activity Modules").font(.headline)) {
                Toggle("Music & Now Playing", isOn: $controller.isMusicEnabled)
                Toggle("Timer & Countdown", isOn: $controller.isTimerEnabled)
                Toggle("Clipboard Monitor", isOn: $controller.isClipboardEnabled)
                Toggle("Live Weather & Air Quality Pill (Ambient)", isOn: $controller.isWeatherEnabled)
                    .onChange(of: controller.isWeatherEnabled) { enabled in
                        if enabled {
                            let act = WeatherActivity(weather: WeatherService.shared.currentWeather)
                            controller.activityManager.presentActivity(act)
                        } else {
                            controller.activityManager.removeActivity(id: "activity.weather")
                        }
                    }
            }
        }
        .padding()
    }
}

public struct PrivacySettingsTab: View {
    @ObservedObject public var controller: DynamicIslandController
    
    public var body: some View {
        Form {
            Section(header: Text("Privacy & Security").font(.headline)) {
                Toggle("Enable Local Clipboard Monitoring", isOn: $controller.isClipboardEnabled)
                
                Text("All Dynamic Island operations occur 100% locally on your Mac. No clipboard data, media info, or telemetry is ever uploaded.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("Accessibility Permissions (For Stock HUD Hiding)").font(.headline)) {
                HStack {
                    Image(systemName: NativeHUDInterceptor.shared.hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(NativeHUDInterceptor.shared.hasAccessibilityPermission ? .green : .orange)
                    
                    Text(NativeHUDInterceptor.shared.hasAccessibilityPermission ? "Accessibility Permission Granted" : "Accessibility Permission Required to Hide macOS Stock HUDs")
                        .font(.system(size: 12, weight: .medium))
                    
                    Spacer()
                    
                    if !NativeHUDInterceptor.shared.hasAccessibilityPermission {
                        Button("Grant Permission...") {
                            NativeHUDInterceptor.shared.requestAccessibilityPermission()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                Text("macOS requires Accessibility permissions to intercept hardware volume and brightness keys so the stock square overlay can be completely hidden.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

public struct NotchPetSettingsTab: View {
    @ObservedObject public var controller: DynamicIslandController
    @ObservedObject private var pet = NotchPetService.shared
    
    public var body: some View {
        Form {
            Section(header: Text("🐾 Notch Pet Companion").font(.headline)) {
                Toggle("Enable Animated Notch Pet", isOn: $pet.isEnabled)
                
                if pet.isEnabled {
                    Picker("Selected Pet Species", selection: $pet.species) {
                        ForEach(PetSpecies.allCases) { species in
                            Text(species.displayName).tag(species)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack(spacing: 16) {
                        VStack {
                            NotchPetRenderer(size: 38)
                                .frame(width: 60, height: 50)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            
                            Text(pet.species.displayName)
                                .font(.system(size: 11, weight: .bold))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Favorite Snack: \(pet.species.favoriteFood)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Button("🍖 Feed Snack") {
                                    pet.feedSnack()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                Button("✨ Pet / Trick") {
                                    pet.petCompanion()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section(header: Text("Reactions & Behaviors").font(.headline)) {
                Text("• Bobs head and wears DJ headphones when music plays")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Celebrates with colorful confetti when your timers or focus sessions finish")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Takes cozy naps with floating zZZ sleep bubbles during long idle times")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

public struct DebugSimulatorTab: View {
    @ObservedObject public var controller: DynamicIslandController
    
    public var body: some View {
        DebugControlView(controller: controller)
    }
}
