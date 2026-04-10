import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
struct VisitedUserProfileView: View {
    @StateObject private var viewModel: VisitedUserProfileViewModel
    @State private var selectedCard: NewsCard?
    @State private var isShowingDetail = false

    init(profileDocumentID: String, userUID: String?) {
        _viewModel = StateObject(
            wrappedValue: VisitedUserProfileViewModel(
                profileDocumentID: profileDocumentID,
                userUID: userUID
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                bannerHeader

                if viewModel.isLoading && viewModel.highlightedItems.isEmpty {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                } else if let errorMessage = viewModel.errorMessage, viewModel.highlightedItems.isEmpty {
                    VStack(spacing: 10) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("Retry") {
                            Task {
                                await viewModel.load()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                } else {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                    }
                    highlightsSection
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .navigationDestination(isPresented: $isShowingDetail) {
            if let selectedCard {
                NewsDetailView(card: selectedCard)
            }
        }
    }

    private var bannerHeader: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(viewModel.bannerGradient)
                .frame(height: 170)
                .overlay(alignment: .bottomLeading) {
                    Text("Highlights")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: viewModel.profile?.avatarColorHex ?? "#0984E3"))
                        Text(viewModel.initial)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 84, height: 84)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .offset(y: -34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.profile?.username ?? "Unknown User")
                            .font(.title3.weight(.bold))
                        Text(viewModel.profile?.email ?? "-")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Gender: \(viewModel.profile?.gender ?? "-")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Member since \(viewModel.memberSinceText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 12)
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Highlighted News")
                .font(.headline)
                .padding(.horizontal, 16)

            if viewModel.highlightedItems.isEmpty {
                Text("No highlighted news yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                ForEach(viewModel.highlightedItems) { item in
                    highlightedRow(item: item)
                }
            }
        }
    }

