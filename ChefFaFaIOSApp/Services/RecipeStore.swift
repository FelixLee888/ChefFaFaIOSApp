import Foundation

struct FilterOption: Identifiable, Hashable {
    let id: String
    let label: String
}

enum RecipeSyncOutcome {
    case updated(RecipePayload)
    case unchanged
}

final class RemoteRecipeSyncClient {
    enum SyncError: LocalizedError {
        case invalidResponse(URL)
        case unexpectedStatus(Int, URL)
        case invalidPayload(URL)
        case noReachableEndpoint

        var errorDescription: String? {
            switch self {
            case .invalidResponse(let url):
                return "Invalid response while syncing recipes from \(url.absoluteString)."
            case .unexpectedStatus(let statusCode, let url):
                return "Recipe sync endpoint returned HTTP \(statusCode): \(url.absoluteString)"
            case .invalidPayload(let url):
                return "Recipe payload format is invalid at \(url.absoluteString)."
            case .noReachableEndpoint:
                return "No recipe sync endpoint is reachable."
            }
        }
    }

    private enum Keys {
        static let lastAttempt = "RecipeSync.lastAttemptAt"
        static let lastSynced = "RecipeSync.lastSyncedAt"
    }

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let cacheFileURL: URL
    private let endpoints: [URL]
    private let refreshCooldown: TimeInterval

    init(
        session: URLSession = .shared,
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        refreshCooldown: TimeInterval = 300,
        endpoints: [URL] = []
    ) {
        self.session = session
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.refreshCooldown = refreshCooldown
        self.endpoints = endpoints.isEmpty ? Self.defaultEndpoints : endpoints
        self.cacheFileURL = Self.resolveCacheFileURL(fileManager: fileManager)
    }

    func loadCachedPayload() -> RecipePayload? {
        guard let data = try? Data(contentsOf: cacheFileURL) else { return nil }
        return try? decoder.decode(RecipePayload.self, from: data)
    }

    func lastSyncedAt() -> Date? {
        userDefaults.object(forKey: Keys.lastSynced) as? Date
    }

    func refreshPayload(force: Bool = false) async throws -> RecipeSyncOutcome {
        guard !endpoints.isEmpty else { throw SyncError.noReachableEndpoint }
        if !force, !isRefreshDue() {
            return .unchanged
        }

        var lastError: Error?
        for endpoint in endpoints {
            do {
                let outcome = try await fetch(from: endpoint)
                markRefreshAttempt()
                markRefreshSuccess()
                return outcome
            } catch {
                lastError = error
            }
        }

        throw lastError ?? SyncError.noReachableEndpoint
    }

