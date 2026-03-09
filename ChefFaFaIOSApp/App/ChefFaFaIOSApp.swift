import SwiftUI

@main
struct ChefFaFaIOSApp: App {
    var body: some Scene {
        WindowGroup {
            RecipeListView()
                .tint(BrandTheme.brand)
        }
    }
}
