import SwiftUI

/// Idle Island View: Represents the notch seamlessly integrated into macOS.
public struct IdleIslandView: View {
    public let isHovered: Bool
    @ObservedObject private var pet = NotchPetService.shared
    
    public var body: some View {
        HStack(spacing: 8) {
            if pet.isEnabled {
                NotchPetRenderer(size: 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else if isHovered {
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 4, height: 4)
                
                Text("Dynamic Island")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 4, height: 4)
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Compact Island View: Displays leading and trailing elements with tight Apple-like layout.
public struct CompactIslandView: View {
    public let activity: any DynamicIslandActivity
    public let namespace: Namespace.ID?
    
    public init(activity: any DynamicIslandActivity, namespace: Namespace.ID? = nil) {
        self.activity = activity
        self.namespace = namespace
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Leading Indicator (Left wing of the notch)
            activity.compactLeadingView(namespace: namespace)
                .frame(alignment: .leading)
            
            Spacer(minLength: 20)
            
            // Trailing Meter/Waveform (Right wing of the notch)
            activity.compactTrailingView(namespace: namespace)
                .frame(alignment: .trailing)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
