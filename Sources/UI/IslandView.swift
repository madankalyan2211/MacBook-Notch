import SwiftUI

/// Continuous Notch-Integrated Animatable Island Shape.
/// Flush and unrounded at the top display bezel (topRadius = 0), dynamically rounded at the bottom.
public struct ContinuousNotchIslandShape: Shape {
    public var bottomCornerRadius: CGFloat
    
    public var animatableData: CGFloat {
        get { bottomCornerRadius }
        set { bottomCornerRadius = newValue }
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let r = min(bottomCornerRadius, height, width / 2.0)
        
        // 1. Start top-left flush with display bezel
        path.move(to: CGPoint(x: 0, y: 0))
        
        // 2. Straight top edge along display bezel (zero rounding)
        path.addLine(to: CGPoint(x: width, y: 0))
        
        // 3. Right edge down to bottom curve
        path.addLine(to: CGPoint(x: width, y: height - r))
        
        // 4. Smooth continuous bottom-right corner curve
        path.addQuadCurve(
            to: CGPoint(x: width - r, y: height),
            control: CGPoint(x: width, y: height)
        )
        
        // 5. Bottom edge
        path.addLine(to: CGPoint(x: r, y: height))
        
        // 6. Smooth continuous bottom-left corner curve
        path.addQuadCurve(
            to: CGPoint(x: 0, y: height - r),
            control: CGPoint(x: 0, y: height)
        )
        
        // 7. Left edge back up to top-left
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        
        return path
    }
}

/// Dynamic Island Root Shell: Pure OLED Solid Black (Zero grey tint, stroke, or shadow halos)
public struct IslandView: View {
    @ObservedObject public var controller: DynamicIslandController
    @Namespace private var islandAnimationNamespace
    
    @State private var dragOffset: CGFloat = 0
    
    public init(controller: DynamicIslandController) {
        self.controller = controller
    }
    
    private var geometry: IslandGeometry {
        controller.currentGeometry
    }
    
    private var islandShape: ContinuousNotchIslandShape {
        ContinuousNotchIslandShape(bottomCornerRadius: geometry.cornerRadius)
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // 1. Main Island Living Shell (Always strictly centered over physical hardware notch)
            ZStack(alignment: .top) {
                islandShape
                    .fill(Color.black)
                
                // Active Island Content
                ActivityContentView(controller: controller, namespace: islandAnimationNamespace)
                    .padding(.horizontal, geometry.horizontalPadding)
                    .padding(.vertical, geometry.verticalPadding)
                    .frame(width: geometry.width, height: geometry.height)
                    .clipShape(islandShape)
                
                // Real-time Universal Audio Reactive Waveform Visualizer
                NotchAudioVisualizerView(width: geometry.width, height: geometry.height)
                    .clipShape(islandShape)
            }
            .frame(width: geometry.width, height: geometry.height)
            .contentShape(islandShape)
            .offset(x: dragOffset)
            .onHover { isHovering in
                controller.handleHover(isHovering: isHovering)
            }
            .onTapGesture {
                controller.handleIslandTap()
            }
            // Multi-Activity Trackpad & Mouse Swipe Gesture
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        if controller.state == .compact && controller.activityManager.activityStack.count > 1 {
                            dragOffset = value.translation.width * 0.4
                        }
                    }
                    .onEnded { value in
                        guard controller.state == .compact else { return }
                        let threshold: CGFloat = 16
                        if value.translation.width < -threshold {
                            controller.handleSwipeLeft()
                        } else if value.translation.width > threshold {
                            controller.handleSwipeRight()
                        }
                        withAnimation(controller.animationEngine.morphSpring) {
                            dragOffset = 0
                        }
                    }
            )
            
            // 2. Detached Secondary Bubble (Positioned to the right with 12pt clearance)
            if controller.state == .compact, let secondary = controller.activityManager.secondaryActivity {
                Button(action: {
                    controller.switchToSecondary()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                        
                        secondary.minimalBubbleView
                    }
                    .frame(width: geometry.height, height: geometry.height)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .offset(x: (geometry.width / 2.0) + (geometry.height / 2.0) + 12.0)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Animate all geometry properties in unison using the appropriate spring
        .animation(controller.state == .expanded ? controller.animationEngine.morphSpring : controller.animationEngine.collapseSpring, value: geometry.width)
        .animation(controller.state == .expanded ? controller.animationEngine.morphSpring : controller.animationEngine.collapseSpring, value: geometry.height)
        .animation(controller.state == .expanded ? controller.animationEngine.morphSpring : controller.animationEngine.collapseSpring, value: geometry.cornerRadius)
        .animation(controller.state == .expanded ? controller.animationEngine.morphSpring : controller.animationEngine.collapseSpring, value: controller.activityManager.secondaryActivity?.id)
    }
}
