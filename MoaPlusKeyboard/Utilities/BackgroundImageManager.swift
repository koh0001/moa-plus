import UIKit

/// Manages background images for keyboard theming
final class BackgroundImageManager {
    static let shared = BackgroundImageManager()

    /// Built-in background image identifiers
    enum BuiltInBackground: String, CaseIterable {
        case none
        case gradientDark
        case gradientLight
        case subtle

        var displayName: String {
            switch self {
            case .none:          return "없음"
            case .gradientDark:  return "다크 그라데이션"
            case .gradientLight: return "라이트 그라데이션"
            case .subtle:        return "은은한 패턴"
            }
        }
    }

    private let fileManager = FileManager.default

    private init() {}

    private func sanitizedFilename(_ id: String) -> String {
        id.replacingOccurrences(of: "/", with: "")
          .replacingOccurrences(of: "..", with: "")
    }

    /// Get the shared container URL for App Group
    private var sharedContainerURL: URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.moaki.keyboard")
    }

    /// Directory for user-selected background images
    private var backgroundImagesDirectory: URL? {
        guard let container = sharedContainerURL else { return nil }
        let dir = container.appendingPathComponent("BackgroundImages", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Save a user-selected image
    func saveUserImage(_ image: UIImage, withId id: String) -> Bool {
        guard let dir = backgroundImagesDirectory,
              let data = image.jpegData(compressionQuality: 0.8) else {
            return false
        }
        let fileURL = dir.appendingPathComponent("\(sanitizedFilename(id)).jpg")
        do {
            try data.write(to: fileURL)
            return true
        } catch {
            return false
        }
    }

    /// Load a user image by ID
    func loadUserImage(withId id: String) -> UIImage? {
        guard let dir = backgroundImagesDirectory else { return nil }
        let fileURL = dir.appendingPathComponent("\(sanitizedFilename(id)).jpg")
        return UIImage(contentsOfFile: fileURL.path)
    }

    /// Delete a user image
    func deleteUserImage(withId id: String) {
        guard let dir = backgroundImagesDirectory else { return }
        let fileURL = dir.appendingPathComponent("\(sanitizedFilename(id)).jpg")
        try? fileManager.removeItem(at: fileURL)
    }

    /// List all user image IDs
    func listUserImageIds() -> [String] {
        guard let dir = backgroundImagesDirectory,
              let files = try? fileManager.contentsOfDirectory(atPath: dir.path) else {
            return []
        }
        return files
            .filter { $0.hasSuffix(".jpg") }
            .map { String($0.dropLast(4)) }
    }

    /// Calculate suggested overlay opacity based on image brightness
    func suggestedOverlayOpacity(for image: UIImage) -> Double {
        // Simple heuristic: darker images need less overlay
        // This could be made smarter with actual brightness analysis
        return 0.3
    }
}
