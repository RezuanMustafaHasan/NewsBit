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

@MainActor
final class NewsFeedViewModel: ObservableObject {
    @Published private(set) var cards: [NewsCard] = []
    @Published private(set) var isLoading = false
    @Published var loadError: String?
    @Published private(set) var favoriteCardIDs: Set<String> = []
    @Published private(set) var highlightedCardIDs: Set<String> = []

    private let service: NewsFeedService
    private let interactionStore: NewsInteractionStore?
    private let pageSize = 20
    private let prefetchThreshold = 10

    private var nextPage = 0
    private var reachedEnd = false

    init(userID: String? = nil) {
        self.service = NewsFeedService()
        if let userID, !userID.isEmpty {
            self.interactionStore = NewsInteractionStore(userID: userID)
        } else {
            self.interactionStore = nil
        }
    }

    func loadInitialIfNeeded() async {
        guard cards.isEmpty else { return }
        await refresh()
    }

    func refresh() async {
        cards = []
        nextPage = 0
        reachedEnd = false
        loadError = nil
        favoriteCardIDs.removeAll()
        highlightedCardIDs.removeAll()
        await fetchNextPage(prepend: true)
    }

    func consumeTopCard() async {
        guard !cards.isEmpty else { return }

        cards.removeLast()

        guard cards.count <= prefetchThreshold, !reachedEnd, !isLoading else {
            return
        }

        await fetchNextPage(prepend: true)
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

    private func fetchNextPage(prepend: Bool) async {
        guard !isLoading, !reachedEnd else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let items = try await service.fetchFeed(page: nextPage, limit: pageSize)
            let mappedCards = items.enumerated().map { index, item in
                item.toNewsCard(styleIndex: (nextPage * pageSize) + index)
            }

            if mappedCards.count < pageSize {
                reachedEnd = true
            }

            if prepend {
                cards.insert(contentsOf: mappedCards, at: 0)
            } else {
                cards.append(contentsOf: mappedCards)
            }

            nextPage += 1
            loadError = nil
            await syncInteractionStateForLoadedCards()
        } catch {
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

    func fetchFeed(page: Int, limit: Int) async throws -> [FeedItem] {
        var components = URLComponents(url: baseURL.appendingPathComponent("v1/feed"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "page", value: String(max(0, page))),
            URLQueryItem(name: "limit", value: String(min(max(1, limit), 100)))
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

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
            throw FeedError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            let envelope = try decoder.decode(FeedEnvelope.self, from: data)
            return envelope.items
        } catch {
            throw FeedError.decodingFailed
        }
    }

    func fetchCard(matching cardID: String, pageSize: Int = 20, maxPages: Int = 6) async throws -> NewsCard? {
        guard !cardID.isEmpty else { return nil }

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

}

private enum FeedError: LocalizedError {
    case unauthorized
    case requestFailed(statusCode: Int)
    case decodingFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Feed API unauthorized. Check Basic auth credentials."
        case .requestFailed(let statusCode):
            return "Feed API request failed (HTTP \(statusCode))."
        case .decodingFailed:
            return "Feed API response format is unexpected."
        case .invalidResponse:
            return "Feed API returned an invalid response."
        }
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
