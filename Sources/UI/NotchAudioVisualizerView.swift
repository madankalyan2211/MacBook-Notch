import SwiftUI

/// Audio-reactive waveform visualizer that renders live pulsing equalizer waves along the notch contour
public struct NotchAudioVisualizerView: View {
    @ObservedObject public var visualizer = AudioVisualizerService.shared
    public let width: CGFloat
    public let height: CGFloat
    
    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
    public var body: some View {
        if visualizer.isEnabled && visualizer.overallIntensity > 0.01 {
            Group {
                switch visualizer.currentStyle {
                case .bottomContour:
                    BottomContourWave(amplitudes: visualizer.currentAmplitudes, width: width, height: height, theme: visualizer.currentTheme)
                case .dualWings:
                    DualWingEqualizer(amplitudes: visualizer.currentAmplitudes, width: width, height: height, theme: visualizer.currentTheme)
                case .neonGlow:
                    NeonGlowAura(intensity: visualizer.overallIntensity, width: width, height: height, theme: visualizer.currentTheme)
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity.animation(.easeInOut(duration: 0.35)))
        }
    }
}

/// Fluid multi-layer wave that pulses along the bottom contour of the dynamic island
private struct BottomContourWave: View {
    let amplitudes: [CGFloat]
    let width: CGFloat
    let height: CGFloat
    let theme: VisualizerTheme
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Layer 1: Diffused Glow Bloom
            WaveCurveShape(amplitudes: amplitudes, maxWaveHeight: 8.0)
                .fill(
                    LinearGradient(
                        colors: theme.gradientColors.map { $0.opacity(0.45) },
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 14)
                .blur(radius: 4)
                .offset(y: 4)
            
            // Layer 2: Vibrant Crisp Wave Ribbon
            WaveCurveShape(amplitudes: amplitudes, maxWaveHeight: 6.0)
                .stroke(
                    LinearGradient(
                        colors: theme.gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
                .frame(width: width, height: 10)
                .offset(y: 2)
            
            // Layer 3: Dynamic Micro Particles / Dots along peaks
            HStack(spacing: max(2, (width - 32) / CGFloat(amplitudes.count))) {
                ForEach(0..<amplitudes.count, id: \.self) { i in
                    let amp = amplitudes[i]
                    Circle()
                        .fill(theme.gradientColors[i % theme.gradientColors.count])
                        .frame(width: max(1.5, amp * 3.2), height: max(1.5, amp * 3.2))
                        .shadow(color: theme.gradientColors[i % theme.gradientColors.count].opacity(0.8), radius: 2)
                        .offset(y: -amp * 4.0)
                }
            }
            .frame(width: width - 24)
            .offset(y: 2)
        }
        .frame(width: width, height: height, alignment: .bottom)
    }
}

/// Symmetric multi-bar equalizer extending along the left and right wings
private struct DualWingEqualizer: View {
    let amplitudes: [CGFloat]
    let width: CGFloat
    let height: CGFloat
    let theme: VisualizerTheme
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Wing Bars (receding towards notch)
            HStack(spacing: 3.5) {
                ForEach(0..<8, id: \.self) { i in
                    let amp = amplitudes[7 - i]
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: theme.gradientColors,
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3.0, height: max(3.0, amp * (height * 0.55)))
                        .shadow(color: theme.gradientColors.first?.opacity(0.6) ?? .clear, radius: 2)
                }
            }
            .padding(.leading, 12)
            
            Spacer()
            
            // Right Wing Bars (pulsing outward from notch)
            HStack(spacing: 3.5) {
                ForEach(8..<16, id: \.self) { i in
                    let amp = amplitudes[i]
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: theme.gradientColors.reversed(),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3.0, height: max(3.0, amp * (height * 0.55)))
                        .shadow(color: theme.gradientColors.last?.opacity(0.6) ?? .clear, radius: 2)
                }
            }
            .padding(.trailing, 12)
        }
        .frame(width: width, height: height, alignment: .center)
    }
}

/// Ambient glowing aura that breathes around the perimeter
private struct NeonGlowAura: View {
    let intensity: CGFloat
    let width: CGFloat
    let height: CGFloat
    let theme: VisualizerTheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: theme.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: max(1.5, intensity * 3.5)
            )
            .blur(radius: max(3, intensity * 7))
            .opacity(Double(max(0.2, intensity * 0.85)))
            .frame(width: width + 6, height: height + 6)
    }
}

/// Custom Shape calculating smooth Bezier curves through amplitude points
private struct WaveCurveShape: Shape {
    let amplitudes: [CGFloat]
    let maxWaveHeight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard amplitudes.count > 1 else { return path }
        
        let step = rect.width / CGFloat(amplitudes.count - 1)
        let baseY = rect.maxY
        
        path.move(to: CGPoint(x: 0, y: baseY - (amplitudes[0] * maxWaveHeight)))
        
        for i in 1..<amplitudes.count {
            let p0 = CGPoint(x: CGFloat(i - 1) * step, y: baseY - (amplitudes[i - 1] * maxWaveHeight))
            let p1 = CGPoint(x: CGFloat(i) * step, y: baseY - (amplitudes[i] * maxWaveHeight))
            
            let mid = CGPoint(x: (p0.x + p1.x) / 2.0, y: (p0.y + p1.y) / 2.0)
            let controlPoint1 = CGPoint(x: (p0.x + mid.x) / 2.0, y: p0.y)
            let controlPoint2 = CGPoint(x: (mid.x + p1.x) / 2.0, y: p1.y)
            
            path.addCurve(to: mid, control1: controlPoint1, control2: controlPoint2)
            path.addLine(to: p1)
        }
        
        return path
    }
}
