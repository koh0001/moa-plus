import UIKit
import ImageIO

/// Manages background images for keyboard theming
final class BackgroundImageManager {
    static let shared = BackgroundImageManager()

    /// Longest-edge cap, in pixels, for background images.
    ///
    /// The keyboard extension runs under a hard memory limit (~30-60MB) and is
    /// the first thing iOS kills under pressure — a killed extension reads to
    /// the user as a frozen keyboard. A picked photo is decoded *uncompressed*:
    /// a 12MP shot (4032x3024) costs ~48MB in ARGB, blowing the budget on its
    /// own, and the risk peaks exactly when the host app is itself loading a
    /// photo. 1536 covers the largest keyboard (iPad landscape @2x) after
    /// aspect-fill while costing at most ~9MB.
    static let maxBackgroundPixelSize: CGFloat = 1536

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

    /// Downscale so the longest edge is at most `maxBackgroundPixelSize`.
    /// Returns the original when it already fits. Works in *pixels*, not
    /// points — `image.size` is in points, so `scale` must be folded in or a
    /// 3x image would be stored 3x larger than intended.
    static func downscaled(_ image: UIImage, maxPixelSize: CGFloat = maxBackgroundPixelSize) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxPixelSize, longest > 0 else { return image }

        let ratio = maxPixelSize / longest
        let targetPixels = CGSize(width: (pixelWidth * ratio).rounded(),
                                  height: (pixelHeight * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1          // target size is already in pixels
        format.opaque = true      // backgrounds are fully covered; skips the alpha channel
        return UIGraphicsImageRenderer(size: targetPixels, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetPixels))
        }
    }

    /// Save a user-selected image, downscaled first so neither the host app nor
    /// the keyboard extension ever decodes a full-resolution photo.
    func saveUserImage(_ image: UIImage, withId id: String) -> Bool {
        guard let dir = backgroundImagesDirectory,
              let data = Self.downscaled(image).jpegData(compressionQuality: 0.8) else {
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

    /// Load a user image by ID, decoded straight to a bounded size.
    ///
    /// Uses ImageIO thumbnailing rather than `UIImage(contentsOfFile:)` so the
    /// full-resolution bitmap is **never** materialised — the decoder scales
    /// while reading. This matters for images written before the save path
    /// started downscaling: those files are still full-resolution on disk, and
    /// the keyboard extension is where decoding them is fatal.
    /// Falls back to a plain load if ImageIO cannot handle the file.
    func loadUserImage(withId id: String) -> UIImage? {
        guard let dir = backgroundImagesDirectory else { return nil }
        let fileURL = dir.appendingPathComponent("\(sanitizedFilename(id)).jpg")

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        if let source = CGImageSourceCreateWithURL(fileURL as CFURL, sourceOptions) {
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: Self.maxBackgroundPixelSize
            ] as CFDictionary
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) {
                return UIImage(cgImage: cgImage)
            }
        }
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
