import XCTest
@testable import ChefFaFaIOSApp

final class RecipeTests: XCTestCase {
    func testLocalizedRecipeUsesTranslationContent() {
        let recipe = Recipe(
            title: "Base Title",
            slug: "unit-1",
            summary: "Base Summary",
            cuisine: "Chinese",
            type: "Dinner",
            prepTime: "10 min",
            cookTime: "15 min",
            totalTime: "25 min",
            servings: "2",
            ingredients: ["base ingredient"],
            instructions: ["base step"],
            tags: ["quick"],
            image: "/assets/recipe-images/example.jpg",
            sourceUrl: "https://example.com",
            googleDocUrl: "https://docs.google.com/document/d/example",
            sourceLanguage: "en",
            translations: [
                "ja": RecipeTranslation(
                    title: "翻訳タイトル",
                    summary: "翻訳サマリー",
                    ingredients: ["翻訳材料"],
                    instructions: ["翻訳手順"]
                )
            ]
        )

        let localized = LocalizedRecipe(recipe: recipe, locale: .ja)

        XCTAssertEqual(localized.title, "翻訳タイトル")
        XCTAssertEqual(localized.summary, "翻訳サマリー")
        XCTAssertEqual(localized.ingredients.first, "翻訳材料")
        XCTAssertEqual(localized.instructions.first, "翻訳手順")
    }

    func testSearchBlobContainsBaseAndLocalizedFields() {
        let recipe = Recipe(
            title: "Black Sesame Soup",
            slug: "unit-2",
            summary: "Rich and nutty dessert soup",
            cuisine: "Chinese",
            type: "Dessert",
            prepTime: "10 min",
            cookTime: "20 min",
            totalTime: "30 min",
            servings: "4",
            ingredients: ["black sesame"],
            instructions: ["blend and simmer"],
            tags: ["sweet"],
            image: nil,
            sourceUrl: nil,
            googleDocUrl: nil,
            sourceLanguage: "en",
            translations: nil
        )

        let localized = LocalizedRecipe(recipe: recipe, locale: .en)
        XCTAssertTrue(localized.searchBlob.contains("black sesame"))
        XCTAssertTrue(localized.searchBlob.contains("dessert"))
    }
}
