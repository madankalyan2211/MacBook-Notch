import SwiftUI

/// Renders the animated pixel companion corresponding to the selected PetSpecies and PetActionState
public struct NotchPetRenderer: View {
    @ObservedObject public var petService: NotchPetService = .shared
    public let size: CGFloat
    
    public init(size: CGFloat = 26) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Confetti Burst Layer when Celebrating
            if petService.currentState == .celebrating {
                ConfettiBurstView()
            }
            
            // Sleep zZZ Bubbles when Sleeping
            if petService.currentState == .sleeping {
                SleepingZzzView()
            }
            
            // Core Character Renderer
            VStack(spacing: 0) {
                switch petService.species {
                case .cat:
                    PixelCatView(state: petService.currentState, frame: petService.animationFrame)
                case .shiba:
                    PixelShibaView(state: petService.currentState, frame: petService.animationFrame)
                case .capybara:
                    PixelCapybaraView(state: petService.currentState, frame: petService.animationFrame)
                case .redPanda:
                    PixelRedPandaView(state: petService.currentState, frame: petService.animationFrame)
                case .penguin:
                    PixelPenguinView(state: petService.currentState, frame: petService.animationFrame)
                case .dino:
                    PixelDinoView(state: petService.currentState, frame: petService.animationFrame)
                }
            }
            .frame(width: size, height: size)
            .offset(x: petService.walkOffset)
            .animation(.easeInOut(duration: 0.2), value: petService.walkOffset)
            
            // Music Headphones Indicator when dancing
            if petService.currentState == .dancing {
                Image(systemName: "headphones")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.55))
                    .offset(y: -size * 0.38 + (petService.animationFrame % 2 == 0 ? -1 : 1))
            }
            
            // Eating snack item
            if petService.currentState == .eating {
                Text(petService.species.favoriteFood.components(separatedBy: " ").first ?? "🍬")
                    .font(.system(size: size * 0.45))
                    .offset(x: 10, y: 4 + (petService.animationFrame % 2 == 0 ? -2 : 0))
            }
        }
        .frame(width: size + 20, height: size + 10)
    }
}

// MARK: - Pixel Cat
private struct PixelCatView: View {
    let state: PetActionState
    let frame: Int
    
    var body: some View {
        ZStack {
            // Body & Head
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 1.0, green: 0.65, blue: 0.25)) // Orange Tabby
                .frame(width: 18, height: 14)
            
            // Ears
            HStack(spacing: 8) {
                Triangle()
                    .fill(Color(red: 0.95, green: 0.45, blue: 0.15))
                    .frame(width: 5, height: 5)
                Triangle()
                    .fill(Color(red: 0.95, green: 0.45, blue: 0.15))
                    .frame(width: 5, height: 5)
            }
            .offset(y: -8)
            
            // Eyes
            if state == .sleeping {
                HStack(spacing: 6) {
                    Text("-").font(.system(size: 8, weight: .bold)).foregroundColor(.black)
                    Text("-").font(.system(size: 8, weight: .bold)).foregroundColor(.black)
                }
                .offset(y: -1)
            } else {
                HStack(spacing: 6) {
                    Circle().fill(Color.black).frame(width: 2.5, height: 2.5)
                    Circle().fill(Color.black).frame(width: 2.5, height: 2.5)
                }
                .offset(y: -1)
            }
            
            // Whiskers & Nose
            Circle()
                .fill(Color(red: 1.0, green: 0.4, blue: 0.5))
                .frame(width: 2, height: 2)
                .offset(y: 2)
            
            // Tail Wagging
            Rectangle()
                .fill(Color(red: 0.95, green: 0.55, blue: 0.2))
                .frame(width: 3, height: 8)
                .rotationEffect(.degrees(Double(frame * 12 - 18)))
                .offset(x: 10, y: 1)
        }
        .offset(y: state == .dancing ? (frame % 2 == 0 ? -2 : 1) : 0)
    }
}

// MARK: - Pixel Shiba Inu
private struct PixelShibaView: View {
    let state: PetActionState
    let frame: Int
    
    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.88, green: 0.58, blue: 0.28)) // Golden Shiba
                .frame(width: 20, height: 15)
            
            // White Muzzle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .frame(width: 12, height: 8)
                .offset(y: 3)
            
            // Ears
            HStack(spacing: 10) {
                Triangle()
                    .fill(Color(red: 0.78, green: 0.45, blue: 0.20))
                    .frame(width: 6, height: 6)
                Triangle()
                    .fill(Color(red: 0.78, green: 0.45, blue: 0.20))
                    .frame(width: 6, height: 6)
            }
            .offset(y: -9)
            
            // Eyes & Nose
            HStack(spacing: 6) {
                Circle().fill(Color.black).frame(width: 2.5, height: 2.5)
                Circle().fill(Color.black).frame(width: 2.5, height: 2.5)
            }
            .offset(y: -1)
            
            Circle().fill(Color.black).frame(width: 2.5, height: 2.5).offset(y: 2)
            
            // Curled Tail
            Circle()
                .stroke(Color(red: 0.88, green: 0.58, blue: 0.28), lineWidth: 3)
                .frame(width: 6, height: 6)
                .offset(x: 11, y: -2 + (frame % 2 == 0 ? -1 : 1))
        }
        .offset(y: state == .dancing ? (frame % 2 == 0 ? -3 : 1) : 0)
    }
}

// MARK: - Pixel Capybara
private struct PixelCapybaraView: View {
    let state: PetActionState
    let frame: Int
    
