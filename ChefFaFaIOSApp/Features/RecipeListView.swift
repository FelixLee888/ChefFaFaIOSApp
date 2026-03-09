import Foundation
import SwiftUI

struct RecipeListView: View {
    @StateObject private var store = RecipeStore()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isLanguageDialogPresented = false
    private let contentLeadingInset: CGFloat = 8
    private let contentTrailingInset: CGFloat = 20
    private let cardCornerRadius: CGFloat = 22
    private let cardInnerPadding: CGFloat = 12

    #if targetEnvironment(simulator)
    private let isSimulator = true
    #else
    private let isSimulator = false
    #endif

    private var columns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [GridItem(.flexible(minimum: 0), spacing: 14)]
        }
        return [GridItem(.adaptive(minimum: 260), spacing: 14)]
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let scrollViewportWidth = max(proxy.size.width, 1)
                let contentWidth = max(scrollViewportWidth - contentLeadingInset - contentTrailingInset, 1)

                ZStack {
                    BrandTheme.pageGradient
                        .ignoresSafeArea()

                    backgroundOrbs

                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            heroSection
                            filtersSection
                            recipesSection
                        }
                        .frame(width: contentWidth, alignment: .leading)
                        .padding(.leading, contentLeadingInset)
                        .padding(.trailing, contentTrailingInset)
                        .padding(.bottom, 26)
                    }
                    .frame(width: scrollViewportWidth, alignment: .leading)
                    .clipped()
                    .refreshable {
                        await store.refreshFromWebsite(force: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle(store.siteMeta.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LocalizedRecipe.self) { recipe in
                RecipeDetailView(recipe: recipe, labels: store.labels)
            }
            .searchable(text: $store.searchText, prompt: store.labels.searchPlaceholder)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let logo = BundledAsset.image(forWebAssetPath: "fafa_icon.png") {
                        logo
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    languageButton
                }
            }
            .confirmationDialog(
                store.labels.language,
                isPresented: $isLanguageDialogPresented,
                titleVisibility: .visible
            ) {
                ForEach(AppLocale.allCases) { locale in
                    Button(locale.displayName) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.locale = locale
                        }
                    }
                }
            }
        }
    }

    private var languageButton: some View {
        Button {
            isLanguageDialogPresented = true
        } label: {
            Image(systemName: "globe")
                .foregroundStyle(BrandTheme.brand)
        }
        .accessibilityLabel(store.labels.language)
    }

    private var backgroundOrbs: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.835, blue: 0.725).opacity(0.55))
                .frame(width: 260, height: 260)
                .blur(radius: isSimulator ? 0 : 52)
                .offset(x: -150, y: -320)

            Circle()
                .fill(Color(red: 0.773, green: 0.925, blue: 0.894).opacity(0.5))
                .frame(width: 260, height: 260)
                .blur(radius: isSimulator ? 0 : 52)
                .offset(x: 170, y: -140)
        }
        .allowsHitTesting(false)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if horizontalSizeClass == .compact {
                VStack(alignment: .leading, spacing: 12) {
                    HeroMediaView()
                    heroTextContent
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    HeroMediaView()
                        .frame(width: 300)
                    heroTextContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(cardInnerPadding)
        .background(BrandTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(BrandTheme.line, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped(antialiased: true)
    }

    private var heroTextContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.labels.heroEyebrow)
                .font(.system(size: 11, weight: .heavy, design: .default))
                .tracking(1.8)
                .foregroundStyle(BrandTheme.accent)

            Text(store.labels.heroTitle)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .lineSpacing(4)
                .foregroundStyle(BrandTheme.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Text(store.labels.heroSubtitle)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.ink.opacity(0.8))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(store.resultCount) \(store.labels.recipesIndexed)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BrandTheme.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let lastSyncedDescription {
                Text(lastSyncedDescription)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(BrandTheme.muted.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var lastSyncedDescription: String? {
        guard let lastSyncedAt = store.lastSyncedAt else { return nil }
        var style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        style = style.locale(Locale(identifier: store.locale.rawValue))
        return "\(store.labels.lastSynced): \(lastSyncedAt.formatted(style))"
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            filterGroup(
                title: store.labels.cuisines,
                allLabel: store.allCuisineLabel,
                selected: store.selectedCuisineKey,
                options: store.cuisineOptions,
                action: store.selectCuisine
            )

            filterGroup(
                title: store.labels.types,
                allLabel: store.allTypeLabel,
                selected: store.selectedTypeKey,
                options: store.typeOptions,
                action: store.selectType
            )
        }
    }

    private func filterGroup(
        title: String,
        allLabel: String,
        selected: String,
        options: [FilterOption],
        action: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BrandTheme.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        let label = option.id == RecipeStore.allFilterValue ? allLabel : option.label
                        filterButton(title: label, value: option.id, selected: selected, action: action)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func filterButton(
        title: String,
        value: String,
        selected: String,
        action: @escaping (String) -> Void
    ) -> some View {
        Button(title) {
            action(value)
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.bold))
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(selected == value ? BrandTheme.brand : Color.white.opacity(0.8))
        .foregroundStyle(selected == value ? Color.white : BrandTheme.muted)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(BrandTheme.line, lineWidth: selected == value ? 0 : 1))
    }

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = store.loadError {
                Text(error)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(store.filteredRecipes) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeCard(recipe: recipe, labels: store.labels)
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.filteredRecipes.isEmpty {
                Text(store.labels.noResults)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.muted)
                    .padding(.top, 6)
            }
        }
    }
}

private struct RecipeCard: View {
    let recipe: LocalizedRecipe
    let labels: LocaleLabels

    #if targetEnvironment(simulator)
    private let isSimulator = true
    #else
    private let isSimulator = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecipeImageView(path: recipe.imagePath, cornerRadius: 14, height: 150)

            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(recipe.cuisine)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 6)
                    Text(recipe.type)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.cuisine)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(recipe.type)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(BrandTheme.muted)
            .textCase(.uppercase)

            Text(recipe.title)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(BrandTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(recipe.summary)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.ink.opacity(0.78))
                .lineLimit(3)

            Text("\(labels.total): \(recipe.totalTime)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(BrandTheme.accent)

            if let host = recipe.sourceHost {
                Text("\(labels.source): \(host)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BrandTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .truncationMode(.middle)
            }

            if !recipe.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recipe.tags.prefix(4), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.bold))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(BrandTheme.brandSoft)
                                .foregroundStyle(BrandTheme.brand)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(BrandTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BrandTheme.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isSimulator ? 0 : 0.08), radius: isSimulator ? 0 : 12, x: 0, y: isSimulator ? 0 : 6)
    }
}

#Preview {
    RecipeListView()
}
