import SwiftUI

struct RecipeImageView: View {
    let path: String?
    var cornerRadius: CGFloat = 14
    var height: CGFloat = 180

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(BrandTheme.accentSoft.opacity(0.55))

            if let bundled = BundledAsset.uiImage(forWebAssetPath: path) {
                Image(uiImage: bundled)
                    .resizable()
                    .scaledToFill()
            } else if let remoteURL = remoteImageURL(for: path) {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(height, 1))
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(BrandTheme.line.opacity(0.8), lineWidth: 1)
        )
    }

    private var placeholder: some View {
        Image(systemName: "fork.knife.circle.fill")
            .font(.system(size: 44))
            .foregroundStyle(BrandTheme.brand.opacity(0.5))
    }

    private func remoteImageURL(for path: String?) -> URL? {
        guard let path else { return nil }
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }

        if trimmed.hasPrefix("/Chief-Fafa-Recipe/") || trimmed.hasPrefix("/assets/") {
            return URL(string: "https://felixlee888.github.io\(trimmed)")
        }

        if trimmed.hasPrefix("assets/") {
            return URL(string: "https://felixlee888.github.io/Chief-Fafa-Recipe/\(trimmed)")
        }

        if trimmed.hasPrefix("recipe-images/") {
            return URL(string: "https://felixlee888.github.io/Chief-Fafa-Recipe/assets/\(trimmed)")
        }

        return nil
    }
}
