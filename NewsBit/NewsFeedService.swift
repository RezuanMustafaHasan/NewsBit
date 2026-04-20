import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

struct NewsCard: Identifiable {
    let id: String
    let source: String
    let title: String
    let time: String
    let summary: String
    let fullText: String
    let commentCount: Int
    let imageURL: URL?
    let thumbnailSymbol: String
    let imageGradient: LinearGradient
}

struct NewsCategoryFilter: Identifiable, Hashable {
    let code: String?
    let label: String

    var id: String {
        code ?? "ALL"
    }

    var apiCode: String? {
        code
    }

    var isAll: Bool {
        code == nil
    }

    static let all = NewsCategoryFilter(code: nil, label: "All")

    static let defaultTabs: [NewsCategoryFilter] = [
        .all,
        NewsCategoryFilter(code: "TOP", label: "Top"),
        NewsCategoryFilter(code: "POLITICS", label: "Politics"),
        NewsCategoryFilter(code: "WORLD", label: "World"),
        NewsCategoryFilter(code: "TECHNOLOGY", label: "Technology"),
        NewsCategoryFilter(code: "SPORTS", label: "Sports"),
        NewsCategoryFilter(code: "BUSINESS", label: "Business"),
        NewsCategoryFilter(code: "HEALTH", label: "Health")
    ]
}

@MainActor
final class NewsFeedViewModel: ObservableObject {
    @Published private(set) var cards: [NewsCard] = []
    @Published private(set) var currentCardIndex = 0
    @Published private(set) var isLoading = false
    @Published var loadError: String?
    @Published private(set) var favoriteCardIDs: Set<String> = []
    @Published private(set) var highlightedCardIDs: Set<String> = []
    @Published private(set) var categories: [NewsCategoryFilter] = NewsCategoryFilter.defaultTabs
    @Published private(set) var selectedCategory: NewsCategoryFilter = .all

    private let service: NewsFeedService
    private let interactionStore: NewsInteractionStore?
    private let pageSize = 20
    private let prefetchThreshold = 10

    private var nextPage = 0
    private var reachedEnd = false
    private var didLoadCategories = false
    private var requestGeneration = 0
    private var activeRequestCount = 0

    init(userID: String? = nil) {
        self.service = NewsFeedService()
        if let userID, !userID.isEmpty {
            self.interactionStore = NewsInteractionStore(userID: userID)
        } else {
            self.interactionStore = nil
        }
    }

    func loadInitialIfNeeded() async {
        await loadCategoriesIfNeeded()
        guard cards.isEmpty else { return }
        await refresh()
    }

    func refresh() async {
        requestGeneration += 1
        let generation = requestGeneration
        cards = []
        currentCardIndex = 0
        nextPage = 0
        reachedEnd = false
        loadError = nil
        favoriteCardIDs.removeAll()
        highlightedCardIDs.removeAll()
        await fetchNextPage(generation: generation)
    }

    var canAdvance: Bool {
        currentCardIndex + 1 < cards.count
    }

    var canRewind: Bool {
        currentCardIndex > 0
    }

    func visibleCards(maxCount: Int) -> [NewsCard] {
        guard !cards.isEmpty, maxCount > 0 else { return [] }

        let safeIndex = min(max(currentCardIndex, 0), cards.count - 1)
        let endIndex = min(cards.count, safeIndex + maxCount)
        return Array(cards[safeIndex..<endIndex])
    }

    func advanceToNextCard() async {
        guard !cards.isEmpty else { return }

        if currentCardIndex + 1 < cards.count {
            currentCardIndex += 1
            await prefetchIfNeeded()
            return
        }

        if !reachedEnd {
            await prefetchIfNeeded()
        }
    }

    func returnToPreviousCard() {
        guard currentCardIndex > 0 else { return }
        currentCardIndex -= 1
    }

    func selectCategory(_ category: NewsCategoryFilter) async {
        guard selectedCategory != category else { return }
        selectedCategory = category
        await refresh()
    }

    func isFavorite(_ card: NewsCard) -> Bool {
        favoriteCardIDs.contains(card.id)
    }

    func isHighlighted(_ card: NewsCard) -> Bool {
        highlightedCardIDs.contains(card.id)
    }

