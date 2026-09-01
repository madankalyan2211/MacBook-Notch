import SwiftUI
import Combine

/// Centralized configuration for all Dynamic Island animations and spring physics.
public final class IslandAnimationConfiguration: ObservableObject {
    public static let shared = IslandAnimationConfiguration()
    
    // MARK: - Speed Multiplier for Motion Debugging & Tuning
    @Published public var speedMultiplier: Double = 1.0 // 1.0 = normal, 0.25 = slow-mo
    
    // MARK: - Base Spring Parameters (Tuned for Apple Dynamic Island & Notchy Physics)
    @Published public var expansionResponse: Double = 0.32
    @Published public var expansionDamping: Double = 0.74
    
    @Published public var collapseResponse: Double = 0.30
    @Published public var collapseDamping: Double = 0.86
    
    @Published public var snapResponse: Double = 0.22
    @Published public var snapDamping: Double = 0.72
    
    @Published public var hoverResponse: Double = 0.22
    @Published public var hoverDamping: Double = 0.78
    
    @Published public var pressResponse: Double = 0.14
    @Published public var pressDamping: Double = 0.60
    
    @Published public var contentResponse: Double = 0.22
    @Published public var contentDamping: Double = 0.84
    
    private init() {}
    
    // MARK: - Computed Animations Scaled by Speed Multiplier
    
    public var expansionSpring: Animation {
        .spring(
            response: expansionResponse / speedMultiplier,
            dampingFraction: expansionDamping,
            blendDuration: 0.15 / speedMultiplier
        )
    }
    
    public var collapseSpring: Animation {
        .spring(
            response: collapseResponse / speedMultiplier,
            dampingFraction: collapseDamping,
            blendDuration: 0.16 / speedMultiplier
        )
    }
    
    public var snapSpring: Animation {
        .spring(
            response: snapResponse / speedMultiplier,
            dampingFraction: snapDamping,
            blendDuration: 0.10 / speedMultiplier
        )
    }
    
    public var hoverSpring: Animation {
        .spring(
            response: hoverResponse / speedMultiplier,
            dampingFraction: hoverDamping,
            blendDuration: 0.10 / speedMultiplier
        )
    }
    
    public var pressSpring: Animation {
        .spring(
            response: pressResponse / speedMultiplier,
            dampingFraction: pressDamping,
            blendDuration: 0.05 / speedMultiplier
        )
    }
    
    public var contentSpring: Animation {
        .spring(
            response: contentResponse / speedMultiplier,
            dampingFraction: contentDamping,
            blendDuration: 0.12 / speedMultiplier
        )
    }
}

/// Dynamic Island geometry and animation coordinator.
public final class AnimationEngine {
    public static let shared = AnimationEngine()
    public let config = IslandAnimationConfiguration.shared
    
    public var morphSpring: Animation { config.expansionSpring }
    public var collapseSpring: Animation { config.collapseSpring }
    public var snapSpring: Animation { config.snapSpring }
    public var hoverSpring: Animation { config.hoverSpring }
    public var pressSpring: Animation { config.pressSpring }
    public var contentSpring: Animation { config.contentSpring }
    
    private init() {}
    
    // MARK: - Precise Geometry Calculation (Locked to Top Bezel)
    
    public func targetGeometry(
        for state: IslandPresentationState,
        notchSize: CGSize,
        activity: (any DynamicIslandActivity)?,
        isHovered: Bool = false
    ) -> IslandGeometry {
        let baseNotchWidth = max(notchSize.width, 150)
        let baseNotchHeight = max(notchSize.height, 32)
        
        switch state {
        case .idle:
            if isHovered {
                return IslandGeometry(
                    width: baseNotchWidth + 20,
                    height: baseNotchHeight,
                    cornerRadius: 12.5,
                    topOffset: 0,
                    horizontalPadding: 12,
                    verticalPadding: 4
                )
            } else {
                return IslandGeometry(
                    width: baseNotchWidth,
                    height: baseNotchHeight,
                    cornerRadius: 11,
                    topOffset: 0,
                    horizontalPadding: 10,
                    verticalPadding: 4
                )
            }
            
        case .peek:
            return IslandGeometry(
                width: max(baseNotchWidth + 26, 190),
                height: max(baseNotchHeight, 30.0),
                cornerRadius: 12.0,
                topOffset: 0,
                horizontalPadding: 12,
                verticalPadding: 3
            )
            
        case .compact:
            let baseCompactWidth = baseNotchWidth + 63
            let activityWidth = activity?.compactPreferredWidth ?? baseCompactWidth
            let targetWidth = max(baseCompactWidth, activityWidth)
            return IslandGeometry(
                width: targetWidth,
                height: max(baseNotchHeight + 1.0, 31.0),
                cornerRadius: 12.0,
                topOffset: 0,
                horizontalPadding: 4,
                verticalPadding: 2
            )
            
        case .expanded:
            let expWidth = activity?.expandedPreferredSize.width ?? 390
            let expContentHeight = activity?.expandedPreferredSize.height ?? 145
            let expTotalHeight = expContentHeight + baseNotchHeight
            return IslandGeometry(
                width: expWidth,
                height: expTotalHeight,
                cornerRadius: 22,
                topOffset: 0,
                horizontalPadding: 18,
                verticalPadding: 8
            )
        }
    }
}