    private func fetch(from endpoint: URL) async throws -> RecipeSyncOutcome {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let endpointKey = encodedKey(for: endpoint)
        if let etag = userDefaults.string(forKey: "RecipeSync.etag.\(endpointKey)") {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let modifiedSince = userDefaults.string(forKey: "RecipeSync.lastModified.\(endpointKey)") {
            request.setValue(modifiedSince, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse(endpoint)
        }

        if http.statusCode == 304 {
            return .unchanged
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            throw SyncError.unexpectedStatus(http.statusCode, endpoint)
        }

        guard let payload = try await decodePayload(from: data, endpoint: endpoint) else {
            throw SyncError.invalidPayload(endpoint)
        }

        let cacheData = try JSONEncoder().encode(payload)
        try persistCache(cacheData)

        if let etag = http.value(forHTTPHeaderField: "ETag"), !etag.isEmpty {
            userDefaults.set(etag, forKey: "RecipeSync.etag.\(endpointKey)")
        }
        if let modified = http.value(forHTTPHeaderField: "Last-Modified"), !modified.isEmpty {
            userDefaults.set(modified, forKey: "RecipeSync.lastModified.\(endpointKey)")
        }

        return .updated(payload)
    }

    private func decodePayload(from data: Data, endpoint: URL) async throws -> RecipePayload? {
        if let payload = try? decoder.decode(RecipePayload.self, from: data) {
            return payload
        }

        return try await decodeEmbeddedWebsitePayload(from: data, endpoint: endpoint)
    }

    private func decodeEmbeddedWebsitePayload(from data: Data, endpoint: URL) async throws -> RecipePayload? {
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        guard let recipeDataJSON = matchGroup(
            in: html,
            pattern: #"<script id="recipe-data" type="application/json">([\s\S]*?)</script>"#
        ) else {
            return nil
        }

        guard let recipeData = recipeDataJSON.data(using: .utf8),
              let webRecipes = try? decoder.decode([EmbeddedWebRecipe].self, from: recipeData) else {
            return nil
        }

        let recipesBySlug = Dictionary(uniqueKeysWithValues: webRecipes.map { ($0.slug, $0) })
        let slugs = webRecipes.map(\.slug)
        let imageMap = imagePathBySlug(from: html)
        async let enDetailsTask = fetchRecipeDetails(locale: "en", slugs: slugs, basedOn: endpoint)
        async let zhHantDetailsTask = fetchRecipeDetails(locale: "zh-Hant", slugs: slugs, basedOn: endpoint)
        async let jaDetailsTask = fetchRecipeDetails(locale: "ja", slugs: slugs, basedOn: endpoint)

        let enDetails = await enDetailsTask
        let zhHantDetails = await zhHantDetailsTask
        let jaDetails = await jaDetailsTask

        let recipes = slugs.compactMap { slug -> Recipe? in
            guard let webRecipe = recipesBySlug[slug] else { return nil }
            let enDetail = enDetails[slug]
            let fallbackSource = localeRecipeURL(for: "en", slug: slug, basedOn: endpoint)?.absoluteString

            let baseTitle = fallbackValue(enDetail?.title, fallback: webRecipe.title)
            let baseSummary = fallbackValue(enDetail?.summary, fallback: webRecipe.summary ?? "")
            let baseCuisine = fallbackValue(enDetail?.cuisine, fallback: webRecipe.cuisine ?? "Global")
            let baseType = fallbackValue(enDetail?.type, fallback: webRecipe.type ?? "Main Course")
            let basePrepTime = fallbackValue(enDetail?.prepTime, fallback: "TBD")
            let baseCookTime = fallbackValue(enDetail?.cookTime, fallback: "TBD")
            let baseTotalTime = fallbackValue(enDetail?.totalTime, fallback: "TBD")
            let baseServings = fallbackValue(enDetail?.servings, fallback: "TBD")
            let baseIngredients: [String] = {
                if let ingredients = enDetail?.ingredients, !ingredients.isEmpty {
                    return ingredients
                }
                return webRecipe.ingredients ?? []
            }()
            let baseInstructions = enDetail?.instructions ?? []

            var translations: [String: RecipeTranslation] = [:]
            if let zhDetail = zhHantDetails[slug] {
                translations["zh-Hant"] = RecipeTranslation(
                    title: fallbackValue(zhDetail.title, fallback: baseTitle),
                    summary: fallbackValue(zhDetail.summary, fallback: baseSummary),
                    ingredients: zhDetail.ingredients.isEmpty ? baseIngredients : zhDetail.ingredients,
                    instructions: zhDetail.instructions
                )
            }
            if let jaDetail = jaDetails[slug] {
                translations["ja"] = RecipeTranslation(
                    title: fallbackValue(jaDetail.title, fallback: baseTitle),
                    summary: fallbackValue(jaDetail.summary, fallback: baseSummary),
                    ingredients: jaDetail.ingredients.isEmpty ? baseIngredients : jaDetail.ingredients,
                    instructions: jaDetail.instructions
                )
            }

            return Recipe(
                title: baseTitle,
                slug: slug,
                summary: baseSummary,
                cuisine: baseCuisine,
                type: baseType,
                prepTime: basePrepTime,
                cookTime: baseCookTime,
                totalTime: baseTotalTime,
                servings: baseServings,
                ingredients: baseIngredients,
                instructions: baseInstructions,
                tags: webRecipe.tags ?? [],
                image: enDetail?.image ?? imageMap[slug],
                sourceUrl: enDetail?.sourceUrl ?? fallbackSource,
                googleDocUrl: enDetail?.googleDocUrl,
                sourceLanguage: "en",
                translations: translations.isEmpty ? nil : translations
            )
        }

        if recipes.isEmpty {
            return nil
        }

        let siteTitle = matchGroup(in: html, pattern: #"<meta property="og:title" content="([^"]+)""#) ?? "Chef Fafa's Recipe"
        let siteDescription = matchGroup(in: html, pattern: #"<meta name="description" content="([^"]*)""#) ?? ""

        return RecipePayload(
            site: SiteMeta(
                title: htmlUnescaped(siteTitle),
                description: htmlUnescaped(siteDescription)
            ),
            recipes: recipes
        )
    }

    private func fetchRecipeDetails(locale: String, slugs: [String], basedOn endpoint: URL) async -> [String: WebRecipeDetail] {
        var result: [String: WebRecipeDetail] = [:]
        for slug in slugs {
            guard let url = localeRecipeURL(for: locale, slug: slug, basedOn: endpoint) else { continue }
            if let detail = await fetchRecipeDetail(at: url) {
                result[slug] = detail
            }
        }
        return result
    }

    private func fetchRecipeDetail(at url: URL) async -> WebRecipeDetail? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            return parseRecipeDetail(from: html)
        } catch {
            return nil
        }
    }

    private func parseRecipeDetail(from html: String) -> WebRecipeDetail? {
        guard let recipeJSON = matchGroup(in: html, pattern: #"<script type="application/ld\+json">([\s\S]*?)</script>"#),
              let recipeData = recipeJSON.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: recipeData) else {
            return nil
        }

        let dictionary: [String: Any]? = {
            if let dict = jsonObject as? [String: Any] {
                return dict
            }
            if let array = jsonObject as? [[String: Any]] {
                return array.first { fallbackValue(stringValue($0["@type"]), fallback: "") == "Recipe" } ?? array.first
            }
            return nil
        }()

        guard let dict = dictionary else { return nil }
        let links = sourceLinks(from: html)

        return WebRecipeDetail(
            title: stringValue(dict["name"]),
            summary: stringValue(dict["description"]),
            cuisine: stringValue(dict["recipeCuisine"]),
            type: stringValue(dict["recipeCategory"]),
            ingredients: normalizeList(stringArray(dict["recipeIngredient"])),
            instructions: normalizeList(instructionArray(dict["recipeInstructions"])),
            prepTime: stringValue(dict["prepTime"]),
            cookTime: stringValue(dict["cookTime"]),
            totalTime: stringValue(dict["totalTime"]),
            servings: stringValue(dict["recipeYield"]),
            image: firstURLString(dict["image"]),
            sourceUrl: links.sourceUrl,
            googleDocUrl: links.googleDocUrl
        )
    }

    private func sourceLinks(from html: String) -> (sourceUrl: String?, googleDocUrl: String?) {
        guard let section = matchGroup(in: html, pattern: #"<section class="recipe-source-links">([\s\S]*?)</section>"#),
              let regex = try? NSRegularExpression(pattern: #"href="([^"]+)""#, options: [.caseInsensitive]) else {
            return (nil, nil)
        }

        let range = NSRange(section.startIndex..., in: section)
        var links: [String] = []
        for match in regex.matches(in: section, options: [], range: range) {
            guard let hrefRange = Range(match.range(at: 1), in: section) else { continue }
            let href = htmlUnescaped(String(section[hrefRange]))
            if !links.contains(href) {
                links.append(href)
            }
        }

        let googleDocUrl = links.first { $0.localizedCaseInsensitiveContains("docs.google.com") }
        let sourceUrl = links.first { !($0.localizedCaseInsensitiveContains("docs.google.com")) }
        return (sourceUrl, googleDocUrl)
    }

    private func localeRecipeURL(for locale: String, slug: String, basedOn endpoint: URL) -> URL? {
        let basePath = endpoint.deletingLastPathComponent().deletingLastPathComponent()
        return basePath
            .appendingPathComponent(locale, isDirectory: true)
            .appendingPathComponent("recipes", isDirectory: true)
            .appendingPathComponent("\(slug).html")
    }

    private func fallbackValue(_ primary: String?, fallback: String) -> String {
        guard let primary else { return fallback }
        let normalized = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? fallback : normalized
    }

    private func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String {
            return value
        }
        if let value = raw as? NSNumber {
            return value.stringValue
        }
        if let values = raw as? [Any] {
            return values.compactMap { stringValue($0) }.first
        }
        return nil
    }

    private func stringArray(_ raw: Any?) -> [String] {
        if let values = raw as? [String] {
            return values
        }
        if let values = raw as? [Any] {
            return values.compactMap { stringValue($0) }
        }
        if let value = stringValue(raw) {
            return [value]
        }
        return []
    }

    private func instructionArray(_ raw: Any?) -> [String] {
        guard let values = raw as? [Any] else { return stringArray(raw) }
        return values.compactMap { value in
            if let text = value as? String {
                return text
            }
            if let object = value as? [String: Any] {
                return stringValue(object["text"]) ?? stringValue(object["name"])
            }
            return nil
        }
    }

    private func firstURLString(_ raw: Any?) -> String? {
        stringArray(raw).first
    }

    private func normalizeList(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func imagePathBySlug(from html: String) -> [String: String] {
        let pattern = #"<a[^>]*class="recipe-card__link"[^>]*href="[^"]*/recipes/([^"/]+)\.html"[^>]*>[\s\S]*?<img[^>]*src="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return [:]
        }

        let range = NSRange(html.startIndex..., in: html)
        var result: [String: String] = [:]

        regex.matches(in: html, options: [], range: range).forEach { match in
            guard let slugRange = Range(match.range(at: 1), in: html),
                  let imageRange = Range(match.range(at: 2), in: html) else {
                return
            }
            result[String(html[slugRange])] = htmlUnescaped(String(html[imageRange]))
        }

        return result
    }

    private func matchGroup(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[valueRange])
    }

    private func htmlUnescaped(_ text: String) -> String {
        let map: [String: String] = [
            "&quot;": "\"",
            "&#39;": "'",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">"
        ]

        return map.reduce(text) { partial, pair in
            partial.replacingOccurrences(of: pair.key, with: pair.value)
        }
    }

    private func persistCache(_ data: Data) throws {
        let directory = cacheFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: cacheFileURL, options: .atomic)
    }

