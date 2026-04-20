import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

struct SocialUser: Identifiable, Hashable {
    let id: String
    let username: String
    let email: String
    let avatarColorHex: String
    let avatarImageBase64: String?
}

struct SocialFollowSnapshot {
    let followersCount: Int
    let followingCount: Int
    let isFollowing: Bool
}

enum DirectMessageKind: String {
    case text
    case news
}

struct SharedNewsPayload: Identifiable, Hashable {
    let id: String
    let source: String
    let title: String
    let timeText: String
    let summary: String
    let fullText: String
    let imageURLString: String?
    let thumbnailSymbol: String

    init(card: NewsCard) {
        self.id = card.id
        self.source = card.source
        self.title = card.title
        self.timeText = card.time
        self.summary = card.summary
        self.fullText = card.fullText
        self.imageURLString = card.imageURL?.absoluteString
        self.thumbnailSymbol = card.thumbnailSymbol
    }

    init?(_ data: [String: Any]) {
        let id = (data["sharedNewsID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = (data["sharedNewsTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !id.isEmpty, !title.isEmpty else { return nil }

        self.id = id
        self.source = (data["sharedNewsSource"] as? String) ?? "NewsBit"
        self.title = title
        self.timeText = (data["sharedNewsTimeText"] as? String) ?? "Shared"
        self.summary = (data["sharedNewsSummary"] as? String) ?? ""
        self.fullText = (data["sharedNewsFullText"] as? String) ?? ((data["sharedNewsSummary"] as? String) ?? "")
        self.imageURLString = data["sharedNewsImageURL"] as? String
        self.thumbnailSymbol = (data["sharedNewsThumbnailSymbol"] as? String) ?? "newspaper.fill"
    }

    var imageURL: URL? {
        guard let imageURLString, !imageURLString.isEmpty else { return nil }
        return URL(string: imageURLString)
    }

    var newsCard: NewsCard {
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

struct DirectMessageItem: Identifiable, Hashable {
    let id: String
    let senderID: String
    let recipientID: String
    let text: String
    let createdAt: Date
    let kind: DirectMessageKind
    let sharedNews: SharedNewsPayload?
}

struct ConversationSummary: Identifiable, Hashable {
    let id: String
    let otherUser: SocialUser
    let lastMessageText: String
    let lastMessageAt: Date
    let kind: DirectMessageKind

    var previewText: String {
        let trimmed = lastMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        return kind == .news ? "Shared a story" : "New message"
    }
}

struct SocialGraphStore {
    private let db = Firestore.firestore()

    func fetchFollowSnapshot(currentUserID: String?, targetUserID: String) async throws -> SocialFollowSnapshot {
        async let followersSnapshot = db.collection("follows")
            .whereField("followingID", isEqualTo: targetUserID)
            .getDocuments()
        async let followingSnapshot = db.collection("follows")
            .whereField("followerID", isEqualTo: targetUserID)
            .getDocuments()

        let isFollowing: Bool
        if let currentUserID,
           !currentUserID.isEmpty,
           currentUserID != targetUserID {
            let followDocument = try await db.collection("follows")
                .document(followDocumentID(followerID: currentUserID, followingID: targetUserID))
                .getDocument()
            isFollowing = followDocument.exists
        } else {
            isFollowing = false
        }

        let followersCount = (try await followersSnapshot).documents.count
        let followingCount = (try await followingSnapshot).documents.count

        return SocialFollowSnapshot(
            followersCount: followersCount,
            followingCount: followingCount,
            isFollowing: isFollowing
        )
    }

    func setFollowing(_ shouldFollow: Bool, currentUserID: String, targetUser: SocialUser) async throws {
        let ref = db.collection("follows")
            .document(followDocumentID(followerID: currentUserID, followingID: targetUser.id))

        if shouldFollow {
            try await ref.setData([
                "followerID": currentUserID,
                "followingID": targetUser.id,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)
        } else {
            try await ref.delete()
        }
    }

    func fetchConnections(for userID: String) async throws -> [SocialUser] {
        async let followingSnapshot = db.collection("follows")
            .whereField("followerID", isEqualTo: userID)
            .getDocuments()
        async let followersSnapshot = db.collection("follows")
            .whereField("followingID", isEqualTo: userID)
            .getDocuments()

        let followingDocuments = (try await followingSnapshot).documents
        let followerDocuments = (try await followersSnapshot).documents

        var orderedIDs: [String] = []
        var seen = Set<String>()

        for document in followingDocuments {
            if let followingID = document.data()["followingID"] as? String,
               !followingID.isEmpty,
               followingID != userID,
               seen.insert(followingID).inserted {
                orderedIDs.append(followingID)
            }
        }

        for document in followerDocuments {
            if let followerID = document.data()["followerID"] as? String,
               !followerID.isEmpty,
               followerID != userID,
               seen.insert(followerID).inserted {
                orderedIDs.append(followerID)
            }
        }

        return try await fetchUsers(ids: orderedIDs)
    }

    func fetchUser(uid: String) async throws -> SocialUser? {
        guard !uid.isEmpty else { return nil }

        let snapshot = try await db.collection("users").document(uid).getDocument()
        guard let data = snapshot.data() else { return nil }
        return socialUser(from: data, documentID: snapshot.documentID)
    }

    func fetchUsers(ids: [String]) async throws -> [SocialUser] {
        let sanitizedIDs = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !sanitizedIDs.isEmpty else { return [] }

        var usersByID: [String: SocialUser] = [:]
        let chunks = stride(from: 0, to: sanitizedIDs.count, by: 10).map { startIndex in
            Array(sanitizedIDs[startIndex..<min(startIndex + 10, sanitizedIDs.count)])
        }

        for chunk in chunks where !chunk.isEmpty {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            for document in snapshot.documents {
                usersByID[document.documentID] = socialUser(from: document.data(), documentID: document.documentID)
            }
        }

        return sanitizedIDs.compactMap { usersByID[$0] }
    }

    private func socialUser(from data: [String: Any], documentID: String) -> SocialUser {
        let uid = (data["uid"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedID = uid?.isEmpty == false ? uid! : documentID

        return SocialUser(
            id: resolvedID,
            username: (data["username"] as? String) ?? "Unknown",
            email: (data["email"] as? String) ?? "-",
            avatarColorHex: (data["avatarColorHex"] as? String) ?? "#0984E3",
            avatarImageBase64: data["avatarImageBase64"] as? String
        )
    }

    private func followDocumentID(followerID: String, followingID: String) -> String {
        "\(followerID)_\(followingID)"
    }
}

struct DirectMessagesStore {
    private let db = Firestore.firestore()
    private let socialStore = SocialGraphStore()

    func fetchConversations(currentUserID: String) async throws -> [ConversationSummary] {
        let snapshot = try await db.collection("conversations")
            .whereField("participantIDs", arrayContains: currentUserID)
            .getDocuments()

        var orderedOtherUserIDs: [String] = []
        var seen = Set<String>()

        for document in snapshot.documents {
            let participants = (document.data()["participantIDs"] as? [String]) ?? []
            guard let otherUserID = participants.first(where: { $0 != currentUserID }),
                  seen.insert(otherUserID).inserted else {
                continue
            }
            orderedOtherUserIDs.append(otherUserID)
        }

        let users = try await socialStore.fetchUsers(ids: orderedOtherUserIDs)
        let usersByID = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

        return snapshot.documents.compactMap {
            conversationSummary(from: $0, currentUserID: currentUserID, usersByID: usersByID)
        }
        .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    func fetchMessages(currentUserID: String, otherUserID: String) async throws -> [DirectMessageItem] {
        let conversationID = canonicalConversationID(currentUserID, otherUserID)
        let snapshot = try await db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .getDocuments()

        return snapshot.documents.map(messageItem(from:))
    }

    @discardableResult
    func listenConversations(
        currentUserID: String,
        onUpdate: @escaping ([ConversationSummary]) -> Void,
        onError: @escaping (String) -> Void
    ) -> ListenerRegistration {
        db.collection("conversations")
            .whereField("participantIDs", arrayContains: currentUserID)
            .addSnapshotListener { [socialStore] snapshot, error in
                if error != nil {
                    Task { @MainActor in
                        onError("Unable to load messages right now.")
                    }
                    return
                }

                guard let snapshot else {
                    Task { @MainActor in
                        onUpdate([])
                    }
                    return
                }

                let documents = snapshot.documents
                Task {
                    do {
                        var orderedOtherUserIDs: [String] = []
                        var seen = Set<String>()

                        for document in documents {
                            let participants = (document.data()["participantIDs"] as? [String]) ?? []
                            guard let otherUserID = participants.first(where: { $0 != currentUserID }),
                                  seen.insert(otherUserID).inserted else {
                                continue
                            }
                            orderedOtherUserIDs.append(otherUserID)
                        }

                        let users = try await socialStore.fetchUsers(ids: orderedOtherUserIDs)
                        let usersByID = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
                        let conversations = documents.compactMap {
                            conversationSummary(from: $0, currentUserID: currentUserID, usersByID: usersByID)
                        }
                        .sorted { $0.lastMessageAt > $1.lastMessageAt }

                        await MainActor.run {
                            onUpdate(conversations)
                        }
                    } catch {
                        await MainActor.run {
                            onError("Unable to load messages right now.")
                        }
                    }
                }
            }
    }

    @discardableResult
    func listenMessages(
        currentUserID: String,
        otherUserID: String,
        onUpdate: @escaping ([DirectMessageItem]) -> Void,
        onError: @escaping (String) -> Void
    ) -> ListenerRegistration {
        let conversationID = canonicalConversationID(currentUserID, otherUserID)

        return db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if error != nil {
                    Task { @MainActor in
                        onError("Unable to load this conversation right now.")
                    }
                    return
                }

                let messages = snapshot?.documents.map(messageItem(from:)) ?? []
                Task { @MainActor in
                    onUpdate(messages)
                }
            }
    }

    func sendText(_ text: String, from sender: SocialUser, to recipient: SocialUser) async throws {
        try await send(kind: .text, text: text, sharedNews: nil, from: sender, to: recipient)
    }

    func shareNews(_ payload: SharedNewsPayload, note: String?, from sender: SocialUser, to recipient: SocialUser) async throws {
        try await send(kind: .news, text: note ?? "", sharedNews: payload, from: sender, to: recipient)
    }

    private func send(
        kind: DirectMessageKind,
        text: String,
        sharedNews: SharedNewsPayload?,
        from sender: SocialUser,
        to recipient: SocialUser
    ) async throws {
        let conversationID = canonicalConversationID(sender.id, recipient.id)
        let conversationRef = db.collection("conversations").document(conversationID)
        let messageRef = conversationRef.collection("messages").document()

        var messagePayload: [String: Any] = [
            "id": messageRef.documentID,
            "senderID": sender.id,
            "recipientID": recipient.id,
            "type": kind.rawValue,
            "text": text,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let sharedNews {
            messagePayload["sharedNewsID"] = sharedNews.id
            messagePayload["sharedNewsSource"] = sharedNews.source
            messagePayload["sharedNewsTitle"] = sharedNews.title
            messagePayload["sharedNewsTimeText"] = sharedNews.timeText
            messagePayload["sharedNewsSummary"] = sharedNews.summary
            messagePayload["sharedNewsFullText"] = sharedNews.fullText
            messagePayload["sharedNewsImageURL"] = sharedNews.imageURLString ?? ""
            messagePayload["sharedNewsThumbnailSymbol"] = sharedNews.thumbnailSymbol
        }

        var conversationPayload: [String: Any] = [
            "participantIDs": [sender.id, recipient.id].sorted(),
            "lastMessageAt": FieldValue.serverTimestamp(),
            "lastMessageType": kind.rawValue,
            "lastMessageText": previewText(for: kind, text: text, sharedNews: sharedNews),
            "lastMessageSenderID": sender.id,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let sharedNews {
            conversationPayload["lastSharedNewsTitle"] = sharedNews.title
        }

        let batch = db.batch()
        batch.setData(conversationPayload, forDocument: conversationRef, merge: true)
        batch.setData(messagePayload, forDocument: messageRef)
        try await batch.commit()
    }

    func fetchCurrentUser(uid: String) async throws -> SocialUser? {
        try await socialStore.fetchUser(uid: uid)
    }

    private func previewText(for kind: DirectMessageKind, text: String, sharedNews: SharedNewsPayload?) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            return trimmedText
        }

        if kind == .news, let sharedNews {
            return "Shared: \(sharedNews.title)"
        }

        return kind == .news ? "Shared a story" : "New message"
    }

    private func canonicalConversationID(_ firstUserID: String, _ secondUserID: String) -> String {
        [firstUserID, secondUserID].sorted().joined(separator: "_")
    }

    private func conversationSummary(
        from document: QueryDocumentSnapshot,
        currentUserID: String,
        usersByID: [String: SocialUser]
    ) -> ConversationSummary? {
        let data = document.data()
        let participants = (data["participantIDs"] as? [String]) ?? []
        guard let otherUserID = participants.first(where: { $0 != currentUserID }),
              let otherUser = usersByID[otherUserID] else {
            return nil
        }

        let lastMessageAt = (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? .distantPast
        let kind = DirectMessageKind(rawValue: (data["lastMessageType"] as? String) ?? "") ?? .text
        let lastMessageText = (data["lastMessageText"] as? String) ?? ""

        return ConversationSummary(
            id: document.documentID,
            otherUser: otherUser,
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt,
            kind: kind
        )
    }

    private func messageItem(from document: QueryDocumentSnapshot) -> DirectMessageItem {
        let data = document.data()
        return DirectMessageItem(
            id: document.documentID,
            senderID: (data["senderID"] as? String) ?? "",
            recipientID: (data["recipientID"] as? String) ?? "",
            text: (data["text"] as? String) ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            kind: DirectMessageKind(rawValue: (data["type"] as? String) ?? "") ?? .text,
            sharedNews: SharedNewsPayload(data)
        )
    }
}

@MainActor
final class MessagesViewModel: ObservableObject {
    @Published private(set) var conversations: [ConversationSummary] = []
    @Published private(set) var connections: [SocialUser] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    let currentUserID: String?
    private let socialStore = SocialGraphStore()
    private let messagesStore = DirectMessagesStore()
    private var conversationsListener: ListenerRegistration?

    init(currentUserID: String?) {
        self.currentUserID = currentUserID
    }

    deinit {
        conversationsListener?.remove()
    }

    func load() async {
        guard let currentUserID, !currentUserID.isEmpty else {
            errorMessage = "Sign in to use messages."
            conversations = []
            connections = []
            conversationsListener?.remove()
            conversationsListener = nil
            return
        }

        isLoading = true
        errorMessage = nil

        conversationsListener?.remove()
        conversationsListener = messagesStore.listenConversations(
            currentUserID: currentUserID,
            onUpdate: { [weak self] conversations in
                guard let self else { return }
                self.conversations = conversations
                self.isLoading = false
            },
            onError: { [weak self] message in
                guard let self else { return }
                self.errorMessage = message
                self.isLoading = false
            }
        )

        do {
            connections = try await socialStore.fetchConnections(for: currentUserID)
        } catch {
            errorMessage = "Unable to load messages right now."
        }

        if conversations.isEmpty {
            isLoading = false
        }
    }
}

@MainActor
final class MessageThreadViewModel: ObservableObject {
    @Published private(set) var messages: [DirectMessageItem] = []
    @Published var draftText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published var errorMessage: String?

    let currentUserID: String?
    let otherUser: SocialUser

    private let messagesStore = DirectMessagesStore()
    private var messagesListener: ListenerRegistration?

    init(currentUserID: String?, otherUser: SocialUser) {
        self.currentUserID = currentUserID
        self.otherUser = otherUser
    }

    deinit {
        messagesListener?.remove()
    }

    func load() async {
        guard let currentUserID, !currentUserID.isEmpty else {
            errorMessage = "Sign in to use messages."
            messages = []
            messagesListener?.remove()
            messagesListener = nil
            return
        }

        isLoading = true
        errorMessage = nil

        messagesListener?.remove()
        messagesListener = messagesStore.listenMessages(
            currentUserID: currentUserID,
            otherUserID: otherUser.id,
            onUpdate: { [weak self] messages in
                guard let self else { return }
                self.messages = messages
                self.isLoading = false
            },
            onError: { [weak self] message in
                guard let self else { return }
                self.errorMessage = message
                self.isLoading = false
            }
        )
    }

    func sendMessage() async {
        guard let currentUserID, !currentUserID.isEmpty else {
            errorMessage = "Sign in to send messages."
            return
        }

        let trimmedDraft = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }

        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            guard let sender = try await messagesStore.fetchCurrentUser(uid: currentUserID) else {
                errorMessage = "Unable to load your profile."
                return
            }

            try await messagesStore.sendText(trimmedDraft, from: sender, to: otherUser)
            draftText = ""
        } catch {
            errorMessage = "Unable to send the message right now."
        }
    }
}

@MainActor
final class NewsShareSheetViewModel: ObservableObject {
    @Published private(set) var connections: [SocialUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSharing = false
    @Published var shareNote = ""
    @Published var errorMessage: String?

    let currentUserID: String?
    let payload: SharedNewsPayload

    private let socialStore = SocialGraphStore()
    private let messagesStore = DirectMessagesStore()

    init(currentUserID: String?, card: NewsCard) {
        self.currentUserID = currentUserID
        self.payload = SharedNewsPayload(card: card)
    }

    func load() async {
        guard let currentUserID, !currentUserID.isEmpty else {
            errorMessage = "Sign in to share stories with friends."
            connections = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            connections = try await socialStore.fetchConnections(for: currentUserID)
        } catch {
            errorMessage = "Unable to load friends right now."
        }
    }

    func share(to recipient: SocialUser) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            errorMessage = "Sign in to share stories with friends."
            return false
        }

        isSharing = true
        errorMessage = nil
        defer { isSharing = false }

        do {
            guard let sender = try await messagesStore.fetchCurrentUser(uid: currentUserID) else {
                errorMessage = "Unable to load your profile."
                return false
            }

            let trimmedNote = shareNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = trimmedNote.isEmpty ? nil : trimmedNote
            try await messagesStore.shareNews(payload, note: note, from: sender, to: recipient)
            return true
        } catch {
            errorMessage = "Unable to share this story right now."
            return false
        }
    }
}

struct MessagesView: View {
    @StateObject private var viewModel: MessagesViewModel

    init(currentUserID: String?) {
        _viewModel = StateObject(wrappedValue: MessagesViewModel(currentUserID: currentUserID))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumHomeBackground()

                Group {
                    if viewModel.currentUserID == nil {
                        socialEmptyState(
                            title: "Messages need an account",
                            subtitle: "Sign in to follow people and send them stories or text messages."
                        )
                    } else if viewModel.isLoading && viewModel.conversations.isEmpty && viewModel.connections.isEmpty {
                        loadingState("Loading messages...")
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                if !viewModel.connections.isEmpty {
                                    sectionTitle("Friends")

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 14) {
                                            ForEach(viewModel.connections) { user in
                                                NavigationLink {
                                                    MessageThreadView(
                                                        currentUserID: viewModel.currentUserID,
                                                        otherUser: user
                                                    )
                                                } label: {
                                                    friendCard(user)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 1)
                                    }
                                    .scrollIndicators(.hidden)
                                }

                                if viewModel.conversations.isEmpty {
                                    socialEmptyState(
                                        title: "No conversations yet",
                                        subtitle: viewModel.connections.isEmpty
                                            ? "Follow someone from search, then share a story upward from the feed."
                                            : "Open a friend above to start chatting or share a story from the feed."
                                    )
                                } else {
                                    sectionTitle("Inbox")

                                    VStack(spacing: 12) {
                                        ForEach(viewModel.conversations) { conversation in
                                            NavigationLink {
                                                MessageThreadView(
                                                    currentUserID: viewModel.currentUserID,
                                                    otherUser: conversation.otherUser
                                                )
                                            } label: {
                                                conversationRow(conversation)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                if let errorMessage = viewModel.errorMessage {
                                    Text(errorMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                        .padding(.horizontal, 2)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 28)
                        }
                        .scrollIndicators(.hidden)
                        .refreshable {
                            await viewModel.load()
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.load()
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(HomePalette.primaryText)
    }

    private func friendCard(_ user: SocialUser) -> some View {
        VStack(spacing: 10) {
            AvatarCircleView(
                username: user.username,
                avatarColorHex: user.avatarColorHex,
                avatarImageBase64: user.avatarImageBase64,
                fontSize: 20
            )
            .frame(width: 58, height: 58)

            Text(user.username)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HomePalette.primaryText)
                .lineLimit(1)
        }
        .frame(width: 86)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(HomePalette.softStroke, lineWidth: 1)
                )
                .shadow(color: HomePalette.shadow, radius: 14, x: 0, y: 8)
        )
    }

    private func conversationRow(_ conversation: ConversationSummary) -> some View {
        HStack(spacing: 12) {
            AvatarCircleView(
                username: conversation.otherUser.username,
                avatarColorHex: conversation.otherUser.avatarColorHex,
                avatarImageBase64: conversation.otherUser.avatarImageBase64,
                fontSize: 22
            )
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.otherUser.username)
                    .font(.headline)
                    .foregroundStyle(HomePalette.primaryText)

                Text(conversation.previewText)
                    .font(.subheadline)
                    .foregroundStyle(HomePalette.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            Text(shortRelativeTime(from: conversation.lastMessageAt))
                .font(.caption)
                .foregroundStyle(HomePalette.mutedText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(HomePalette.softStroke, lineWidth: 1)
                )
                .shadow(color: HomePalette.shadow, radius: 14, x: 0, y: 8)
        )
    }

    private func socialEmptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "paperplane.circle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(HomePalette.mutedText)
            Text(title)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(HomePalette.primaryText)
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(HomePalette.mutedText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .homeGlassCard(cornerRadius: 28)
    }

    private func loadingState(_ title: String) -> some View {
        VStack {
            ProgressView(title)
                .tint(HomePalette.accent)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .homeGlassCard(cornerRadius: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

struct MessageThreadView: View {
    @StateObject private var viewModel: MessageThreadViewModel
    @State private var selectedSharedNews: SharedNewsPayload?
    @State private var isShowingUserProfile = false

    init(currentUserID: String?, otherUser: SocialUser) {
        _viewModel = StateObject(
            wrappedValue: MessageThreadViewModel(
                currentUserID: currentUserID,
                otherUser: otherUser
            )
        )
    }

    var body: some View {
        ZStack {
            PremiumHomeBackground()

            if viewModel.currentUserID == nil {
                VStack(spacing: 12) {
                    Text("Sign in to use messages.")
                        .font(.subheadline)
                        .foregroundStyle(HomePalette.mutedText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                messagesList
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedSharedNews) { sharedNews in
            NewsDetailView(card: sharedNews.newsCard)
        }
        .navigationDestination(isPresented: $isShowingUserProfile) {
            VisitedUserProfileView(
                profileDocumentID: viewModel.otherUser.id,
                userUID: viewModel.otherUser.id
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.currentUserID != nil {
                composer
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    isShowingUserProfile = true
                } label: {
                    VStack(spacing: 0) {
                        Text(viewModel.otherUser.username)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HomePalette.primaryText)
                            .lineLimit(1)

                        Text("View profile")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(HomePalette.mutedText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.isLoading && viewModel.messages.isEmpty {
                        ProgressView("Loading conversation...")
                            .tint(HomePalette.accent)
                            .padding(.top, 40)
                    } else if viewModel.messages.isEmpty {
                        VStack(spacing: 10) {
                            Text("No messages yet")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(HomePalette.primaryText)

                            Text("Send the first message to start this conversation.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(HomePalette.mutedText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity)
                        .homeGlassCard(cornerRadius: 28)
                        .padding(.top, 22)
                    } else {
                        ForEach(viewModel.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.last?.id, initial: true) { _, messageID in
                guard let messageID else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(messageID, anchor: .bottom)
                }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: DirectMessageItem) -> some View {
        let isOutgoing = message.senderID == viewModel.currentUserID

        HStack {
            if isOutgoing {
                Spacer(minLength: 48)
                messageBubbleBody(message, isOutgoing: true)
            } else {
                messageBubbleBody(message, isOutgoing: false)
                Spacer(minLength: 48)
            }
        }
    }

    private func messageBubbleBody(_ message: DirectMessageItem, isOutgoing: Bool) -> some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 6) {
            if message.kind == .news, let sharedNews = message.sharedNews {
                Button {
                    selectedSharedNews = sharedNews
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(message.text)
                                .font(.subheadline)
                                .foregroundStyle(isOutgoing ? Color.white : HomePalette.primaryText)
                                .multilineTextAlignment(.leading)
                        }

                        newsSharePreview(sharedNews, isOutgoing: isOutgoing)
                    }
                    .padding(12)
                    .background(messageBubbleBackground(isOutgoing: isOutgoing))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(isOutgoing ? Color.white : HomePalette.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(messageBubbleBackground(isOutgoing: isOutgoing))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .multilineTextAlignment(.leading)
            }

            Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(HomePalette.mutedText)
        }
    }

    private func newsSharePreview(_ sharedNews: SharedNewsPayload, isOutgoing: Bool) -> some View {
        HStack(spacing: 10) {
            newsShareThumbnail(sharedNews)

            VStack(alignment: .leading, spacing: 4) {
                Text(sharedNews.source)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOutgoing ? Color.white.opacity(0.82) : HomePalette.mutedText)

                Text(sharedNews.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isOutgoing ? Color.white : HomePalette.primaryText)
                    .lineLimit(2)

                Text(sharedNews.timeText)
                    .font(.caption)
                    .foregroundStyle(isOutgoing ? Color.white.opacity(0.76) : HomePalette.mutedText)
            }
        }
    }

    @ViewBuilder
    private func newsShareThumbnail(_ sharedNews: SharedNewsPayload) -> some View {
        if let imageURL = sharedNews.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    shareThumbnailPlaceholder(symbol: sharedNews.thumbnailSymbol)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            shareThumbnailPlaceholder(symbol: sharedNews.thumbnailSymbol)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func shareThumbnailPlaceholder(symbol: String) -> some View {
        ZStack {
            LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    private var composer: some View {
        MessageComposerBar(
            text: $viewModel.draftText,
            isSending: viewModel.isSending,
            onSend: {
                Task {
                    await viewModel.sendMessage()
                }
            }
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        // Keep a little separation from the tab bar without wasting vertical space.
        .padding(.bottom, PremiumNavigationMetrics.composerClearance)
        .background(
            LinearGradient(
                colors: [
                    HomePalette.background.opacity(0),
                    HomePalette.background.opacity(0.82),
                    HomePalette.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func messageBubbleBackground(isOutgoing: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isOutgoing ? HomePalette.accent : Color.white.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isOutgoing ? HomePalette.accent.opacity(0.2) : HomePalette.softStroke, lineWidth: 1)
            )
            .shadow(color: isOutgoing ? HomePalette.accent.opacity(0.12) : HomePalette.shadow, radius: 10, x: 0, y: 6)
    }
}

private struct MessageComposerBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Write a message", text: $text, axis: .vertical)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(HomePalette.primaryText)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(HomePalette.softStroke, lineWidth: 1)
                        )
                )

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(HomePalette.accent)
                    )
            }
            .buttonStyle(PressableIconButtonStyle())
            .disabled(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.84))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(HomePalette.softStroke, lineWidth: 1)
                )
                .shadow(color: HomePalette.shadow, radius: 16, x: 0, y: 10)
        )
    }
}

struct NewsShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: NewsShareSheetViewModel
    @State private var searchText = ""

    init(card: NewsCard, currentUserID: String?) {
        _viewModel = StateObject(
            wrappedValue: NewsShareSheetViewModel(
                currentUserID: currentUserID,
                card: card
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                shareHeader
                Divider()

                if viewModel.currentUserID == nil {
                    VStack(spacing: 12) {
                        Text("Sign in to share stories with friends.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isLoading && viewModel.connections.isEmpty {
                    ProgressView("Loading friends...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredConnections.isEmpty {
                    VStack(spacing: 12) {
                        Text(emptyShareStateTitle)
                            .font(.headline)
                        Text(emptyShareStateSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredConnections) { user in
                            HStack(spacing: 12) {
                                AvatarCircleView(
                                    username: user.username,
                                    avatarColorHex: user.avatarColorHex,
                                    avatarImageBase64: user.avatarImageBase64,
                                    fontSize: 18
                                )
                                .frame(width: 42, height: 42)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.username)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Send") {
                                    Task {
                                        let shared = await viewModel.share(to: user)
                                        if shared {
                                            dismiss()
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.isSharing)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }
            }
            .navigationTitle("Share Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private var shareHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.payload.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(viewModel.payload.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Add a note (optional)", text: $viewModel.shareNote, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search friends", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .padding(16)
        .background(Color(.systemBackground))
    }

    private var filteredConnections: [SocialUser] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return viewModel.connections }

        return viewModel.connections.filter { user in
            user.username.localizedCaseInsensitiveContains(trimmedSearch)
                || user.email.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    private var emptyShareStateTitle: String {
        if viewModel.connections.isEmpty {
            return "No friends available"
        }

        return "No matching friends"
    }

    private var emptyShareStateSubtitle: String {
        if viewModel.connections.isEmpty {
            return "Follow someone from search first, then you can send them stories here."
        }

        return "Try another name or email."
    }
}

extension VisitedUserProfile {
    var socialUser: SocialUser {
        SocialUser(
            id: uid,
            username: username,
            email: email,
            avatarColorHex: avatarColorHex,
            avatarImageBase64: avatarImageBase64
        )
    }
}

private func shortRelativeTime(from date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