    private func highlightedRow(item: HighlightedNewsItem) -> some View {
        Button {
            Task {
                let card = await viewModel.fetchNewsDetails(for: item)
                selectedCard = card
                isShowingDetail = true
            }
        } label: {
            HStack(spacing: 12) {
                highlightedThumbnail(for: item)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(item.dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func highlightedThumbnail(for item: HighlightedNewsItem) -> some View {
        if let imageURL = item.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    thumbnailPlaceholder
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            thumbnailPlaceholder
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "highlighter")
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

struct HighlightedNewsItem: Identifiable {
    let id: String
    let title: String
    let source: String
    let timeText: String
    let summary: String
    let fullText: String
    let thumbnailSymbol: String
    let imageURL: URL?
    let savedAt: Date

    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: savedAt)
    }

    var asNewsCard: NewsCard {
        NewsCard(
            id: id,
            source: source,
            title: title,
            time: timeText,
            summary: summary,
            fullText: fullText,
            commentCount: 0,
            imageURL: imageURL,
            thumbnailSymbol: thumbnailSymbol,
            imageGradient: LinearGradient(
                colors: [.orange, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct VisitedUserProfile {
    let uid: String
    let username: String
    let email: String
    let gender: String
    let avatarColorHex: String
    let createdAt: Date?
}

@MainActor
final class VisitedUserProfileViewModel: ObservableObject {
    @Published private(set) var profile: VisitedUserProfile?
    @Published private(set) var highlightedItems: [HighlightedNewsItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private let service = NewsFeedService()
    private let profileDocumentID: String
    private let userUID: String?

    init(profileDocumentID: String, userUID: String?) {
        self.profileDocumentID = profileDocumentID
        self.userUID = userUID
    }

    var initial: String {
        let username = profile?.username.trimmingCharacters(in: .whitespacesAndNewlines) ?? "U"
        guard let first = username.first else { return "U" }
        return String(first).uppercased()
    }

    var memberSinceText: String {
        guard let createdAt = profile?.createdAt else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    var bannerGradient: LinearGradient {
        let base = Color(hex: profile?.avatarColorHex ?? "#0984E3")
        return LinearGradient(
            colors: [base, base.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var profileLoadFailed = false
        var highlightsLoadFailed = false

        do {
            profile = try await fetchProfile()
        } catch {
            profile = nil
            profileLoadFailed = true
        }

        let ownerIDs = resolvedOwnerIDs()

        highlightedItems = await fetchHighlights(ownerIDs: ownerIDs)
        highlightsLoadFailed = highlightedItems.isEmpty

        if profileLoadFailed && highlightsLoadFailed {
            errorMessage = "Unable to load user profile right now."
        } else if profileLoadFailed {
            errorMessage = "Unable to load user details right now."
        } else if highlightsLoadFailed {
            errorMessage = "Unable to load highlighted news right now."
        }
    }

    func fetchNewsDetails(for item: HighlightedNewsItem) async -> NewsCard {
        do {
            if let fetchedCard = try await service.fetchCard(matching: item.id) {
                return fetchedCard
            }
        } catch {
            // Fall back to persisted highlight data if live fetch fails.
        }

        return item.asNewsCard
    }

    private func fetchProfile() async throws -> VisitedUserProfile {
        let snapshot = try await db.collection("users").document(profileDocumentID).getDocument()
        let data = snapshot.data() ?? [:]

        return VisitedUserProfile(
            uid: data["uid"] as? String ?? userUID ?? profileDocumentID,
            username: data["username"] as? String ?? "Unknown",
            email: data["email"] as? String ?? "-",
            gender: data["gender"] as? String ?? "-",
            avatarColorHex: data["avatarColorHex"] as? String ?? "#0984E3",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }

    private func fetchHighlights(ownerIDs: [String]) async -> [HighlightedNewsItem] {
        var entriesByNewsID: [String: HighlightedNewsItem] = [:]

        print("Visited profile ownerIDs:", ownerIDs)

        for ownerID in ownerIDs {
            do {
                let byUserFieldSnapshot = try await db.collection("highlights")
                    .whereField("userID", isEqualTo: ownerID)
                    .getDocuments()

                print("where userID == \(ownerID): \(byUserFieldSnapshot.documents.count) docs")

                for document in byUserFieldSnapshot.documents {
                    print("Matched by field:", document.documentID, document.data())
                    upsert(document: document, into: &entriesByNewsID)
                }
            } catch {
                print("Highlights by userID query failed for \(ownerID):", error.localizedDescription)
            }

            do {
                let byDocumentPrefixSnapshot = try await db.collection("highlights")
                    .order(by: FieldPath.documentID())
                    .start(at: ["\(ownerID)_"])
                    .end(at: ["\(ownerID)_\u{f8ff}"])
                    .getDocuments()

                print("docID prefix \(ownerID)_ : \(byDocumentPrefixSnapshot.documents.count) docs")

                for document in byDocumentPrefixSnapshot.documents {
                    print("Matched by prefix:", document.documentID, document.data())
                    upsert(document: document, into: &entriesByNewsID)
                }
            } catch {
                print("Highlights by document prefix query failed for \(ownerID):", error.localizedDescription)
            }

            do {
                let nestedSnapshot = try await db.collection("highlights")
                    .document(ownerID)
                    .collection("items")
                    .getDocuments()

                print("nested highlights/\(ownerID)/items: \(nestedSnapshot.documents.count) docs")

                for document in nestedSnapshot.documents {
                    print("Matched nested:", document.documentID, document.data())
                    upsert(document: document, into: &entriesByNewsID)
                }
            } catch {
                print("Nested highlights query failed for \(ownerID):", error.localizedDescription)
            }
        }

        let result = Array(entriesByNewsID.values).sorted { $0.savedAt > $1.savedAt }
        print("Final highlightedItems count:", result.count)
        return result
    }

    private func resolvedOwnerIDs() -> [String] {
        let candidates = [profile?.uid, userUID, profileDocumentID]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    private func parseNewsItem(from document: QueryDocumentSnapshot, defaultSymbol: String) -> HighlightedNewsItem {
        let data = document.data()
        let newsID = data["newsId"] as? String ?? document.documentID
        let title = data["title"] as? String ?? "Untitled"
        let source = data["source"] as? String ?? "NewsBit"
        let timeText = data["timeText"] as? String ?? "Saved"
        let summary = data["summary"] as? String ?? "No summary available."
        let fullText = data["fullText"] as? String ?? summary
        let thumbnailSymbol = data["thumbnailSymbol"] as? String ?? defaultSymbol
        let savedAt = (data["savedAt"] as? Timestamp)?.dateValue() ?? Date()
        let imageURL = (data["imageURL"] as? String).flatMap(URL.init(string:))

        return HighlightedNewsItem(
            id: newsID,
            title: title,
            source: source,
            timeText: timeText,
            summary: summary,
            fullText: fullText,
            thumbnailSymbol: thumbnailSymbol,
            imageURL: imageURL,
            savedAt: savedAt
        )
    }

    private func upsert(document: QueryDocumentSnapshot, into store: inout [String: HighlightedNewsItem]) {
        let item = parseNewsItem(from: document, defaultSymbol: "highlighter")
        if let existing = store[item.id] {
            if item.savedAt > existing.savedAt {
                store[item.id] = item
            }
        } else {
            store[item.id] = item
        }
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}