    private func isRefreshDue() -> Bool {
        guard let lastAttempt = userDefaults.object(forKey: Keys.lastAttempt) as? Date else { return true }
        return Date().timeIntervalSince(lastAttempt) >= refreshCooldown
    }

    private func markRefreshAttempt() {
        userDefaults.set(Date(), forKey: Keys.lastAttempt)
    }

    private func markRefreshSuccess() {
        userDefaults.set(Date(), forKey: Keys.lastSynced)
    }

    private func encodedKey(for endpoint: URL) -> String {
        endpoint.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "default"
    }

    private static func resolveCacheFileURL(fileManager: FileManager) -> URL {
        let baseDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return baseDir
            .appendingPathComponent("ChefFaFaIOSApp", isDirectory: true)
            .appendingPathComponent("recipes_cache.json")
    }

    private static let defaultEndpoints: [URL] = [
        URL(string: "https://felixlee888.github.io/Chief-Fafa-Recipe/en/index.html")
    ]
    .compactMap { $0 }
}

private struct WebRecipeDetail {
    let title: String?
    let summary: String?
    let cuisine: String?
    let type: String?
    let ingredients: [String]
    let instructions: [String]
    let prepTime: String?
    let cookTime: String?
    let totalTime: String?
    let servings: String?
    let image: String?
    let sourceUrl: String?
    let googleDocUrl: String?
}

