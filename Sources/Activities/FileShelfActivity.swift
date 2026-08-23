import SwiftUI

/// Dynamic Island Activity for the Notch Drop Shelf and AirDrop Radar
public final class FileShelfActivity: DynamicIslandActivity, ObservableObject {
    public let id: String = "activity.shelf"
    public let type: ActivityType = .shelf
    public let priority: ActivityPriority = .high
    public var timeoutDuration: TimeInterval? = nil
    
    @Published public var files: [ShelvedFileItem]
    
    public var title: String { "\(files.count) Shelved \(files.count == 1 ? "File" : "Files")" }
    public var subtitle: String { "AirDrop & Stash" }
    public var iconName: String { "folder.fill" }
    public var tintColor: Color { Color(red: 0.0, green: 0.75, blue: 1.0) }
    public var progress: Double? { nil }
    
    public var compactPreferredWidth: CGFloat { 325 }
    public var expandedPreferredSize: CGSize { CGSize(width: 395, height: 165) }
    
    public init(files: [ShelvedFileItem] = []) {
        self.files = files
    }
    
    public func compactLeadingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            ShelfCompactLeadingView(activity: self, namespace: namespace)
        )
    }
    
    public func compactTrailingView(namespace: Namespace.ID?) -> AnyView {
        AnyView(
            ShelfCompactTrailingView(activity: self, namespace: namespace)
        )
    }
    
    public func expandedView(controller: DynamicIslandController, namespace: Namespace.ID?) -> AnyView {
        AnyView(
            ShelfExpandedCardView(activity: self, controller: controller, namespace: namespace)
        )
    }
    
    public var minimalBubbleView: AnyView {
        AnyView(
            Image(systemName: "folder.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tintColor)
        )
    }
}

public struct ShelfCompactLeadingView: View {
    @ObservedObject public var activity: FileShelfActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "folder.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(activity.tintColor)
            
            Text("\(activity.files.count) \(activity.files.count == 1 ? "File" : "Files")")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.leading, 8)
        .matchedGeometryIfAvailable(id: "shelf_leading_\(activity.id)", in: namespace)
    }
}

public struct ShelfCompactTrailingView: View {
    @ObservedObject public var activity: FileShelfActivity
    public let namespace: Namespace.ID?
    
    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "airdrop")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(activity.tintColor)
            
            Text("Shelf")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(activity.tintColor)
        }
        .padding(.trailing, 8)
        .matchedGeometryIfAvailable(id: "shelf_trailing_\(activity.id)", in: namespace)
    }
}

public struct ShelfExpandedCardView: View {
    @ObservedObject public var activity: FileShelfActivity
    public let controller: DynamicIslandController
    public let namespace: Namespace.ID?
    
    @ObservedObject private var shelfService = FileShelfService.shared
    
    public var body: some View {
        VStack(spacing: 9) {
            // Header Row: Title, File count, Clear button & X Close button
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "folder.fill.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(activity.tintColor)
                    
                    Text("Notch Shelf")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("(\(shelfService.files.count))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        shelfService.clearAll()
                        controller.activityManager.removeActivity(id: activity.id)
                        controller.transition(to: .idle)
                    }) {
                        Text("Clear Shelf")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    // Direct "X" Close Button
                    Button(action: {
                        controller.transition(to: .compact)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 22, height: 22)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Stashed File Cards Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(shelfService.files) { file in
                        ShelvedFileCard(file: file)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 60)
            
            // Bottom Action Bar: AirDrop All, Copy All
            HStack(spacing: 10) {
                Button(action: {
                    shelfService.airDropAllFiles()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "airdrop")
                            .font(.system(size: 12, weight: .bold))
                        Text("AirDrop All")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.65, blue: 1.0), Color(red: 0.0, green: 0.45, blue: 0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    shelfService.copyAllFilesToClipboard()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("Copy All")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Drag files off shelf anytime")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
    }
}

private struct ShelvedFileCard: View {
    let file: ShelvedFileItem
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Icon / Thumbnail
            if let thumb = file.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(nsImage: file.fileIcon)
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            
            // Name & Size
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 80, alignment: .leading)
                
                Text(file.fileSizeString)
                    .font(.system(size: 9.5, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            
            // Quick Actions (AirDrop, Reveal, Remove)
            VStack(spacing: 3) {
                Button(action: {
                    FileShelfService.shared.airDropSingleFile(url: file.url)
                }) {
                    Image(systemName: "airdrop")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color(red: 0.0, green: 0.75, blue: 1.0))
                        .frame(width: 16, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    FileShelfService.shared.revealInFinder(url: file.url)
                }) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 16, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Remove File "X" Button
                Button(action: {
                    FileShelfService.shared.removeFile(id: file.id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .frame(width: 16, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color.white.opacity(isHovered ? 0.14 : 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered = $0 }
        // Drag back out of the shelf
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
    }
}
