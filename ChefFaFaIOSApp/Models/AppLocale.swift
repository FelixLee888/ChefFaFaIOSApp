import Foundation

enum AppLocale: String, CaseIterable, Identifiable, Codable {
    case en = "en"
    case zhHant = "zh-Hant"
    case ja = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en:
            return "English"
        case .zhHant:
            return "繁體中文"
        case .ja:
            return "日本語"
        }
    }

    var labels: LocaleLabels {
        switch self {
        case .en:
            return .init(
                heroEyebrow: "FAFA RECIPE ARCHIVE",
                heroTitle: "Find your next favorite meal in seconds.",
                heroSubtitle: "Search by title, ingredients, cuisine, or recipe type.",
                searchLabel: "Search recipes",
                searchPlaceholder: "Try: black sesame, adobo, pasta, soup",
                recipesIndexed: "recipes indexed",
                lastSynced: "Last synced",
                cuisines: "Cuisines",
                types: "Types",
                allCuisines: "All cuisines",
                allTypes: "All types",
                noResults: "No recipes match your current search. Try a different keyword or clear filters.",
                prep: "Prep",
                cook: "Cook",
                total: "Total",
                servings: "Servings",
                ingredients: "Ingredients",
                instructions: "Instructions",
                source: "Source",
                googleDoc: "Google Doc",
                language: "Language"
            )
        case .zhHant:
            return .init(
                heroEyebrow: "春田花花食譜庫",
                heroTitle: "快速找到下一道想做的料理。",
                heroSubtitle: "可依標題、食材、料理類型與餐別搜尋。",
                searchLabel: "搜尋食譜",
                searchPlaceholder: "例如：黑芝麻、蘿蔔糕、義大利麵、湯",
                recipesIndexed: "道食譜已建立索引",
                lastSynced: "上次同步",
                cuisines: "料理類型",
                types: "餐別",
                allCuisines: "全部料理",
                allTypes: "全部餐別",
                noResults: "目前沒有符合條件的食譜，請換個關鍵字或清除篩選。",
                prep: "準備",
                cook: "烹調",
                total: "總計",
                servings: "份量",
                ingredients: "材料",
                instructions: "做法",
                source: "原始頁面",
                googleDoc: "Google 文件",
                language: "語言"
            )
        case .ja:
            return .init(
                heroEyebrow: "エディトリアル レシピアーカイブ",
                heroTitle: "次に作りたい一皿をすぐに見つける。",
                heroSubtitle: "タイトル、食材、料理ジャンル、レシピタイプで検索。",
                searchLabel: "レシピを検索",
                searchPlaceholder: "例：黒ごま、アドボ、パスタ、スープ",
                recipesIndexed: "件のレシピを索引化",
                lastSynced: "最終同期",
                cuisines: "料理ジャンル",
                types: "レシピタイプ",
                allCuisines: "すべてのジャンル",
                allTypes: "すべてのタイプ",
                noResults: "一致するレシピがありません。キーワードを変えるかフィルターを解除してください。",
                prep: "下準備",
                cook: "調理",
                total: "合計",
                servings: "分量",
                ingredients: "材料",
                instructions: "作り方",
                source: "元ページ",
                googleDoc: "Google ドキュメント",
                language: "言語"
            )
        }
    }
}

struct LocaleLabels {
    let heroEyebrow: String
    let heroTitle: String
    let heroSubtitle: String
    let searchLabel: String
    let searchPlaceholder: String
    let recipesIndexed: String
    let lastSynced: String
    let cuisines: String
    let types: String
    let allCuisines: String
    let allTypes: String
    let noResults: String
    let prep: String
    let cook: String
    let total: String
    let servings: String
    let ingredients: String
    let instructions: String
    let source: String
    let googleDoc: String
    let language: String
}