    func toggleFavorite(for card: NewsCard) async {
        guard let interactionStore else { return }

        if favoriteCardIDs.contains(card.id) {
            favoriteCardIDs.remove(card.id)
            do {
                try await interactionStore.removeFavorite(cardID: card.id)
            } catch {
                favoriteCardIDs.insert(card.id)
            }
        } else {
            favoriteCardIDs.insert(card.id)
            do {
                try await interactionStore.saveFavorite(card: card)
            } catch {
                favoriteCardIDs.remove(card.id)
            }
        }
    }

    func toggleHighlight(for card: NewsCard) async {
        guard let interactionStore else { return }

        if highlightedCardIDs.contains(card.id) {
            highlightedCardIDs.remove(card.id)
            do {
                try await interactionStore.removeHighlight(cardID: card.id)
            } catch {
                highlightedCardIDs.insert(card.id)
            }
        } else {
            highlightedCardIDs.insert(card.id)
            do {
                try await interactionStore.saveHighlight(card: card)
            } catch {
                highlightedCardIDs.remove(card.id)
            }
        }
    }

    private func syncInteractionStateForLoadedCards() async {
        guard let interactionStore else { return }

        let cardIDs = cards.map(\.id)
        do {
            async let favorites = interactionStore.fetchFavoriteIDs(in: cardIDs)
            async let highlights = interactionStore.fetchHighlightIDs(in: cardIDs)
            favoriteCardIDs = try await favorites
            highlightedCardIDs = try await highlights
        } catch {
            // Keep UI responsive if interaction fetch fails.
        }
    }

    private func loadCategoriesIfNeeded() async {
        guard !didLoadCategories else { return }
        didLoadCategories = true

        do {
            let fetchedCategories = try await service.fetchCategories()
            guard !fetchedCategories.isEmpty else { return }

            var normalizedCategories: [NewsCategoryFilter] = [.all]
            for category in fetchedCategories where !category.isAll {
                if !normalizedCategories.contains(where: { $0.id == category.id }) {
                    normalizedCategories.append(category)
                }
            }
            categories = normalizedCategories
        } catch {
            // Keep the built-in category list as a fallback.
        }
    }

    private func prefetchIfNeeded() async {
        let remainingCards = cards.count - (currentCardIndex + 1)
        guard remainingCards <= prefetchThreshold, !reachedEnd else { return }
        await fetchNextPage(generation: requestGeneration)
    }

    private func fetchNextPage(generation: Int) async {
        guard !reachedEnd else { return }
        guard !(activeRequestCount > 0 && generation == requestGeneration) else { return }

        let requestPage = nextPage
        let requestCategory = selectedCategory.apiCode

        activeRequestCount += 1
        isLoading = true
        defer {
            activeRequestCount = max(0, activeRequestCount - 1)
            isLoading = activeRequestCount > 0
        }

        do {
            let items = try await service.fetchFeed(
                page: requestPage,
                limit: pageSize,
                categoryCode: requestCategory
            )

            guard generation == requestGeneration,
                  requestPage == nextPage,
                  requestCategory == selectedCategory.apiCode else {
                return
            }

            let mappedCards = items.enumerated().map { index, item in
                item.toNewsCard(styleIndex: (requestPage * pageSize) + index)
            }

            if mappedCards.count < pageSize {
                reachedEnd = true
            }

            cards.append(contentsOf: mappedCards)

            nextPage += 1
            loadError = nil
            await syncInteractionStateForLoadedCards()
        } catch {
            guard generation == requestGeneration else { return }
            if let feedError = error as? FeedError {
                loadError = feedError.localizedDescription
            } else {
                loadError = "Unable to load feed. Please try again."
            }
        }
    }
}

