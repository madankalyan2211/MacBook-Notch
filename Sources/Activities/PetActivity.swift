import SwiftUI

/// Dynamic Island Activity for the Animated Notch Pet Companion
public final class PetActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .pet
    public let priority: ActivityPriority = .ambient
    public var timeoutDuration: TimeInterval? = nil
    
    @ObservedObject public var petService: NotchPetService = .shared
    
    public var title: String { petService.species.displayName }
    public var subtitle: String { "Happiness \(petService.happiness)%" }
    public var iconName: String { "pawprint.fill" }
    public var tintColor: Color { Color(red: 1.0, green: 0.65, blue: 0.25) }
    public var progress: Double? { Double(petService.happiness) / 100.0 }
    
    public var compactPreferredWidth: CGFloat { 275 }
    public var expandedPreferredSize: CGSize { CGSize(width: 375, height: 155) }
    
    public init(id: String = "activity.pet") {
        self.id = id
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            PetCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            PetCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            PetExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
    
    public var minimalBubbleView: AnyView {
        AnyView(
            NotchPetRenderer(size: 20)
        )
    }
}

public struct PetCompactLeadingView: View {
    @ObservedObject public var activity: PetActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 5) {
            NotchPetRenderer(size: 22)
                .matchedGeometryIfAvailable(id: "pet_char_\(activity.id)", in: namespace)
        }
        .padding(.leading, 6)
    }
}

public struct PetCompactTrailingView: View {
    @ObservedObject public var activity: PetActivity
    public let namespace: Namespace.ID?
    
    private var stateLabel: String {
        switch activity.petService.currentState {
        case .sleeping: return "zZZ"
        case .dancing: return "🎶 Vibing"
        case .eating: return "Nom Nom"
        case .celebrating: return "✨ Yay!"
        case .walking: return "Exploring"
        case .idleSitting: return "❤️"
        }
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Text(stateLabel)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.35))
            
            Image(systemName: "pawprint.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.orange)
        }
        .padding(.trailing, 8)
        .matchedGeometryIfAvailable(id: "pet_status_\(activity.id)", in: namespace)
    }
}

public struct PetExpandedCardView: View {
    @ObservedObject public var activity: PetActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    @ObservedObject private var pet = NotchPetService.shared
    
    public var body: some View {
        VStack(spacing: 10) {
            // Top Row: Animated Pet, Name, and Species Switcher
            HStack(spacing: 12) {
                NotchPetRenderer(size: 34)
                    .matchedGeometryIfAvailable(id: "pet_char_\(activity.id)", in: namespace)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(pet.species.displayName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Action Badge
                        Text(actionStatusText)
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    
                    Text("Your desktop companion on the notch")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Next Pet Switcher Button
                Button(action: cycleNextPet) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Switch")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            
            // Middle Row: Happiness & Hunger Bars
            HStack(spacing: 12) {
                PetStatBar(label: "❤️ Happiness", value: pet.happiness, color: .pink)
                PetStatBar(label: "🍖 Fullness", value: pet.hunger, color: .orange)
            }
            .padding(.horizontal, 6)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Bottom Action Controls: Feed, Pet, Do Trick
            HStack(spacing: 10) {
                PetActionButton(
                    icon: pet.species.foodIcon,
                    title: "Feed \(pet.species.favoriteFood.components(separatedBy: " ").first ?? "")",
                    color: Color(red: 0.35, green: 0.85, blue: 0.55)
                ) {
                    pet.feedSnack()
                }
                
                PetActionButton(
                    icon: "hand.tap.fill",
                    title: "Pet Me",
                    color: Color(red: 1.0, green: 0.55, blue: 0.75)
                ) {
                    pet.petCompanion()
                }
                
                PetActionButton(
                    icon: "sparkles",
                    title: "Do Trick",
                    color: Color(red: 1.0, green: 0.78, blue: 0.25)
                ) {
                    pet.celebrate()
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 4)
    }
    
    private var actionStatusText: String {
        switch pet.currentState {
        case .sleeping: return "Sleeping zZZ"
        case .dancing: return "Dancing to Music"
        case .eating: return "Eating Snack"
        case .celebrating: return "Party Time! ✨"
        case .walking: return "Exploring Notch"
        case .idleSitting: return "Happy & Cozy"
        }
    }
    
    private func cycleNextPet() {
        let all = PetSpecies.allCases
        if let idx = all.firstIndex(of: pet.species) {
            let nextIdx = (idx + 1) % all.count
            pet.species = all[nextIdx]
            pet.celebrate()
        }
    }
}

private struct PetStatBar: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(value)%")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(value) / 100.0))
                }
            }
            .frame(height: 5)
        }
    }
}

private struct PetActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(color.opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
