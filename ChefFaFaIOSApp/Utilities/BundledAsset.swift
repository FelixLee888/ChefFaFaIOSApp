import Foundation
import SwiftUI
import UIKit

enum BundledAsset {
    private static let webAssetsRoot = "WebAssets"
    private static let imageCache = NSCache<NSString, UIImage>()

    static func image(forWebAssetPath path: String?) -> Image? {
        guard let uiImage = uiImage(forWebAssetPath: path) else { return nil }
        return Image(uiImage: uiImage)
    }

    static func uiImage(forWebAssetPath path: String?) -> UIImage? {
        guard let path else { return nil }
        let cacheKey = NSString(string: path)
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        guard let url = url(forWebAssetPath: path),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }

        imageCache.setObject(image, forKey: cacheKey)
        return image
    }

    static func url(fileName: String) -> URL? {
        url(forWebAssetPath: fileName)
    }

    static func url(forWebAssetPath path: String) -> URL? {
        let normalized = normalize(path: path)
        guard !normalized.isEmpty else { return nil }

        let filename = (normalized as NSString).lastPathComponent
        let ext = (filename as NSString).pathExtension
        let name = (filename as NSString).deletingPathExtension
        let relativeDir = (normalized as NSString).deletingLastPathComponent
        let resourceExt = ext.isEmpty ? nil : ext
        let bundle = Bundle.main

        let candidateSubdirs: [String?] = [
            relativeDir == "." ? webAssetsRoot : "\(webAssetsRoot)/\(relativeDir)",
            relativeDir == "." ? nil : relativeDir,
            nil
        ]

        for subdir in candidateSubdirs {
            if let url = bundle.url(forResource: name, withExtension: resourceExt, subdirectory: subdir) {
                return url
            }
        }

        return nil
    }

    private static func normalize(path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("/assets/") {
            return String(trimmed.dropFirst("/assets/".count))
        }
        if trimmed.hasPrefix("assets/") {
            return String(trimmed.dropFirst("assets/".count))
        }
        return trimmed
    }
}