private struct EmbeddedWebRecipe: Codable {
    let slug: String
    let title: String
    let cuisine: String?
    let type: String?
    let tags: [String]?
    let summary: String?
    let ingredients: [String]?
}

@MainActor
final class RecipeStore: ObservableObject {
    @Published private(set) var siteMeta = SiteMeta(title: "Chef Fafa's Recipe", description: "")
    @Published private(set) var recipes: [Recipe] = []
    @Published private(set) var loadError: String?
    @Published private(set) var lastSyncedAt: Date?

    @Published var locale: AppLocale = .en
    @Published var searchText = ""
    @Published var selectedCuisineKey: String
    @Published var selectedTypeKey: String

    static let allFilterValue = "__all__"
    private static let allOption = FilterOption(id: allFilterValue, label: "__ALL__")
    private let syncClient: RemoteRecipeSyncClient
    private var startupSyncTask: Task<Void, Never>?

    init(bundle: Bundle = .main, syncClient: RemoteRecipeSyncClient = .init()) {
        self.syncClient = syncClient
        lastSyncedAt = syncClient.lastSyncedAt()
        selectedCuisineKey = Self.allFilterValue
        selectedTypeKey = Self.allFilterValue
        loadRecipesFromCacheOrBundle(bundle: bundle)
        startupSyncTask = Task { [weak self] in
            await self?.refreshFromWebsite(force: true)
        }
    }