private struct FeedEnvelope: Decodable {
    let items: [FeedItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([FeedItem].self) {
            items = array
            return
        }

        let keyed = try decoder.container(keyedBy: AnyCodingKey.self)

        if let value = try keyed.decodeIfPresent([FeedItem].self, forKey: AnyCodingKey("data")) {
            items = value
            return
        }

        if let value = try keyed.decodeIfPresent([FeedItem].self, forKey: AnyCodingKey("content")) {
            items = value
            return
        }

        if let value = try keyed.decodeIfPresent([FeedItem].self, forKey: AnyCodingKey("feed")) {
            items = value
            return
        }

        if let value = try keyed.decodeIfPresent([FeedItem].self, forKey: AnyCodingKey("items")) {
            items = value
            return
        }

        if let value = try keyed.decodeIfPresent([FeedItem].self, forKey: AnyCodingKey("articles")) {
            items = value
            return
        }

        items = []
    }
}

struct FeedItem: Decodable {
    let id: String
    let source: String
    let title: String
    let summary: String
    let content: String
    let publishedAt: Date?
    let imageURL: URL?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        id = Self.decodeIdentifier(container, keys: ["id", "_id", "uuid", "newsId", "articleId"]) ?? UUID().uuidString

        source = Self.decodeNestedString(
            container,
            parentKeys: ["source"],
            childKeys: ["name", "title"]
        ) ?? Self.decodeString(container, keys: ["source", "sourceName", "publisher", "categoryLabel", "category"]) ?? "NewsBit"

        title = Self.decodeString(container, keys: ["title", "headline"]) ?? "Untitled"

        summary = Self.decodeString(container, keys: ["summary", "description", "excerpt", "snippet"]) ?? ""

        content = Self.decodeString(container, keys: ["content", "body", "text"]) ?? summary

        publishedAt = Self.decodeDate(container, keys: ["publishedAt", "published_at", "createdAt", "created_at", "date"])

