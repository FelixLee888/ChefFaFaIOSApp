import Foundation

struct RecipePayload: Codable {
    let site: SiteMeta
    let recipes: [Recipe]
}

struct SiteMeta: Codable {
    let title: String
    let description: String
}

struct RecipeTranslation: Codable, Hashable {
    let title: String
    let summary: String
    let ingredients: [String]
    let instructions: [String]
}

struct Recipe: Identifiable, Codable, Hashable {
    let title: String
    let slug: String
    let summary: String
    let cuisine: String
    let type: String
    let prepTime: String
    let cookTime: String
    let totalTime: String
    let servings: String
    let ingredients: [String]
    let instructions: [String]
    let tags: [String]
    let image: String?
    let sourceUrl: String?
    let googleDocUrl: String?
    let sourceLanguage: String?
    let translations: [String: RecipeTranslation]?

    var id: String { slug }

    func localizedContent(for locale: AppLocale) -> RecipeContent {
        guard let translation = translations?[locale.rawValue] else {
            return .init(title: title, summary: summary, ingredients: ingredients, instructions: instructions)
        }

        return .init(
            title: translation.title,
            summary: translation.summary,
            ingredients: translation.ingredients,
            instructions: translation.instructions
        )
    }

    func localizedCuisine(for locale: AppLocale) -> String {
        guard let translated = Self.cuisineTranslations[cuisine]?[locale] else { return cuisine }
        return translated
    }

    func localizedType(for locale: AppLocale) -> String {
        guard let translated = Self.typeTranslations[type]?[locale] else { return type }
        return translated
    }

    func sourceHost() -> String? {
        guard let sourceUrl, !sourceUrl.isEmpty, let url = URL(string: sourceUrl), let host = url.host else {
            return nil
        }
        return host
    }
}

struct RecipeContent: Hashable {
    let title: String
    let summary: String
    let ingredients: [String]
    let instructions: [String]
}

struct LocalizedRecipe: Identifiable, Hashable {
    let recipe: Recipe
    let locale: AppLocale

    var id: String { recipe.id }
    var cuisineKey: String { recipe.cuisine }
    var typeKey: String { recipe.type }
    var title: String { content.title }
    var summary: String { content.summary }
    var ingredients: [String] { content.ingredients }
    var instructions: [String] { content.instructions }
    var cuisine: String { recipe.localizedCuisine(for: locale) }
    var type: String { recipe.localizedType(for: locale) }
    var prepTime: String { recipe.prepTime }
    var cookTime: String { recipe.cookTime }
    var totalTime: String { recipe.totalTime }
    var servings: String { recipe.servings }
    var tags: [String] { recipe.tags }
    var imagePath: String? { recipe.image }
    var sourceUrl: String? { recipe.sourceUrl?.isEmpty == true ? nil : recipe.sourceUrl }
    var googleDocUrl: String? { recipe.googleDocUrl?.isEmpty == true ? nil : recipe.googleDocUrl }
    var sourceHost: String? { recipe.sourceHost() }

    var searchBlob: String {
        [
            title,
            summary,
            recipe.title,
            recipe.summary,
            cuisine,
            type,
            recipe.cuisine,
            recipe.type,
            tags.joined(separator: " "),
            ingredients.joined(separator: " "),
            recipe.ingredients.joined(separator: " ")
        ]
        .joined(separator: " ")
        .normalizedSearch
    }

    private var content: RecipeContent {
        recipe.localizedContent(for: locale)
    }
}

private extension Recipe {
    static let cuisineTranslations: [String: [AppLocale: String]] = [
        "Filipino": [.zhHant: "菲律賓料理", .ja: "フィリピン料理"],
        "Italian": [.zhHant: "義式料理", .ja: "イタリア料理"],
        "Japanese": [.zhHant: "日式料理", .ja: "和食"],
        "Chinese": [.zhHant: "中式料理", .ja: "中華料理"],
        "Thai": [.zhHant: "泰式料理", .ja: "タイ料理"],
        "Korean": [.zhHant: "韓式料理", .ja: "韓国料理"],
        "Indian": [.zhHant: "印度料理", .ja: "インド料理"],
        "Mexican": [.zhHant: "墨西哥料理", .ja: "メキシコ料理"],
        "Mediterranean": [.zhHant: "地中海料理", .ja: "地中海料理"],
        "American": [.zhHant: "美式料理", .ja: "アメリカ料理"],
        "French": [.zhHant: "法式料理", .ja: "フランス料理"],
        "Global": [.zhHant: "國際風味", .ja: "グローバル"]
    ]

    static let typeTranslations: [String: [AppLocale: String]] = [
        "Breakfast": [.zhHant: "早餐", .ja: "朝食"],
        "Lunch": [.zhHant: "午餐", .ja: "ランチ"],
        "Dinner": [.zhHant: "晚餐", .ja: "ディナー"],
        "Dessert": [.zhHant: "甜點", .ja: "デザート"],
        "Snack": [.zhHant: "點心", .ja: "スナック"],
        "Appetizer": [.zhHant: "前菜", .ja: "前菜"],
        "Soup": [.zhHant: "湯品", .ja: "スープ"],
        "Salad": [.zhHant: "沙拉", .ja: "サラダ"],
        "Beverage": [.zhHant: "飲品", .ja: "ドリンク"],
        "Main Course": [.zhHant: "主菜", .ja: "メイン"]
    ]
}

extension String {
    var normalizedSearch: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