    deinit {
        startupSyncTask?.cancel()
    }

    var labels: LocaleLabels {
        locale.labels
    }

    var allCuisineLabel: String { labels.allCuisines }
    var allTypeLabel: String { labels.allTypes }

    var localizedRecipes: [LocalizedRecipe] {
        recipes
            .map { LocalizedRecipe(recipe: $0, locale: locale) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var cuisineOptions: [FilterOption] {
        let mapped = localizedRecipes.reduce(into: [String: String]()) { result, recipe in
            result[recipe.cuisineKey] = recipe.cuisine
        }
        let options = mapped.map { FilterOption(id: $0.key, label: $0.value) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }

        return [Self.allOption] + options
    }

    var typeOptions: [FilterOption] {
        let mapped = localizedRecipes.reduce(into: [String: String]()) { result, recipe in
            result[recipe.typeKey] = recipe.type
        }
        let options = mapped.map { FilterOption(id: $0.key, label: $0.value) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }

        return [Self.allOption] + options
    }

    var filteredRecipes: [LocalizedRecipe] {
        let query = searchText.normalizedSearch

        return localizedRecipes.filter { recipe in
            let queryMatches = query.isEmpty || recipe.searchBlob.contains(query)
            let cuisineMatches = selectedCuisineKey == Self.allFilterValue || recipe.cuisineKey == selectedCuisineKey
            let typeMatches = selectedTypeKey == Self.allFilterValue || recipe.typeKey == selectedTypeKey
            return queryMatches && cuisineMatches && typeMatches
        }
    }

    var resultCount: Int {
        filteredRecipes.count
    }

    func selectCuisine(_ cuisineKey: String) {
        selectedCuisineKey = cuisineKey
    }

    func selectType(_ typeKey: String) {
        selectedTypeKey = typeKey
    }

    func refreshFromWebsite(force: Bool = false) async {
        do {
            let outcome = try await syncClient.refreshPayload(force: force)
            switch outcome {
            case .updated(let payload):
                applyPayload(payload)
            case .unchanged:
                break
            }
            lastSyncedAt = syncClient.lastSyncedAt()
            if !recipes.isEmpty {
                loadError = nil
            }
        } catch {
            if error.isExpectedCancellation {
                return
            }
            if recipes.isEmpty {
                loadError = "Unable to load recipes from website or local cache."
            }
#if DEBUG
            print("Recipe refresh error:", error.localizedDescription)
#endif
        }
    }

    private func loadRecipesFromCacheOrBundle(bundle: Bundle) {
        if let cachedPayload = syncClient.loadCachedPayload() {
            applyPayload(cachedPayload)
            loadError = nil
            return
        }

        guard let url = bundle.url(forResource: "recipes", withExtension: "json") else {
            loadError = "Missing bundled recipes.json"
            recipes = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(RecipePayload.self, from: data)
            applyPayload(payload)
            loadError = nil
        } catch {
            loadError = "Failed to parse recipes.json"
            recipes = []
        }
    }

    private func applyPayload(_ payload: RecipePayload) {
        siteMeta = payload.site
        recipes = payload.recipes
        normalizeSelectedFilters()
    }

    private func normalizeSelectedFilters() {
        let cuisines = Set(recipes.map(\.cuisine))
        let types = Set(recipes.map(\.type))

        if selectedCuisineKey != Self.allFilterValue, !cuisines.contains(selectedCuisineKey) {
            selectedCuisineKey = Self.allFilterValue
        }
        if selectedTypeKey != Self.allFilterValue, !types.contains(selectedTypeKey) {
            selectedTypeKey = Self.allFilterValue
        }
    }
}

private extension Error {
    var isExpectedCancellation: Bool {
        if self is CancellationError {
            return true
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
