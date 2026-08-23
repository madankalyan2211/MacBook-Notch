import Foundation
import SwiftUI
import Combine
import AVFoundation

public enum PetSpecies: String, CaseIterable, Identifiable, Sendable {
    case cat = "Cat"
    case shiba = "Shiba"
    case capybara = "Capybara"
    case redPanda = "Red Panda"
    case penguin = "Penguin"
    case dino = "Dino"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .cat: return "🐱 Pixel Kitty"
        case .shiba: return "🐕 Shiba Inu"
        case .capybara: return "🦫 Chill Capybara"
        case .redPanda: return "🐼 Red Panda"
        case .penguin: return "🐧 Pixel Penguin"
        case .dino: return "🦖 Tamagotchi Dino"
        }
    }
    
    public var favoriteFood: String {
        switch self {
        case .cat: return "🐟 Fish"
        case .shiba: return "🍖 Bone"
        case .capybara: return "🍊 Yuzu Orange"
        case .redPanda: return "🎋 Bamboo"
        case .penguin: return "🦐 Shrimp"
        case .dino: return "🥩 Steak"
        }
    }
    
    public var foodIcon: String {
        switch self {
        case .cat: return "fish.fill"
        case .shiba: return "bone.fill"
        case .capybara: return "circle.fill"
        case .redPanda: return "leaf.fill"
        case .penguin: return "drop.fill"
        case .dino: return "flame.fill"
        }
    }
}

public enum PetActionState: Equatable, Sendable {
    case sleeping
    case idleSitting
    case walking(direction: Int) // -1 left, 1 right
    case dancing
    case eating
    case celebrating
}

/// Service managing Notch Pet state, animations, behaviors, and reactions
public final class NotchPetService: ObservableObject {
    public static let shared = NotchPetService()
    
    @Published public var isEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "macbooknotch.pet.enabled")
            onStateUpdated?()
        }
    }
    
    @Published public var species: PetSpecies = .cat {
        didSet {
            UserDefaults.standard.set(species.rawValue, forKey: "macbooknotch.pet.species")
            onStateUpdated?()
        }
    }
    
    @Published public private(set) var currentState: PetActionState = .idleSitting
    @Published public private(set) var happiness: Int = 85 // 0-100
    @Published public private(set) var hunger: Int = 30 // 0-100 (100 = full)
    @Published public private(set) var walkOffset: CGFloat = 0 // -40 to +40
    @Published public private(set) var animationFrame: Int = 0
    
    public var onStateUpdated: (() -> Void)?
    
    private var behaviorTimer: Timer?
    private var animTimer: Timer?
    private var idleCount: Int = 0
    private var isMusicActive: Bool = false
    
    private init() {
        let storedEnabled = UserDefaults.standard.object(forKey: "macbooknotch.pet.enabled") as? Bool ?? true
        self.isEnabled = storedEnabled
        
        if let storedSpeciesStr = UserDefaults.standard.string(forKey: "macbooknotch.pet.species"),
           let storedSpecies = PetSpecies(rawValue: storedSpeciesStr) {
            self.species = storedSpecies
        }
        
        startAnimationLoops()
    }
    
    private func startAnimationLoops() {
        // Fast 0.2s animation ticker for frame steps (walking, dancing, tail wagging)
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { [weak self] _ in
            guard let self = self, self.isEnabled else { return }
            self.animationFrame = (self.animationFrame + 1) % 4
            
            // Handle walk movement if walking
            if case .walking(let dir) = self.currentState {
                let step: CGFloat = CGFloat(dir) * 4.0
                let newOffset = self.walkOffset + step
                if abs(newOffset) > 42 {
                    self.currentState = .walking(direction: -dir)
                } else {
                    self.walkOffset = newOffset
                }
            }
        }
        
        // Behavior state decider every 6 seconds
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isEnabled else { return }
            self.decideNextBehavior()
        }
    }
    
    private func decideNextBehavior() {
        // If celebrating or eating, don't interrupt until complete
        if currentState == .celebrating || currentState == .eating {
            return
        }
        
        if isMusicActive {
            currentState = .dancing
            return
        }
        
        idleCount += 1
        
        // After 4 ticks (~24s) of idle, go to sleep
        if idleCount >= 4 {
            currentState = .sleeping
            return
        }
        
        let randomChoice = Int.random(in: 0...10)
        if randomChoice < 4 {
            currentState = .idleSitting
        } else if randomChoice < 8 {
            let dir = Bool.random() ? 1 : -1
            currentState = .walking(direction: dir)
        } else {
            currentState = .idleSitting
        }
    }
    
    public func setMusicActive(_ active: Bool) {
        self.isMusicActive = active
        if active {
            self.currentState = .dancing
            self.idleCount = 0
        } else {
            if self.currentState == .dancing {
                self.currentState = .idleSitting
            }
        }
    }
    
    public func celebrate() {
        self.currentState = .celebrating
        self.happiness = min(100, self.happiness + 20)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if self.currentState == .celebrating {
                self.currentState = self.isMusicActive ? .dancing : .idleSitting
            }
        }
    }
    
    public func feedSnack() {
        self.currentState = .eating
        self.hunger = min(100, self.hunger + 35)
        self.happiness = min(100, self.happiness + 15)
        self.idleCount = 0
        
        // Play subtle feeding sound
        NSSound.beep()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            self.currentState = .celebrating
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self = self else { return }
                self.currentState = self.isMusicActive ? .dancing : .idleSitting
            }
        }
    }
    
    public func petCompanion() {
        self.happiness = min(100, self.happiness + 10)
        self.idleCount = 0
        if currentState == .sleeping {
            currentState = .idleSitting
        } else {
            currentState = .celebrating
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                self.currentState = self.isMusicActive ? .dancing : .idleSitting
            }
        }
    }
}
