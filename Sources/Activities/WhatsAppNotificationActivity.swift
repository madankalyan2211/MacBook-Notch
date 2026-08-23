import SwiftUI

/// Dynamic Island Activity for WhatsApp Message Notifications
public final class WhatsAppNotificationActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .whatsapp
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 7.0
    
    @Published public var message: WhatsAppMessage
    
    public var title: String { message.senderName }
    public var subtitle: String { message.messageText }
    public var iconName: String { "message.fill" }
    public var tintColor: Color { Color(red: 0.15, green: 0.83, blue: 0.40) } // WhatsApp emerald green
    public var progress: Double? { nil }
    
    public var compactPreferredWidth: CGFloat { 375 }
    public var expandedPreferredSize: CGSize { CGSize(width: 395, height: 145) }
    
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
                .frame(maxWidth: 120, alignment: .trailing)
            
            Circle()
                .fill(activity.tintColor)
                .frame(width: 6, height: 6)
        }
        .padding(.trailing, 8)
        .matchedGeometryIfAvailable(id: "whatsapp_trailing_\(activity.id)", in: namespace)
    }
}

public struct WhatsAppExpandedCardView: View {
    @ObservedObject public var activity: WhatsAppNotificationActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    private var message: WhatsAppMessage { activity.message }
    private let waGreen = Color(red: 0.15, green: 0.83, blue: 0.40)
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header Row: Avatar / Icon + Sender Name + Time + Dismiss X
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
                        
                        if message.isGroup, let grp = message.groupName {
                            Text("• \(grp)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    
                    Text("WhatsApp • \(message.timeFormatted)")
                        .font(.system(size: 10.5, weight: .regular, design: .rounded))
                        .foregroundColor(waGreen.opacity(0.9))
                }
                
                Spacer()
                
                // Dismiss "X" Button
                Button(action: {
                    WhatsAppNotificationService.shared.dismissMessage()
                    controller.activityManager.removeActivity(id: activity.id)
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
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Bottom Action Bar: Open in WhatsApp + Copy Text
            HStack(spacing: 10) {
                Button(action: {
                    WhatsAppNotificationService.shared.openWhatsApp()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Reply in WhatsApp")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.83, blue: 0.40), Color(red: 0.10, green: 0.65, blue: 0.32)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    WhatsAppNotificationService.shared.copyMessageText()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 10.5, weight: .medium))
                        Text("Copy Text")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
    }
}
