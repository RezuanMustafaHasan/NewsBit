import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
struct VisitedUserProfileView: View {
    @StateObject private var viewModel: VisitedUserProfileViewModel
    @State private var selectedCard: NewsCard?
    @State private var isShowingDetail = false
    @State private var pendingUndoItem: HighlightedNewsItem?
    @State private var undoDismissTask: Task<Void, Never>?

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
        .overlay(alignment: .bottomTrailing) {
            if let pendingUndoItem {
                Button("Undo") {
                    Task {
                        let restored = await viewModel.restoreHighlight(item: pendingUndoItem)
                        if restored {
                            hideUndo()
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.black.opacity(0.82), in: Capsule())
                .foregroundStyle(.white)
                .padding(.trailing, 16)
                .padding(.bottom, 22)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pendingUndoItem?.id)
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
                    AvatarCircleView(
                        username: viewModel.profile?.username ?? "Unknown User",
                        avatarColorHex: viewModel.profile?.avatarColorHex ?? "#0984E3",
                        avatarImageBase64: viewModel.profile?.avatarImageBase64,
                        fontSize: 30
                    )
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

                HStack(spacing: 28) {
                    statColumn(value: viewModel.followersCount, label: "Followers")
                    statColumn(value: viewModel.followingCount, label: "Following")
                }
                .padding(.horizontal, 16)

                if let profile = viewModel.profile, viewModel.canInteract {
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.toggleFollow()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isUpdatingFollow {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(viewModel.isFollowing ? .primary : .white)
                                }

                                Text(viewModel.isFollowing ? "Following" : "Follow")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(viewModel.isFollowing ? Color(.secondarySystemBackground) : Color.blue)
                            )
                            .foregroundStyle(viewModel.isFollowing ? Color.primary : Color.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isUpdatingFollow)

                        if let currentUserID = viewModel.currentUserID {
                            NavigationLink {
                                MessageThreadView(
                                    currentUserID: currentUserID,
                                    otherUser: profile.socialUser
                                )
                            } label: {
                                Label("Message", systemImage: "paperplane.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.blue.opacity(0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.blue.opacity(0.35), lineWidth: 1)
                                    )
                                    .foregroundStyle(Color.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 12)
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
        HStack(spacing: 12) {
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
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    let removed = await viewModel.unhighlight(item: item)
                    if removed {
                        showUndo(for: item)
                    }
                }
            } label: {
                Image(systemName: "highlighter")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .padding(.horizontal, 12)
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

    private func showUndo(for item: HighlightedNewsItem) {
        undoDismissTask?.cancel()
        pendingUndoItem = item
        undoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                await MainActor.run {
                    hideUndo()
                }
            }
        }
    }

    private func hideUndo() {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        pendingUndoItem = nil
    }
}

struct HighlightedNewsItem: Identifiable, Hashable {
    let id: String
    let entryDocumentID: String
    let ownerID: String
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
    let avatarImageBase64: String?
    let createdAt: Date?
}

@MainActor
final class VisitedUserProfileViewModel: ObservableObject {
    @Published private(set) var profile: VisitedUserProfile?
    @Published private(set) var highlightedItems: [HighlightedNewsItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var followersCount = 0
    @Published private(set) var followingCount = 0
    @Published private(set) var isFollowing = false
    @Published private(set) var isUpdatingFollow = false

    private let db = Firestore.firestore()
    private let service = NewsFeedService()
    private let socialStore = SocialGraphStore()
    private let profileDocumentID: String
    private let userUID: String?
    let currentUserID: String?

    init(profileDocumentID: String, userUID: String?) {
        self.profileDocumentID = profileDocumentID
        self.userUID = userUID
        self.currentUserID = Auth.auth().currentUser?.uid
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

    var canInteract: Bool {
        guard let profile else { return false }
        guard let currentUserID, !currentUserID.isEmpty else { return false }
        return currentUserID != profile.uid
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var profileLoadFailed = false

        do {
            profile = try await fetchProfile()
        } catch {
            profile = nil
            profileLoadFailed = true
        }

        let ownerIDs = resolvedOwnerIDs()
        highlightedItems = await fetchHighlights(ownerIDs: ownerIDs)

        do {
            let snapshot = try await socialStore.fetchFollowSnapshot(
                currentUserID: currentUserID,
                targetUserID: resolvedTargetUserID()
            )
            followersCount = snapshot.followersCount
            followingCount = snapshot.followingCount
            isFollowing = snapshot.isFollowing
        } catch {
            followersCount = 0
            followingCount = 0
            isFollowing = false
        }

        if profileLoadFailed && highlightedItems.isEmpty {
            errorMessage = "Unable to load user profile right now."
        } else if profileLoadFailed {
            errorMessage = "Unable to load user details right now."
        } else if highlightedItems.isEmpty {
            errorMessage = "Unable to load highlighted news right now."
        }
    }

    func toggleFollow() async {
        guard !isUpdatingFollow else { return }
        guard let currentUserID, !currentUserID.isEmpty, let profile else { return }
        guard currentUserID != profile.uid else { return }

        isUpdatingFollow = true
        errorMessage = nil
        let shouldFollow = !isFollowing
        let previousFollowers = followersCount
        let previousState = isFollowing

        isFollowing = shouldFollow
        followersCount = max(0, followersCount + (shouldFollow ? 1 : -1))

        defer { isUpdatingFollow = false }

        do {
            try await socialStore.setFollowing(
                shouldFollow,
                currentUserID: currentUserID,
                targetUser: profile.socialUser
            )
        } catch {
            isFollowing = previousState
            followersCount = previousFollowers
            errorMessage = "Unable to update follow status right now."
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

    func unhighlight(item: HighlightedNewsItem) async -> Bool {
        let originalItems = highlightedItems
        highlightedItems.removeAll { $0.id == item.id }

        var candidateIDs = Set<String>()
        candidateIDs.insert(item.entryDocumentID)
        candidateIDs.insert("\(item.ownerID)_\(item.id)")
        for ownerID in resolvedOwnerIDs() {
            candidateIDs.insert("\(ownerID)_\(item.id)")
        }

        do {
            let batch = db.batch()
            for documentID in candidateIDs {
                let ref = db.collection("highlights").document(documentID)
                batch.deleteDocument(ref)
            }
            try await batch.commit()
            return true
        } catch {
            highlightedItems = originalItems
            errorMessage = "Unable to remove highlight right now."
            return false
        }
    }

    func restoreHighlight(item: HighlightedNewsItem) async -> Bool {
        let ownerID = item.ownerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (resolvedOwnerIDs().first ?? profileDocumentID)
            : item.ownerID
        let entryID = "\(ownerID)_\(item.id)"

        do {
            try await db.collection("highlights")
                .document(entryID)
                .setData([
                    "entryId": entryID,
                    "userID": ownerID,
                    "newsId": item.id,
                    "title": item.title,
                    "source": item.source,
                    "timeText": item.timeText,
                    "summary": item.summary,
                    "fullText": item.fullText,
                    "thumbnailSymbol": item.thumbnailSymbol,
                    "imageURL": item.imageURL?.absoluteString ?? "",
                    "savedAt": Timestamp(date: item.savedAt)
                ], merge: true)

            if !highlightedItems.contains(where: { $0.id == item.id }) {
                highlightedItems.append(item)
                highlightedItems.sort { $0.savedAt > $1.savedAt }
            }
            return true
        } catch {
            errorMessage = "Unable to restore highlight right now."
            return false
        }
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
            avatarImageBase64: data["avatarImageBase64"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }

    private func fetchHighlights(ownerIDs: [String]) async -> [HighlightedNewsItem] {
        var entriesByNewsID: [String: HighlightedNewsItem] = [:]

        for ownerID in ownerIDs {
            if let byUserFieldSnapshot = try? await db.collection("highlights")
                .whereField("userID", isEqualTo: ownerID)
                .getDocuments() {
                for document in byUserFieldSnapshot.documents {
                    upsert(document: document, ownerIDFallback: ownerID, into: &entriesByNewsID)
                }
            }

            if let byDocumentPrefixSnapshot = try? await db.collection("highlights")
                .order(by: FieldPath.documentID())
                .start(at: ["\(ownerID)_"])
                .end(at: ["\(ownerID)_\u{f8ff}"])
                .getDocuments() {
                for document in byDocumentPrefixSnapshot.documents {
                    upsert(document: document, ownerIDFallback: ownerID, into: &entriesByNewsID)
                }
            }

            if let nestedSnapshot = try? await db.collection("highlights")
                .document(ownerID)
                .collection("items")
                .getDocuments() {
                for document in nestedSnapshot.documents {
                    upsert(document: document, ownerIDFallback: ownerID, into: &entriesByNewsID)
                }
            }
        }

        if entriesByNewsID.isEmpty {
            if let broadSnapshot = try? await db.collection("highlights").limit(to: 300).getDocuments() {
                for document in broadSnapshot.documents {
                    let data = document.data()
                    let byField = ownerIDs.contains((data["userID"] as? String) ?? "")
                    let byDocPrefix = ownerIDs.contains { ownerID in
                        document.documentID.hasPrefix("\(ownerID)_")
                    }
                    if byField || byDocPrefix {
                        upsert(document: document, ownerIDFallback: ownerIDs.first ?? profileDocumentID, into: &entriesByNewsID)
                    }
                }
            }
        }

        return Array(entriesByNewsID.values).sorted { $0.savedAt > $1.savedAt }
    }

    private func resolvedOwnerIDs() -> [String] {
        let candidates = [profile?.uid, userUID, profileDocumentID]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    private func resolvedTargetUserID() -> String {
        resolvedOwnerIDs().first ?? profileDocumentID
    }

    private func parseNewsItem(from document: QueryDocumentSnapshot, defaultSymbol: String, ownerIDFallback: String) -> HighlightedNewsItem {
        let data = document.data()
        let newsID = data["newsId"] as? String ?? document.documentID
        let ownerByField = data["userID"] as? String
        let ownerByDocumentID = document.documentID.split(separator: "_", maxSplits: 1).first.map(String.init)
        let ownerID = ownerByField ?? ownerByDocumentID ?? ownerIDFallback
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
            entryDocumentID: document.documentID,
            ownerID: ownerID,
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

    private func upsert(
        document: QueryDocumentSnapshot,
        ownerIDFallback: String,
        into store: inout [String: HighlightedNewsItem]
    ) {
        let item = parseNewsItem(from: document, defaultSymbol: "highlighter", ownerIDFallback: ownerIDFallback)
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
