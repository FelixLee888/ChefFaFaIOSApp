import SwiftUI

struct RecipeImageView: View {
    let path: String?
    var cornerRadius: CGFloat = 14
    var height: CGFloat = 180

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(BrandTheme.accentSoft.opacity(0.55))

            if let image = BundledAsset.image(forWebAssetPath: path) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(BrandTheme.brand.opacity(0.5))
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
}