    var body: some View {
        ZStack {
            // Solid chill blocky body
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(red: 0.55, green: 0.38, blue: 0.25)) // Warm Capy Brown
                .frame(width: 22, height: 16)
            
            // Big flat snout
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.42, green: 0.28, blue: 0.18))
                .frame(width: 11, height: 8)
                .offset(x: -6, y: 3)
            
            // Peaceful slit eyes
            HStack(spacing: 7) {
                Rectangle().fill(Color.black).frame(width: 3, height: 1.5)
                Rectangle().fill(Color.black).frame(width: 3, height: 1.5)
            }
            .offset(y: -1)
            
            // Yuzu Orange on Head
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.72, blue: 0.05))
                    .frame(width: 7, height: 7)
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 2, height: 2.5)
                    .offset(y: -4)
            }
            .offset(x: 2, y: -10)
        }
        .offset(y: state == .dancing ? (frame % 2 == 0 ? -1 : 0) : 0)
    }
}

// MARK: - Pixel Red Panda
private struct PixelRedPandaView: View {
    let state: PetActionState
    let frame: Int
    
    var body: some View {
        ZStack {
            // Fluffy Head & Body
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.85, green: 0.32, blue: 0.15)) // Rust Red
                .frame(width: 19, height: 15)
            
            // White Face Marks
            HStack(spacing: 10) {
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white).frame(width: 4, height: 4)
            }
            .offset(y: 1)
            
            // Eyes & Nose
            HStack(spacing: 5) {
                Circle().fill(Color.black).frame(width: 2, height: 2)
                Circle().fill(Color.black).frame(width: 2, height: 2)
            }
            .offset(y: 0)
            
            // Ringed Tail
            HStack(spacing: 1.5) {
                Rectangle().fill(Color(red: 0.85, green: 0.32, blue: 0.15)).frame(width: 3, height: 6)
                Rectangle().fill(Color(red: 0.95, green: 0.85, blue: 0.75)).frame(width: 2, height: 6)
                Rectangle().fill(Color(red: 0.85, green: 0.32, blue: 0.15)).frame(width: 3, height: 6)
            }
            .rotationEffect(.degrees(25 + Double(frame * 8)))
            .offset(x: 12, y: 2)
        }
        .offset(y: state == .dancing ? (frame % 2 == 0 ? -2 : 1) : 0)
    }
}

// MARK: - Pixel Penguin
private struct PixelPenguinView: View {
    let state: PetActionState
    let frame: Int
    
    var body: some View {
        ZStack {
            // Black Body
            Capsule()
                .fill(Color(red: 0.15, green: 0.15, blue: 0.18))
                .frame(width: 16, height: 18)
            
            // White Belly
            Capsule()
                .fill(Color.white)
                .frame(width: 10, height: 12)
                .offset(y: 2)
            
            // Eyes
            HStack(spacing: 5) {
                Circle().fill(Color.black).frame(width: 2, height: 2)
                Circle().fill(Color.black).frame(width: 2, height: 2)
            }
            .offset(y: -4)
            
            // Orange Beak
            Triangle()
                .fill(Color.orange)
                .frame(width: 4, height: 3)
                .offset(y: -1)
            
            // Orange Feet
            HStack(spacing: 6) {
                Circle().fill(Color.orange).frame(width: 4, height: 2.5)
                Circle().fill(Color.orange).frame(width: 4, height: 2.5)
            }
            .offset(y: 9 + (frame % 2 == 0 ? 1 : 0))
        }
        .offset(y: state == .dancing ? (frame % 2 == 0 ? -2 : 1) : 0)
    }
}

// MARK: - Pixel Dino
private struct PixelDinoView: View {
    let state: PetActionState
    let frame: Int
    
    var body: some View {
        ZStack {
            // Green Dino Body
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(red: 0.28, green: 0.78, blue: 0.42)) // Emerald Green
                .frame(width: 19, height: 15)
            
            // Back Spikes
            HStack(spacing: 3) {
                Triangle().fill(Color(red: 0.95, green: 0.45, blue: 0.25)).frame(width: 3, height: 4)
                Triangle().fill(Color(red: 0.95, green: 0.45, blue: 0.25)).frame(width: 3, height: 4)
                Triangle().fill(Color(red: 0.95, green: 0.45, blue: 0.25)).frame(width: 3, height: 4)
            }
            .offset(y: -9)
            
            // Eyes
            Circle().fill(Color.black).frame(width: 2.5, height: 2.5).offset(x: -4, y: -2)
            
            // Fire Puff when celebrating
            if state == .celebrating {
                Text("🔥").font(.system(size: 10)).offset(x: -12, y: -2)
            }
        }
        .offset(y: state == .dancing ? (frame % 2 == 0 ? -2 : 1) : 0)
    }
}

// MARK: - Animated Helper Views
private struct SleepingZzzView: View {
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 2) {
            Text("z")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.cyan.opacity(animate ? 0.9 : 0.2))
            Text("Z")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.cyan.opacity(animate ? 0.8 : 0.1))
            Text("Z")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.cyan.opacity(animate ? 0.9 : 0.3))
        }
        .offset(x: 14, y: animate ? -14 : -6)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

private struct ConfettiBurstView: View {
    let colors: [Color] = [.red, .yellow, .green, .cyan, .pink, .orange, .purple]
    
    var body: some View {
        ZStack {
            ForEach(0..<12) { i in
                Circle()
                    .fill(colors[i % colors.count])
                    .frame(width: 3.5, height: 3.5)
                    .offset(
                        x: CGFloat(cos(Double(i) * .pi / 6.0) * 18.0),
                        y: CGFloat(sin(Double(i) * .pi / 6.0) * 14.0)
                    )
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
