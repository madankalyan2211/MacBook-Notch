import SwiftUI
import AppKit

public final class ClipboardActivity: DynamicIslandActivity, ObservableObject {
    public let id: String
    public let type: ActivityType = .clipboard
    public let priority: ActivityPriority = .critical
    public var timeoutDuration: TimeInterval? = 2.5
    
    @Published public var title: String
    @Published public var subtitle: String
    @Published public var itemType: ClipboardItem.ItemType
    @Published public var rawContent: String
    
    public var iconName: String {
        switch itemType {
        case .url: return "link"
        case .hexColor: return "paintpalette.fill"
        case .image: return "photo.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.on.clipboard.fill"
        }
    }
    
    public var tintColor: Color {
        switch itemType {
        case .url: return Color(red: 0.25, green: 0.55, blue: 1.0)
        case .hexColor: return Color(red: 0.85, green: 0.35, blue: 0.95)
        case .image: return Color(red: 0.30, green: 0.85, blue: 0.45)
        case .code: return Color(red: 0.20, green: 0.80, blue: 0.90)
        case .text: return Color(red: 0.35, green: 0.75, blue: 1.0)
        }
    }
    
    public var typeLabel: String {
        switch itemType {
        case .url: return "Link"
        case .hexColor: return "Color"
        case .image: return "Image"
        case .code: return "Code"
        case .text: return "Text"
        }
    }
    
    public var compactPreferredWidth: CGFloat { 296 }
    public var expandedPreferredSize: CGSize { CGSize(width: 330, height: 62) }
    
    public init(
        id: String = "activity.clipboard",
        title: String = "Copied",
        subtitle: String = "Clipboard content",
        itemType: ClipboardItem.ItemType = .text(""),
        rawContent: String = ""
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.itemType = itemType
        self.rawContent = rawContent
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(tintColor.opacity(0.22))
                        .frame(width: 18, height: 18)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(tintColor)
                }
                .matchedGeometryIfAvailable(id: "clip_icon_\(id)", in: namespace)
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .matchedGeometryIfAvailable(id: "clip_title_\(id)", in: namespace)
            }
            .padding(.leading, 6)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            HStack(spacing: 6) {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 130, alignment: .trailing)
                
                Text(typeLabel)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(tintColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(tintColor.opacity(0.18))
                    .clipShape(Capsule())
            }
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            ClipboardExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
}

public struct ClipboardExpandedCardView: View {
    @ObservedObject public var activity: ClipboardActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(activity.tintColor.opacity(0.22))
                    .frame(width: 32, height: 32)
                
                Image(systemName: activity.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(activity.tintColor)
            }
            .matchedGeometryIfAvailable(id: "clip_icon_\(activity.id)", in: namespace)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Copied to Clipboard")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .matchedGeometryIfAvailable(id: "clip_title_\(activity.id)", in: namespace)
                    
                    Text(activity.typeLabel)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(activity.tintColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(activity.tintColor.opacity(0.18))
                        .clipShape(Capsule())
                }
                
                Text(activity.rawContent.isEmpty ? activity.subtitle : activity.rawContent)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer(minLength: 4)
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.25, green: 0.95, blue: 0.45))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
