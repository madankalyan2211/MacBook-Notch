import SwiftUI

/// Represents the visual presentation modes of the Dynamic Island.
public enum IslandPresentationState: String, CaseIterable, Equatable {
    /// Attached to the notch with minimal idle dimensions
    case idle
    /// Slight expansion when the cursor approaches or hovers
    case peek
    /// Compact pill displaying active activity summary (leading/trailing)
    case compact
    /// Full interactive card presenting detailed activity controls
    case expanded
}

/// Represents the transition phase of the island animation engine.
public enum IslandTransitionPhase: Equatable {
    case stable
    case expanding(from: IslandPresentationState, to: IslandPresentationState)
    case collapsing(from: IslandPresentationState, to: IslandPresentationState)
    case activitySwitching(fromId: String?, toId: String)
    case interrupted(byPriority: ActivityPriority)
}

/// Represents the dimension configuration of the island for any state.
public struct IslandGeometry: Equatable {
    public var width: CGFloat
    public var height: CGFloat
    public var cornerRadius: CGFloat
    public var topOffset: CGFloat
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    
    public init(
        width: CGFloat = 160,
        height: CGFloat = 32,
        cornerRadius: CGFloat = 12,
        topOffset: CGFloat = 0,
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 6
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.topOffset = topOffset
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }
}