        if let rawImageURL = Self.decodeString(container, keys: ["imageUrl", "imageURL", "image", "thumbnail"]) {
            imageURL = URL(string: rawImageURL)
        } else {
            imageURL = nil
        }
    }

    private static func decodeIdentifier(_ container: KeyedDecodingContainer<AnyCodingKey>, keys: [String]) -> String? {
        for key in keys {
            let codingKey = AnyCodingKey(key)

            if let intValue = try? container.decodeIfPresent(Int.self, forKey: codingKey) {
                return String(intValue)
            }

            if let stringValue = (try? container.decodeIfPresent(String.self, forKey: codingKey)) ?? nil {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func decodeString(_ container: KeyedDecodingContainer<AnyCodingKey>, keys: [String]) -> String? {
        for key in keys {
            let codingKey = AnyCodingKey(key)
            if let value = (try? container.decodeIfPresent(String.self, forKey: codingKey)) ?? nil {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func decodeNestedString(
        _ container: KeyedDecodingContainer<AnyCodingKey>,
        parentKeys: [String],
        childKeys: [String]
    ) -> String? {
        for parentKey in parentKeys {
            let key = AnyCodingKey(parentKey)
            guard let nested = try? container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: key) else {
                continue
            }

            for childKey in childKeys {
                let nestedKey = AnyCodingKey(childKey)
                if let value = (try? nested.decodeIfPresent(String.self, forKey: nestedKey)) ?? nil {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
        }
        return nil
    }

    private static func decodeDate(_ container: KeyedDecodingContainer<AnyCodingKey>, keys: [String]) -> Date? {
        for key in keys {
            let codingKey = AnyCodingKey(key)

            if let value = try? container.decodeIfPresent(Double.self, forKey: codingKey) {
                return Date(timeIntervalSince1970: value)
            }

            if let value = try? container.decodeIfPresent(Int.self, forKey: codingKey) {
                return Date(timeIntervalSince1970: Double(value))
            }

            if let raw = try? container.decodeIfPresent(String.self, forKey: codingKey) {
                if let date = ISO8601DateFormatter.withFractional.date(from: raw)
                    ?? ISO8601DateFormatter.standard.date(from: raw)
                    ?? DateFormatter.iso8601NoTimezone.date(from: raw)
                    ?? DateFormatter.iso8601NoTimezoneNoFractional.date(from: raw) {
                    return date
                }
            }
        }
        return nil
    }

    func toNewsCard(styleIndex: Int) -> NewsCard {
        let styles = NewsCardStyle.allCases
        let style = styles[abs(styleIndex) % styles.count]

        return NewsCard(
            id: id,
            source: source,
            title: title,
            time: publishedAt?.relativeTimeText ?? "Just now",
            summary: summary.isEmpty ? content : summary,
            fullText: content.isEmpty ? summary : content,
            commentCount: 0,
            imageURL: imageURL,
            thumbnailSymbol: style.symbol,
            imageGradient: style.gradient
        )
    }
}

private enum NewsCardStyle: CaseIterable {
    case orange
    case blue
    case purple
    case teal

    var symbol: String {
        switch self {
        case .orange:
            return "newspaper.fill"
        case .blue:
            return "globe"
        case .purple:
            return "cpu"
        case .teal:
            return "sportscourt.fill"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .orange:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blue:
            return LinearGradient(colors: [.blue, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .purple:
            return LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .teal:
            return LinearGradient(colors: [.teal, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct NewsInteractionStore {
    private let db = Firestore.firestore()
    private let userID: String

    init(userID: String) {
        self.userID = userID
    }

    func saveFavorite(card: NewsCard) async throws {
        try await saveCard(card, in: "favorites")
    }

    func removeFavorite(cardID: String) async throws {
        try await removeCard(cardID: cardID, from: "favorites")
    }

    func saveHighlight(card: NewsCard) async throws {
        try await saveCard(card, in: "highlights")
    }

    func removeHighlight(cardID: String) async throws {
        try await removeCard(cardID: cardID, from: "highlights")
    }

    func fetchFavoriteIDs(in cardIDs: [String]) async throws -> Set<String> {
        try await fetchIDs(in: "favorites", cardIDs: cardIDs)
    }

    func fetchHighlightIDs(in cardIDs: [String]) async throws -> Set<String> {
        try await fetchIDs(in: "highlights", cardIDs: cardIDs)
    }

    private func saveCard(_ card: NewsCard, in container: String) async throws {
        let entryID = pairDocumentID(userID: userID, newsID: card.id)
        try await db.collection(container)
            .document(entryID)
            .setData([
                "entryId": entryID,
                "userID": userID,
                "newsId": card.id,
                "title": card.title,
                "source": card.source,
                "timeText": card.time,
                "summary": card.summary,
                "fullText": card.fullText,
                "thumbnailSymbol": card.thumbnailSymbol,
                "imageURL": card.imageURL?.absoluteString ?? "",
                "savedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    private func removeCard(cardID: String, from container: String) async throws {
        let entryID = pairDocumentID(userID: userID, newsID: cardID)
        try await db.collection(container)
            .document(entryID)
            .delete()
    }

    private func fetchIDs(in container: String, cardIDs: [String]) async throws -> Set<String> {
        guard !cardIDs.isEmpty else { return [] }

        var matchedIDs = Set<String>()
        let chunks = stride(from: 0, to: cardIDs.count, by: 10).map { startIndex in
            Array(cardIDs[startIndex..<min(startIndex + 10, cardIDs.count)])
        }

        for chunk in chunks where !chunk.isEmpty {
            let snapshot = try await db.collection(container)
                .whereField("userID", isEqualTo: userID)
                .whereField("newsId", in: chunk)
                .getDocuments()

            snapshot.documents.forEach { document in
                if let newsID = document.data()["newsId"] as? String {
                    matchedIDs.insert(newsID)
                }
            }
        }

        return matchedIDs
    }

    private func pairDocumentID(userID: String, newsID: String) -> String {
        "\(userID)_\(newsID)"
    }
}

struct NewsFeedService {
    private let baseURL = URL(string: "https://newsbitapi.onrender.com")!

    func fetchCategories() async throws -> [NewsCategoryFilter] {
        let data = try await performRequest(url: baseURL.appendingPathComponent("v1/categories"))

        do {
            let decoded = try JSONDecoder().decode([APINewsCategory].self, from: data)
            return decoded.map {
                NewsCategoryFilter(
                    code: $0.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                    label: $0.label.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        } catch {
            throw FeedError.decodingFailed
        }
    }

    func fetchFeed(page: Int, limit: Int, categoryCode: String? = nil) async throws -> [FeedItem] {
        let normalizedPage = max(0, page)
        let apiPage = normalizedPage + 1
        let endpointURL: URL
        if let categoryCode,
           !categoryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            endpointURL = baseURL
                .appendingPathComponent("v1/categories")
                .appendingPathComponent(categoryCode.uppercased())
                .appendingPathComponent("feed")
        } else {
            endpointURL = baseURL.appendingPathComponent("v1/feed")
        }

        var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "page", value: String(apiPage)),
            URLQueryItem(name: "limit", value: String(min(max(1, limit), 100)))
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let data = try await performRequest(url: url)

        let decoder = JSONDecoder()
        do {
            let envelope = try decoder.decode(FeedEnvelope.self, from: data)
            return envelope.items
        } catch {
            throw FeedError.decodingFailed
        }
    }

    func fetchDetailedCard(id cardID: String, fallbackCard: NewsCard? = nil) async throws -> NewsCard {
        let item = try await fetchArticle(id: cardID)
        let fallbackSummary = fallbackCard?.summary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallbackFullText = fallbackCard?.fullText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return NewsCard(
            id: item.id,
            source: item.source,
            title: item.title,
            time: item.publishedAt?.relativeTimeText ?? fallbackCard?.time ?? "Just now",
            summary: item.summary.isEmpty ? fallbackSummary : item.summary,
            fullText: item.content.isEmpty ? (fallbackFullText.isEmpty ? fallbackSummary : fallbackFullText) : item.content,
            commentCount: fallbackCard?.commentCount ?? 0,
            imageURL: item.imageURL ?? fallbackCard?.imageURL,
            thumbnailSymbol: fallbackCard?.thumbnailSymbol ?? NewsCardStyle.orange.symbol,
            imageGradient: fallbackCard?.imageGradient ?? NewsCardStyle.orange.gradient
        )
    }

    func fetchCard(matching cardID: String, pageSize: Int = 20, maxPages: Int = 6) async throws -> NewsCard? {
        guard !cardID.isEmpty else { return nil }

        if let detailedCard = try? await fetchDetailedCard(id: cardID) {
            return detailedCard
        }

        for page in 0..<maxPages {
            let items = try await fetchFeed(page: page, limit: pageSize)
            if let matchedIndex = items.firstIndex(where: { $0.id == cardID }) {
                return items[matchedIndex].toNewsCard(styleIndex: (page * pageSize) + matchedIndex)
            }

            if items.count < pageSize {
                break
            }
        }

        return nil
    }

    private func fetchArticle(id cardID: String) async throws -> FeedItem {
        let url = baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("articles")
            .appendingPathComponent(cardID)

        let data = try await performRequest(url: url)

        do {
            return try JSONDecoder().decode(FeedItem.self, from: data)
        } catch {
            throw FeedError.decodingFailed
        }
    }

    private func performRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Basic cHVibGljOjEyMzQ1Njc4", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw FeedError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FeedError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: APIErrorEnvelope.message(from: data)
            )
        }

        return data
    }
}

private enum FeedError: LocalizedError {
    case unauthorized
    case requestFailed(statusCode: Int, message: String?)
    case decodingFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Feed API unauthorized. Check Basic auth credentials."
        case .requestFailed(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Feed API request failed (HTTP \(statusCode)): \(message)"
            }
            return "Feed API request failed (HTTP \(statusCode))."
        case .decodingFailed:
            return "Feed API response format is unexpected."
        case .invalidResponse:
            return "Feed API returned an invalid response."
        }
    }
}

private struct APINewsCategory: Decodable {
    let code: String
    let label: String
}

private struct APIErrorEnvelope: Decodable {
    let message: String?
    let error: String?
    let validationErrors: [String: String]?

    static func message(from data: Data) -> String? {
        guard let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) else {
            return nil
        }

        if let message = envelope.message, !message.isEmpty {
            if let validationErrors = envelope.validationErrors, !validationErrors.isEmpty {
                let details = validationErrors
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key): \($0.value)" }
                    .joined(separator: ", ")
                return "\(message) (\(details))"
            }

            return message
        }

        return envelope.error
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

private extension ISO8601DateFormatter {
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension DateFormatter {
    static let iso8601NoTimezone: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        return formatter
    }()

    static let iso8601NoTimezoneNoFractional: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}

private extension Date {
    var relativeTimeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
