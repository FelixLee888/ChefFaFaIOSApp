import SwiftUI

struct RecipeDetailView: View {
    let recipe: LocalizedRecipe
    let labels: LocaleLabels

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RecipeImageView(path: recipe.imagePath, cornerRadius: 22, height: 240)

                    Text("\(recipe.cuisine) • \(recipe.type)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandTheme.accent)

                    Text(recipe.title)
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(BrandTheme.ink)
                        .lineSpacing(4)
                        .lineLimit(4)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(recipe.summary)
                        .font(.body)
                        .foregroundStyle(BrandTheme.ink.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)

                    sourceLinksSection
                    statsSection
                    tagsSection
                    ingredientsSection
                    instructionSection
                }
                .padding(14)
                .frame(width: max(proxy.size.width - 28, 1), alignment: .leading)
            }
        }
        .background(BrandTheme.pageGradient.ignoresSafeArea())
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var sourceLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let sourceUrl = recipe.sourceUrl, let url = URL(string: sourceUrl) {
                Link(destination: url) {
                    compactLinkRow(title: labels.source, host: url.host ?? sourceUrl)
                }
            }

            if let googleDocUrl = recipe.googleDocUrl, let url = URL(string: googleDocUrl) {
                Link(destination: url) {
                    compactLinkRow(title: labels.googleDoc, host: url.host ?? googleDocUrl)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BrandTheme.line, lineWidth: 1)
        )
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(label: labels.prep, value: recipe.prepTime)
            detailRow(label: labels.cook, value: recipe.cookTime)
            detailRow(label: labels.total, value: recipe.totalTime)
            detailRow(label: labels.servings, value: recipe.servings)
        }
        .padding(12)
        .background(Color.white.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BrandTheme.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !recipe.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recipe.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.bold))
                            .padding(.vertical, 5)
                            .padding(.horizontal, 9)
                            .background(BrandTheme.brandSoft)
                            .foregroundStyle(BrandTheme.brand)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(labels.ingredients)
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandTheme.ink)

            ForEach(recipe.ingredients, id: \.self) { ingredient in
                Text("• \(ingredient)")
                    .font(.body)
                    .foregroundStyle(BrandTheme.ink.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(labels.instructions)
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandTheme.ink)

            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                Text("\(index + 1). \(step)")
                    .font(.body)
                    .foregroundStyle(BrandTheme.ink.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(BrandTheme.muted)
            Spacer()
            Text(value.isEmpty ? "TBD" : value)
                .foregroundStyle(BrandTheme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .font(.subheadline)
    }

    private func compactLinkRow(title: String, host: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.footnote.weight(.bold))
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text(host)
                    .font(.footnote)
                    .foregroundStyle(BrandTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                Image(systemName: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.footnote.weight(.bold))
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right.square")
                        .font(.footnote.weight(.semibold))
                }

                Text(host)
                    .font(.footnote)
                    .foregroundStyle(BrandTheme.muted)
                    .lineLimit(3)
                    .truncationMode(.middle)
            }
        }
        .foregroundStyle(BrandTheme.brand)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(
            recipe: LocalizedRecipe(
                recipe: Recipe(
                    title: "Preview Recipe",
                    slug: "preview-recipe",
                    summary: "Preview summary",
                    cuisine: "Chinese",
                    type: "Dinner",
                    prepTime: "20 min",
                    cookTime: "25 min",
                    totalTime: "45 min",
                    servings: "2",
                    ingredients: ["Ingredient A", "Ingredient B"],
                    instructions: ["Step one", "Step two"],
                    tags: ["easy"],
                    image: nil,
                    sourceUrl: nil,
                    googleDocUrl: nil,
                    sourceLanguage: "en",
                    translations: nil
                ),
                locale: .en
            ),
            labels: AppLocale.en.labels
        )
    }
}
