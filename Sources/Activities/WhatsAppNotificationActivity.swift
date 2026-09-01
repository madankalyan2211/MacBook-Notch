import SwiftUI

/// Dynamic Island Activity for WhatsApp Message Notifications
public final class WhatsAppNotificationActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .whatsapp
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 8.0
    
    @Published public var message: WhatsAppMessage
    
    public var title: String { message.senderName }
    public var subtitle: String { message.messageText }
    public var iconName: String { "message.fill" }
    public var tintColor: Color { Color(red: 0.15, green: 0.83, blue: 0.40) } // WhatsApp emerald green
    public var progress: Double? { nil }
    
    public var compactPreferredWidth: CGFloat {
        let nameCharCount = CGFloat(message.senderName.count)
        let textSnippetCount = CGFloat(min(message.messageText.count, 22))
        
        // Base hardware notch width is ~195pt.
        let leftWingRequired = (nameCharCount * 9.2) + 42.0
        let rightWingRequired = (textSnippetCount * 7.5) + 38.0
        let maxWing = max(leftWingRequired, rightWingRequired)
        
        // Symmetrical capsule expansion around the notch center
        let totalCalculated = 195.0 + (maxWing * 2.0)
        
        // Dynamic clamp between 390 pt and 620 pt
        return max(390.0, min(620.0, totalCalculated))
    }
    
    public var expandedPreferredSize: CGSize {
        let nameCharCount = CGFloat(message.senderName.count)
        let cardWidth = max(430.0, min(560.0, 390.0 + (nameCharCount * 6.0)))
        return CGSize(width: cardWidth, height: 172)
    }
    
    public init(message: WhatsAppMessage) {
        self.id = "activity.whatsapp.\(message.id)"
        self.message = message
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            WhatsAppCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            WhatsAppCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            WhatsAppExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
    
    public var minimalBubbleView: AnyView {
        AnyView(
            Image(systemName: "message.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tintColor)
        )
    }
}

public struct WhatsAppCompactLeadingView: View {
    @ObservedObject public var activity: WhatsAppNotificationActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "message.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(activity.tintColor)
            
            Text(activity.message.senderName)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, 8)
        .matchedGeometryIfAvailable(id: "whatsapp_leading_\(activity.id)", in: namespace)
    }
}

public struct WhatsAppCompactTrailingView: View {
    @ObservedObject public var activity: WhatsAppNotificationActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 5) {
            Text(activity.message.messageText)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: 160, alignment: .trailing)
            
            Circle()
                .fill(activity.tintColor)
                .frame(width: 6.5, height: 6.5)
        }
        .padding(.trailing, 8)
        .matchedGeometryIfAvailable(id: "whatsapp_trailing_\(activity.id)", in: namespace)
    }
}

public struct WhatsAppExpandedCardView: View {
    @ObservedObject public var activity: WhatsAppNotificationActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    @State private var replyText: String = ""
    @State private var isSending: Bool = false
    @State private var isSentSuccess: Bool = false
    @State private var successScale: CGFloat = 0.6
    @State private var successOpacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var glowOpacity: Double = 0
    @FocusState private var isFieldFocused: Bool
    
    private var message: WhatsAppMessage { activity.message }
    private let waGreen = Color(red: 0.15, green: 0.83, blue: 0.40)
    
    public var body: some View {
        VStack(spacing: 9) {
            // Header Row: Avatar Badge + Sender Name + Group info + Time + Dismiss X
            HStack(spacing: 9) {
                // WhatsApp Icon Badge
                ZStack {
                    Circle()
                        .fill(waGreen.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "message.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(waGreen)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(message.senderName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        if message.isGroup, let grp = message.groupName {
                            Text("• \(grp)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                    
                    Text("WhatsApp • \(message.timeFormatted)")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundColor(waGreen.opacity(0.9))
                }
                
                Spacer()
                
                // Dismiss "X" Button
                Button(action: {
                    dismissAndCollapse()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            // Message Bubble Content
            HStack {
                Text(message.messageText)
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Quick Reply Capsule Input Bar
            HStack(spacing: 8) {
                if isSentSuccess {
                    // Multi-step animated success banner
                    ZStack {
                        // Glow pulse behind
                        Capsule()
                            .fill(waGreen.opacity(0.08 * glowOpacity))
                            .blur(radius: 6)
                            .scaleEffect(1.0 + (glowOpacity * 0.06))
                        
                        HStack(spacing: 8) {
                            // Animated checkmark
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(waGreen)
                                .scaleEffect(checkmarkScale)
                                .shadow(color: waGreen.opacity(0.6), radius: 4)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Sent!")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(waGreen)
                                Text("Reply sent ✓")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(waGreen.opacity(0.75))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [waGreen.opacity(0.18), waGreen.opacity(0.10)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(waGreen.opacity(0.35 * glowOpacity), lineWidth: 1.5)
                        )
                    }
                    .scaleEffect(successScale)
                    .opacity(successOpacity)
                } else {
                    // Inline Text Field
                    HStack(spacing: 6) {
                        TextField("Reply to \(message.senderName)...", text: $replyText, onCommit: {
                            handleSendReply()
                        })
                        .focused($isFieldFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        
                        if !replyText.isEmpty {
                            Button(action: {
                                replyText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 6)
                        }
                    }
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isFieldFocused ? waGreen.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                    
                    // Send Button
                    Button(action: {
                        handleSendReply()
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.15, green: 0.83, blue: 0.40), Color(red: 0.10, green: 0.65, blue: 0.32)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: -0.5, y: 0.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
                }
            }
            .padding(.horizontal, 2)
            
            // Bottom Quick Links Row
            HStack(spacing: 8) {
                Button(action: {
                    WhatsAppNotificationService.shared.openWhatsApp()
                    dismissAndCollapse()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Open App")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.09))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    WhatsAppNotificationService.shared.copyMessageText()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 9.5, weight: .medium))
                        Text("Copy")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.09))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
                if let win = NSApp.windows.first(where: { $0 is DynamicIslandWindow }) {
                    win.makeKey()
                }
                self.isFieldFocused = true
            }
        }
    }
    
    private func handleSendReply() {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        
        isSending = true
        isFieldFocused = false
        replyText = ""
        
        // Send the message in background
        WhatsAppNotificationService.shared.sendReply(text: trimmed)
        
        // Step 1: Snap success banner into view
        isSentSuccess = true
        withAnimation(.spring(response: 0.30, dampingFraction: 0.60)) {
            successScale = 1.03
            successOpacity = 1.0
        }
        
        // Step 2: Animate checkmark pop-in and glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                checkmarkScale = 1.15
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                checkmarkScale = 1.0
            }
            withAnimation(.easeInOut(duration: 0.4)) {
                glowOpacity = 1.0
            }
        }
        
        // Step 3: Settle and slight scale settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.18)) {
                successScale = 1.0
            }
        }
        
        // Step 4: Fade out with a shimmer shrink, then collapse
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeIn(duration: 0.22)) {
                glowOpacity = 0
                successOpacity = 0.6
                successScale = 0.88
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            dismissAndCollapse()
        }
    }
    
    private func dismissAndCollapse() {
        isFieldFocused = false
        
        WhatsAppNotificationService.shared.dismissMessage()
        controller.activityManager.removeActivity(id: activity.id)
        
        // Gracefully morph to running activity (e.g. Music / Timer) or idle notch
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            if controller.activityManager.activeActivity != nil {
                controller.transition(to: .compact)
            } else {
                controller.transition(to: .idle)
            }
        }
    }
}
