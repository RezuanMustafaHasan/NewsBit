//import SwiftUI
//
//struct HomeView: View {
//    @StateObject private var viewModel = NewsFeedViewModel()
//    @State private var selectedNews: NewsCard?
//    @State private var isShowingDetail = false
//
//    var body: some View {
//        NavigationStack {
//            ZStack {
//                LinearGradient(
//                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.6), Color.black.opacity(0.75)],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//                .ignoresSafeArea()
//
//                GeometryReader { geometry in
//                    let horizontalInset: CGFloat = 12
//                    let cardWidth = max(0, geometry.size.width - (horizontalInset * 2))
//
//                    ZStack {
//                        ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
//                            SwipeableNewsCardView(
//                                card: card,
//                                isTopCard: index == viewModel.cards.count - 1,
//                                onTap: {
//                                    if index == viewModel.cards.count - 1 {
//                                        selectedNews = card
//                                        isShowingDetail = true
//                                    }
//                                },
//                                onSwipe: {
//                                    if index == viewModel.cards.count - 1 {
//                                        Task {
//                                            await viewModel.consumeTopCard()
//                                        }
//                                    }
//                                }
//                            )
//                            .frame(width: cardWidth, height: geometry.size.height)
//                            .offset(y: CGFloat(viewModel.cards.count - 1 - index) * 6)
//                            .scaleEffect(1 - CGFloat(viewModel.cards.count - 1 - index) * 0.03)
//                            .zIndex(Double(index))
//                            .clipped()
//                        }
//
//                        if viewModel.cards.isEmpty {
//                            VStack(spacing: 12) {
//                                if viewModel.isLoading {
//                                    ProgressView()
//                                        .tint(.white)
//                                } else {
//                                    Text("No more stories")
//                                        .font(.headline)
//                                        .foregroundStyle(.white)
//
//                                    if let loadError = viewModel.loadError {
//                                        Text(loadError)
//                                            .font(.footnote)
//                                            .multilineTextAlignment(.center)
//                                            .foregroundStyle(.white.opacity(0.85))
//                                    }
//
//                                    Button("Reload") {
//                                        Task {
//                                            await viewModel.refresh()
//                                        }
//                                    }
//                                    .buttonStyle(.borderedProminent)
//                                }
//                            }
//                            .padding(.horizontal, 24)
//                        }
//                    }
//                    .frame(width: cardWidth, height: geometry.size.height)
//                    .clipped()
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .clipped()
//            }
//            .navigationBarHidden(true)
//            .navigationDestination(isPresented: $isShowingDetail) {
//                if let selectedNews {
//                    NewsDetailView(card: selectedNews)
//                }
//            }
//            .task {
//                await viewModel.loadInitialIfNeeded()
//            }
//        }
//    }
//}
//
//struct SwipeableNewsCardView: View {
//    let card: NewsCard
//    let isTopCard: Bool
//    let onTap: () -> Void
//    let onSwipe: () -> Void
//
//    @State private var offset: CGSize = .zero
//
//    var body: some View {
//        GeometryReader { geometry in
//            VStack(spacing: 0) {
//                ZStack(alignment: .topTrailing) {
//                    Group {
//                        if let imageURL = card.imageURL {
//                            AsyncImage(url: imageURL) { phase in
//                                switch phase {
//                                case .success(let image):
//                                    image
//                                        .resizable()
//                                        .scaledToFill()
//                                default:
//                                    Rectangle()
//                                        .fill(card.imageGradient)
//                                        .overlay(alignment: .center) {
//                                            Image(systemName: card.thumbnailSymbol)
//                                                .font(.system(size: 78, weight: .bold))
//                                                .foregroundStyle(.white.opacity(0.8))
//                                        }
//                                }
//                            }
//                        } else {
//                            Rectangle()
//                                .fill(card.imageGradient)
//                                .overlay(alignment: .center) {
//                                    Image(systemName: card.thumbnailSymbol)
//                                        .font(.system(size: 78, weight: .bold))
//                                        .foregroundStyle(.white.opacity(0.8))
//                            }
//                        }
//                    }
//                    .frame(width: geometry.size.width, height: geometry.size.height * 0.5)
//                    .clipped()
//                    .overlay(alignment: .bottomLeading) {
//                        Text(card.source)
//                            .font(.caption.weight(.semibold))
//                            .foregroundStyle(.white)
//                            .padding(.horizontal, 10)
//                            .padding(.vertical, 6)
//                            .background(.black.opacity(0.55), in: Capsule())
//                            .padding(14)
//                    }
//
//                    Image(systemName: "ellipsis")
//                        .font(.headline)
//                        .foregroundStyle(.white)
//                        .padding(12)
//                        .background(.black.opacity(0.45), in: Circle())
//                        .padding(12)
//                }
//                .frame(width: geometry.size.width, height: geometry.size.height * 0.5)
//                .clipped()
//
//                VStack(alignment: .leading, spacing: 10) {
//                    Text(card.title)
//                        .font(.title3.weight(.bold))
//                        .foregroundStyle(.primary)
//                        .fixedSize(horizontal: false, vertical: true)
//
//                    Text(card.time)
//                        .font(.subheadline.weight(.medium))
//                        .foregroundStyle(.secondary)
//
//                    Text(card.summary)
//                        .font(.body)
//                        .foregroundStyle(.secondary)
//                        .lineLimit(6)
//                }
//                .padding(16)
//                .frame(width: geometry.size.width, height: geometry.size.height * 0.5, alignment: .topLeading)
//                .background(Color.white)
//                .clipped()
//            }
//            .frame(width: geometry.size.width, height: geometry.size.height)
//            .background(Color.white)
//            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
//            .overlay(
//                RoundedRectangle(cornerRadius: 24, style: .continuous)
//                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
//            )
//            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
//            .offset(offset)
//            .rotationEffect(.degrees(Double(offset.width / 18)))
//            .contentShape(Rectangle())
//            .onTapGesture {
//                if isTopCard {
//                    onTap()
//                }
//            }
//            .gesture(isTopCard ? dragGesture : nil)
//            .allowsHitTesting(isTopCard)
//            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: offset)
//        }
//    }
//
//    private var dragGesture: some Gesture {
//        DragGesture()
//            .onChanged { value in
//                offset = value.translation
//            }
//            .onEnded { value in
//                let width = value.translation.width
//                let height = value.translation.height
//                let threshold: CGFloat = 110
//
//                if abs(width) > threshold || abs(height) > threshold {
//                    let swipeX = width == 0 ? 0 : (width > 0 ? 900 : -900)
//                    let swipeY = height == 0 ? 0 : (height > 0 ? 900 : -900)
//
//                    withAnimation(.easeIn(duration: 0.22)) {
//                        offset = CGSize(width: swipeX, height: swipeY)
//                    }
//
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                        onSwipe()
//                    }
//                } else {
//                    offset = .zero
//                }
//            }
//    }
//}
//
//struct NewsDetailView: View {
//    let card: NewsCard
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 0) {
//                ZStack(alignment: .bottomLeading) {
//                    Group {
//                        if let imageURL = card.imageURL {
//                            AsyncImage(url: imageURL) { phase in
//                                switch phase {
//                                case .success(let image):
//                                    image
//                                        .resizable()
//                                        .scaledToFill()
//                                default:
//                                    Rectangle()
//                                        .fill(card.imageGradient)
//                                        .overlay {
//                                            Image(systemName: card.thumbnailSymbol)
//                                                .font(.system(size: 96, weight: .bold))
//                                                .foregroundStyle(.white.opacity(0.8))
//                                        }
//                                }
//                            }
//                        } else {
//                            Rectangle()
//                                .fill(card.imageGradient)
//                                .overlay {
//                                    Image(systemName: card.thumbnailSymbol)
//                                        .font(.system(size: 96, weight: .bold))
//                                        .foregroundStyle(.white.opacity(0.8))
//                                }
//                        }
//                    }
//                    .frame(height: 300)
//                    .clipped()
//
//                    Text(card.source)
//                        .font(.caption.weight(.semibold))
//                        .foregroundStyle(.white)
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 8)
//                        .background(.black.opacity(0.55), in: Capsule())
//                        .padding(16)
//                }
//
//                VStack(alignment: .leading, spacing: 14) {
//                    Text(card.title)
//                        .font(.title2.weight(.bold))
//
//                    Text(card.time)
//                        .font(.subheadline)
//                        .foregroundStyle(.secondary)
//
//                    HStack(spacing: 16) {
//                        Label(card.source, systemImage: "newspaper")
//                        Label("\(card.commentCount)", systemImage: "bubble.left")
//                    }
//                    .font(.subheadline.weight(.medium))
//                    .foregroundStyle(.secondary)
//
//                    Text(card.summary)
//                        .font(.body.weight(.semibold))
//                        .padding(.top, 4)
//
//                    Text(card.fullText)
//                        .font(.body)
//                        .foregroundStyle(.primary)
//                        .fixedSize(horizontal: false, vertical: true)
//                }
//                .padding(16)
//                .frame(maxWidth: .infinity, alignment: .leading)
//            }
//        }
//        .background(Color(.systemBackground))
//        .navigationTitle("News")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

struct HomeView: View {
    @StateObject private var viewModel: NewsFeedViewModel
    @State private var selectedNews: NewsCard?
    @State private var activeSheet: ActiveSheet?
    @State private var isShowingDetail = false
    private let currentUserID: String?

    init(userID: String? = nil) {
        self.currentUserID = userID
        _viewModel = StateObject(wrappedValue: NewsFeedViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let layout = HomeScreenLayout(
                    size: geometry.size,
                    safeAreaInsets: geometry.safeAreaInsets
                )
                let visibleCards = viewModel.visibleCards(maxCount: 1)

                ZStack {
                    PremiumHomeBackground()

                    VStack(spacing: layout.sectionSpacing) {
                        HomeCategoryChipsView(
                            categories: viewModel.categories,
                            selectedCategory: viewModel.selectedCategory,
                            isLoading: viewModel.isLoading,
                            onSelect: { category in
                                Task {
                                    await viewModel.selectCategory(category)
                                }
                            }
                        )
                        .frame(height: layout.categoryHeight)

                        NewsSwipeDeckView(
                            cards: visibleCards,
                            categoryLabel: currentCategoryLabel,
                            cardSize: CGSize(width: layout.cardWidth, height: layout.cardHeight),
                            deckHeight: layout.deckHeight,
                            isLoading: viewModel.isLoading,
                            loadError: viewModel.loadError,
                            emptyTitle: emptyStateTitle,
                            canAdvance: viewModel.canAdvance,
                            canRewind: viewModel.canRewind,
                            favoriteIDs: viewModel.favoriteCardIDs,
                            highlightedIDs: viewModel.highlightedCardIDs,
                            onReload: {
                                Task {
                                    await viewModel.refresh()
                                }
                            },
                            onOpen: { card in
                                selectedNews = card
                                isShowingDetail = true
                            },
                            onSwipeForward: { _ in
                                Task {
                                    await viewModel.advanceToNextCard()
                                }
                            },
                            onSwipeBackward: { _ in
                                viewModel.returnToPreviousCard()
                            },
                            onFavorite: { card in
                                Task {
                                    await viewModel.toggleFavorite(for: card)
                                }
                            },
                            onComment: { card in
                                activeSheet = .comments(card)
                            },
                            onHighlight: { card in
                                Task {
                                    await viewModel.toggleHighlight(for: card)
                                }
                            },
                            onShare: { card in
                                activeSheet = .share(card)
                            }
                        )
                        .frame(width: layout.cardWidth, height: layout.deckHeight)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.top, layout.topPadding)
                    .padding(.bottom, layout.bottomPadding)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingDetail) {
                if let selectedNews {
                    NewsDetailView(card: selectedNews)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .comments(let card):
                    NewsCommentsSheet(card: card)
                case .share(let card):
                    NewsShareSheet(card: card, currentUserID: currentUserID)
                }
            }
            .task {
                await viewModel.loadInitialIfNeeded()
            }
        }
    }

    private var emptyStateTitle: String {
        if viewModel.selectedCategory.isAll {
            return "No more stories"
        }

        return "No more \(viewModel.selectedCategory.label) stories"
    }

    private var currentCategoryLabel: String {
        viewModel.selectedCategory.isAll ? "Top" : viewModel.selectedCategory.label
    }
}

private enum ActiveSheet: Identifiable {
    case comments(NewsCard)
    case share(NewsCard)

    var id: String {
        switch self {
        case .comments(let card):
            return "comments-\(card.id)"
        case .share(let card):
            return "share-\(card.id)"
        }
    }
}

struct NewsDetailView: View {
    let card: NewsCard
    @State private var resolvedCard: NewsCard?
    @State private var isLoadingFullArticle = false

    private let service = NewsFeedService()

    private var activeCard: NewsCard {
        resolvedCard ?? card
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = layoutMetrics(
                for: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection(layout: layout)
                        .frame(maxWidth: layout.contentMaxWidth)
                        .frame(maxWidth: .infinity)

                    articlePanel(layout: layout)
                        .frame(maxWidth: layout.contentMaxWidth)
                    .padding(.horizontal, layout.outerHorizontalPadding)
                    .padding(.top, -layout.heroOverlap)
                    .padding(.bottom, layout.bottomPadding)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(
                ZStack {
                    PremiumHomeBackground()

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color(.systemGroupedBackground).opacity(0.82)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Story")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: card.id) {
                await loadFullArticleIfNeeded()
            }
        }
    }

    private func heroSection(layout: DetailLayoutMetrics) -> some View {
        ZStack(alignment: .bottomLeading) {
            heroMedia(layout: layout)

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: layout.heroMetaSpacing) {
                HStack(spacing: layout.heroPillSpacing) {
                    heroPill(title: activeCard.source, systemImage: "newspaper.fill", layout: layout)
                    heroPill(title: activeCard.time, systemImage: "clock.fill", layout: layout)
                }

                Text("Swipe through the feed, then open the full story here.")
                    .font(.system(size: layout.heroCaptionFontSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.84))
            }
            .padding(.horizontal, layout.heroOverlayHorizontalPadding)
            .padding(.bottom, layout.heroOverlayBottomPadding)
        }
        .frame(height: layout.heroHeight)
        .clipShape(
            RoundedRectangle(cornerRadius: layout.heroCornerRadius, style: .continuous)
        )
        .padding(.horizontal, layout.outerHorizontalPadding)
        .padding(.top, layout.heroTopPadding)
    }

    private func heroMedia(layout: DetailLayoutMetrics) -> some View {
        ZStack {
            placeholderHero(layout: layout)

            if let imageURL = activeCard.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    default:
                        Color.clear
                    }
                }
            }
        }
        .clipped()
    }

    private func articlePanel(layout: DetailLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: layout.articleSpacing) {
            Text("FEATURED REPORT")
                .font(.system(size: layout.eyebrowFontSize, weight: .bold))
                .tracking(layout.eyebrowTracking)
                .foregroundStyle(HomePalette.accent)

            Text(activeCard.title)
                .font(.system(size: layout.titleFontSize, weight: .bold, design: .default))
                .foregroundStyle(HomePalette.primaryText)
                .multilineTextAlignment(.leading)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: layout.detailPillSpacing) {
                    detailPill(title: readingTimeText, systemImage: "text.book.closed.fill", layout: layout)
                    detailPill(title: activeCard.time, systemImage: "clock.fill", layout: layout)
                    detailPill(title: discussionText, systemImage: "bubble.left.and.bubble.right.fill", layout: layout)
                }

                VStack(alignment: .leading, spacing: layout.detailPillSpacing) {
                    detailPill(title: readingTimeText, systemImage: "text.book.closed.fill", layout: layout)
                    detailPill(title: activeCard.time, systemImage: "clock.fill", layout: layout)
                    detailPill(title: discussionText, systemImage: "bubble.left.and.bubble.right.fill", layout: layout)
                }
            }

            if isLoadingFullArticle && needsFullArticleFetch {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Loading full article...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(HomePalette.mutedText)
                }
            }

            if shouldShowSummary {
                summaryCard(layout: layout)
            }

            bodyCard(layout: layout)
        }
        .padding(layout.articlePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(articlePanelBackground(layout: layout))
    }

    private func summaryCard(layout: DetailLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: layout.bodySpacing) {
            Text("In Brief")
                .font(.system(size: layout.summaryLabelFontSize, weight: .semibold))
                .foregroundStyle(HomePalette.accent)

            Text(articleSummaryText)
                .font(.system(size: layout.summaryFontSize, weight: .semibold))
                .foregroundStyle(HomePalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(layout.summaryPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: layout.summaryCornerRadius, style: .continuous)
                .fill(HomePalette.accentSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: layout.summaryCornerRadius, style: .continuous)
                        .stroke(HomePalette.accent.opacity(0.14), lineWidth: 1)
                )
        )
    }

    private func bodyCard(layout: DetailLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: layout.bodySpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Full Story")
                    .font(.system(size: layout.bodyHeadingFontSize, weight: .bold))
                    .foregroundStyle(HomePalette.primaryText)

                Text("Source: \(activeCard.source)")
                    .font(.system(size: layout.bodyMetaFontSize, weight: .medium))
                    .foregroundStyle(HomePalette.mutedText)
            }

            Divider()

            VStack(alignment: .leading, spacing: layout.bodySpacing) {
                ForEach(Array(articleParagraphs.enumerated()), id: \.offset) { index, paragraph in
                    Text(paragraph)
                        .font(
                            .system(
                                size: index == 0 ? layout.bodyLeadFontSize : layout.bodyFontSize,
                                weight: index == 0 ? .semibold : .regular,
                                design: .serif
                            )
                        )
                        .lineSpacing(layout.bodyLineSpacing)
                        .foregroundStyle(HomePalette.primaryText.opacity(index == 0 ? 1 : 0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func articlePanelBackground(layout: DetailLayoutMetrics) -> some View {
        RoundedRectangle(cornerRadius: layout.articleCornerRadius, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(
                color: .black.opacity(0.08),
                radius: layout.articleShadowRadius,
                x: 0,
                y: layout.articleShadowYOffset
            )
            .overlay(
                RoundedRectangle(cornerRadius: layout.articleCornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
    }

    private func heroPill(title: String, systemImage: String, layout: DetailLayoutMetrics) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: layout.heroPillFontSize, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, layout.heroPillHorizontalPadding)
            .padding(.vertical, layout.heroPillVerticalPadding)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func detailPill(title: String, systemImage: String, layout: DetailLayoutMetrics) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: layout.detailPillFontSize, weight: .semibold))
            .foregroundStyle(HomePalette.mutedText)
            .padding(.horizontal, layout.detailPillHorizontalPadding)
            .padding(.vertical, layout.detailPillVerticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(HomePalette.softFill)
            )
    }

    private var articleSummaryText: String {
        activeCard.summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var articleBodyText: String {
        let fullText = activeCard.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        return fullText.isEmpty ? articleSummaryText : fullText
    }

    private var needsFullArticleFetch: Bool {
        let summary = card.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = card.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !card.id.isEmpty && ((fullText.isEmpty) || (!summary.isEmpty && fullText == summary))
    }

    private var articleParagraphs: [String] {
        let normalizedBody = articleBodyText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let separated = normalizedBody
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !separated.isEmpty {
            return separated
        }

        guard !normalizedBody.isEmpty else { return [articleSummaryText] }
        return [normalizedBody]
    }

    private var shouldShowSummary: Bool {
        !articleSummaryText.isEmpty && articleSummaryText != articleBodyText
    }

    private var discussionText: String {
        activeCard.commentCount > 0 ? "\(activeCard.commentCount) comments" : "Discussion open"
    }

    private var readingTimeText: String {
        let text = [activeCard.summary, activeCard.fullText]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
        let minutes = max(1, Int(ceil(Double(wordCount) / 180.0)))
        return "\(minutes) min read"
    }

    private func placeholderHero(layout: DetailLayoutMetrics) -> some View {
        Rectangle()
            .fill(activeCard.imageGradient)
            .overlay {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: layout.placeholderLargeCircleSize, height: layout.placeholderLargeCircleSize)
                        .offset(x: layout.placeholderLargeCircleOffset.width, y: layout.placeholderLargeCircleOffset.height)

                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: layout.placeholderSmallCircleSize, height: layout.placeholderSmallCircleSize)
                        .offset(x: layout.placeholderSmallCircleOffset.width, y: layout.placeholderSmallCircleOffset.height)

                    Image(systemName: activeCard.thumbnailSymbol)
                        .font(.system(size: layout.placeholderIconSize, weight: .bold))
                        .foregroundStyle(.white.opacity(0.84))
                }
            }
    }

    private func loadFullArticleIfNeeded() async {
        guard needsFullArticleFetch else { return }
        guard !isLoadingFullArticle else { return }

        isLoadingFullArticle = true
        defer { isLoadingFullArticle = false }

        if let detailedCard = try? await service.fetchDetailedCard(id: card.id, fallbackCard: card) {
            resolvedCard = detailedCard
        }
    }

    private func layoutMetrics(for size: CGSize, safeAreaInsets: EdgeInsets) -> DetailLayoutMetrics {
        let width = size.width.isFinite ? max(size.width, 1) : 1
        let height = size.height.isFinite ? max(size.height, 1) : 1
        let aspectRatio = width / height
        let isLandscape = aspectRatio > 1
        let isCompactWidth = width < 390
        let isCompactHeight = height < 720

        let outerHorizontalPadding = max(min(width * 0.045, 24), 12)
        let availableContentWidth = max(width - (outerHorizontalPadding * 2), 1)
        let contentMaxWidth = min(availableContentWidth, isLandscape ? 780 : 700)
        let heroHeightBase = isLandscape ? height * 0.5 : width * 0.9
        let heroHeight = min(
            max(heroHeightBase, isCompactHeight ? 240 : 290),
            isLandscape ? 360 : 440
        )
        let heroCornerRadius = isCompactWidth ? 26.0 : 34.0
        let heroTopPadding = isCompactHeight ? 8.0 : 12.0
        let heroOverlayHorizontalPadding = isCompactWidth ? 16.0 : 20.0
        let heroOverlayBottomPadding = isCompactHeight ? 18.0 : 24.0
        let heroPillFontSize = isCompactWidth ? 11.0 : 12.0
        let heroPillHorizontalPadding = isCompactWidth ? 10.0 : 12.0
        let heroPillVerticalPadding = isCompactWidth ? 7.0 : 8.0
        let heroPillSpacing = isCompactWidth ? 6.0 : 8.0
        let heroMetaSpacing = isCompactWidth ? 10.0 : 12.0
        let heroCaptionFontSize = isCompactWidth ? 12.0 : 13.0
        let heroOverlap = min(max(heroHeight * 0.12, 26), 48)
        let articleSpacing = isCompactHeight ? 16.0 : 20.0
        let articlePadding = isCompactWidth ? 20.0 : 24.0
        let articleCornerRadius = isCompactWidth ? 28.0 : 32.0
        let articleShadowRadius = isCompactWidth ? 16.0 : 20.0
        let articleShadowYOffset = isCompactWidth ? 10.0 : 12.0
        let eyebrowFontSize = isCompactWidth ? 11.0 : 12.0
        let eyebrowTracking = isCompactWidth ? 1.1 : 1.4
        let titleFontSize = min(
            max(width * (isLandscape ? 0.042 : 0.076), isCompactWidth ? 25.0 : 28.0),
            isLandscape ? 34.0 : 40.0
        )
        let detailPillFontSize = isCompactWidth ? 11.0 : 12.0
        let detailPillHorizontalPadding = isCompactWidth ? 10.0 : 12.0
        let detailPillVerticalPadding = isCompactWidth ? 7.0 : 8.0
        let detailPillSpacing = isCompactWidth ? 8.0 : 10.0
        let summaryPadding = isCompactWidth ? 18.0 : 20.0
        let summaryCornerRadius = isCompactWidth ? 22.0 : 26.0
        let summaryLabelFontSize = isCompactWidth ? 12.0 : 13.0
        let summaryFontSize = isCompactWidth ? 16.0 : (isLandscape ? 16.5 : 17.5)
        let bodySpacing = isCompactHeight ? 12.0 : 16.0
        let bodyHeadingFontSize = isCompactWidth ? 17.0 : 19.0
        let bodyMetaFontSize = isCompactWidth ? 13.0 : 14.0
        let bodyLeadFontSize = min(max(width * 0.05, 18.0), isLandscape ? 19.0 : 21.0)
        let bodyFontSize = min(max(width * 0.044, 16.0), isLandscape ? 17.5 : 18.5)
        let bodyLineSpacing = isCompactWidth ? 5.0 : 7.0
        let bottomPadding = max(28.0, safeAreaInsets.bottom + 20.0)
        let placeholderLargeCircleSize = min(max(heroHeight * 0.56, 150.0), 220.0)
        let placeholderSmallCircleSize = min(max(heroHeight * 0.4, 108.0), 160.0)
        let placeholderIconSize = min(max(heroHeight * 0.27, 72.0), 108.0)

        return DetailLayoutMetrics(
            outerHorizontalPadding: outerHorizontalPadding,
            contentMaxWidth: contentMaxWidth,
            bottomPadding: bottomPadding,
            heroHeight: heroHeight,
            heroCornerRadius: heroCornerRadius,
            heroTopPadding: heroTopPadding,
            heroOverlayHorizontalPadding: heroOverlayHorizontalPadding,
            heroOverlayBottomPadding: heroOverlayBottomPadding,
            heroPillFontSize: heroPillFontSize,
            heroPillHorizontalPadding: heroPillHorizontalPadding,
            heroPillVerticalPadding: heroPillVerticalPadding,
            heroPillSpacing: heroPillSpacing,
            heroMetaSpacing: heroMetaSpacing,
            heroCaptionFontSize: heroCaptionFontSize,
            heroOverlap: heroOverlap,
            articleSpacing: articleSpacing,
            articlePadding: articlePadding,
            articleCornerRadius: articleCornerRadius,
            articleShadowRadius: articleShadowRadius,
            articleShadowYOffset: articleShadowYOffset,
            eyebrowFontSize: eyebrowFontSize,
            eyebrowTracking: eyebrowTracking,
            titleFontSize: titleFontSize,
            detailPillFontSize: detailPillFontSize,
            detailPillHorizontalPadding: detailPillHorizontalPadding,
            detailPillVerticalPadding: detailPillVerticalPadding,
            detailPillSpacing: detailPillSpacing,
            summaryPadding: summaryPadding,
            summaryCornerRadius: summaryCornerRadius,
            summaryLabelFontSize: summaryLabelFontSize,
            summaryFontSize: summaryFontSize,
            bodySpacing: bodySpacing,
            bodyHeadingFontSize: bodyHeadingFontSize,
            bodyMetaFontSize: bodyMetaFontSize,
            bodyLeadFontSize: bodyLeadFontSize,
            bodyFontSize: bodyFontSize,
            bodyLineSpacing: bodyLineSpacing,
            placeholderLargeCircleSize: placeholderLargeCircleSize,
            placeholderLargeCircleOffset: CGSize(
                width: placeholderLargeCircleSize * 0.44,
                height: -(placeholderLargeCircleSize * 0.26)
            ),
            placeholderSmallCircleSize: placeholderSmallCircleSize,
            placeholderSmallCircleOffset: CGSize(
                width: -(placeholderSmallCircleSize * 0.7),
                height: placeholderSmallCircleSize * 0.62
            ),
            placeholderIconSize: placeholderIconSize
        )
    }

    private struct DetailLayoutMetrics {
        let outerHorizontalPadding: CGFloat
        let contentMaxWidth: CGFloat
        let bottomPadding: CGFloat
        let heroHeight: CGFloat
        let heroCornerRadius: CGFloat
        let heroTopPadding: CGFloat
        let heroOverlayHorizontalPadding: CGFloat
        let heroOverlayBottomPadding: CGFloat
        let heroPillFontSize: CGFloat
        let heroPillHorizontalPadding: CGFloat
        let heroPillVerticalPadding: CGFloat
        let heroPillSpacing: CGFloat
        let heroMetaSpacing: CGFloat
        let heroCaptionFontSize: CGFloat
        let heroOverlap: CGFloat
        let articleSpacing: CGFloat
        let articlePadding: CGFloat
        let articleCornerRadius: CGFloat
        let articleShadowRadius: CGFloat
        let articleShadowYOffset: CGFloat
        let eyebrowFontSize: CGFloat
        let eyebrowTracking: CGFloat
        let titleFontSize: CGFloat
        let detailPillFontSize: CGFloat
        let detailPillHorizontalPadding: CGFloat
        let detailPillVerticalPadding: CGFloat
        let detailPillSpacing: CGFloat
        let summaryPadding: CGFloat
        let summaryCornerRadius: CGFloat
        let summaryLabelFontSize: CGFloat
        let summaryFontSize: CGFloat
        let bodySpacing: CGFloat
        let bodyHeadingFontSize: CGFloat
        let bodyMetaFontSize: CGFloat
        let bodyLeadFontSize: CGFloat
        let bodyFontSize: CGFloat
        let bodyLineSpacing: CGFloat
        let placeholderLargeCircleSize: CGFloat
        let placeholderLargeCircleOffset: CGSize
        let placeholderSmallCircleSize: CGFloat
        let placeholderSmallCircleOffset: CGSize
        let placeholderIconSize: CGFloat
    }
}
private struct NewsCommentsSheet: View {
    let card: NewsCard
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: NewsCommentsViewModel

    init(card: NewsCard) {
        self.card = card
        let user = Auth.auth().currentUser
        _viewModel = StateObject(
            wrappedValue: NewsCommentsViewModel(
                newsID: card.id,
                currentUserID: user?.uid,
                currentUsername: user?.displayName ?? "User"
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                commentComposer
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()

                if viewModel.isLoading && viewModel.comments.isEmpty {
                    Spacer()
                    ProgressView("Loading comments...")
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(viewModel.comments) { comment in
                                commentRow(comment)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadComments()
            }
        }
    }

    private var commentComposer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Add a comment...", text: $viewModel.newCommentText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button("Post") {
                Task {
                    await viewModel.postComment()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
        }
    }

    @ViewBuilder
    private func commentRow(_ comment: CommentThreadItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarCircleView(
                username: comment.username,
                avatarColorHex: comment.avatarColorHex,
                avatarImageBase64: comment.avatarImageBase64,
                fontSize: 14
            )
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 10) {
                authorMeta(name: comment.username, date: comment.createdAt)

                Text(comment.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                voteRow(
                    userVote: comment.userVote,
                    score: comment.score,
                    upvoteAction: {
                        Task {
                            await viewModel.voteComment(commentID: comment.id, direction: .up)
                        }
                    },
                    downvoteAction: {
                        Task {
                            await viewModel.voteComment(commentID: comment.id, direction: .down)
                        }
                    }
                )

                Button {
                    viewModel.toggleReplyComposer(for: comment.id)
                } label: {
                    Text(viewModel.replyTargetCommentID == comment.id ? "Cancel" : "Reply")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if viewModel.replyTargetCommentID == comment.id {
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("Write a reply...", text: $viewModel.replyText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1...4)

                        Button("Send") {
                            Task {
                                await viewModel.postReply(parentCommentID: comment.id)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
                    }
                    .padding(.top, 2)
                }

                if !comment.replies.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(comment.replies) { reply in
                            replyRow(commentID: comment.id, reply: reply)
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func replyRow(commentID: String, reply: ReplyItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarCircleView(
                username: reply.username,
                avatarColorHex: reply.avatarColorHex,
                avatarImageBase64: reply.avatarImageBase64,
                fontSize: 12
            )
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 8) {
                authorMeta(name: reply.username, date: reply.createdAt)

                Text(reply.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                voteRow(
                    userVote: reply.userVote,
                    score: reply.score,
                    upvoteAction: {
                        Task {
                            await viewModel.voteReply(commentID: commentID, replyID: reply.id, direction: .up)
                        }
                    },
                    downvoteAction: {
                        Task {
                            await viewModel.voteReply(commentID: commentID, replyID: reply.id, direction: .down)
                        }
                    }
                )
            }
        }
        .padding(10)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func authorMeta(name: String, date: Date) -> some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.subheadline.weight(.semibold))

            Text(Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date()))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func voteRow(
        userVote: Int,
        score: Int,
        upvoteAction: @escaping () -> Void,
        downvoteAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Button(action: upvoteAction) {
                Image(systemName: userVote == 1 ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(userVote == 1 ? .green : .secondary)

            Text("\(score)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: downvoteAction) {
                Image(systemName: userVote == -1 ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(userVote == -1 ? .red : .secondary)
        }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

@MainActor
private final class NewsCommentsViewModel: ObservableObject {
    @Published private(set) var comments: [CommentThreadItem] = []
    @Published var newCommentText: String = ""
    @Published var replyText: String = ""
    @Published var replyTargetCommentID: String?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let currentUserID: String?
    private let currentUsername: String
    private let store: NewsCommentsStore

    init(newsID: String, currentUserID: String?, currentUsername: String) {
        self.currentUserID = currentUserID
        self.currentUsername = currentUsername
        self.store = NewsCommentsStore(newsID: newsID)
    }

    func loadComments() async {
        isLoading = true
        defer { isLoading = false }

        do {
            comments = try await store.fetchComments(currentUserID: currentUserID)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load comments."
        }
    }

    func postComment() async {
        guard let currentUserID else {
            errorMessage = "You need to be signed in to comment."
            return
        }

        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await store.addComment(text: text, userID: currentUserID, username: currentUsername)
            newCommentText = ""
            await loadComments()
        } catch {
            errorMessage = "Unable to post comment."
        }
    }

    func postReply(parentCommentID: String) async {
        guard let currentUserID else {
            errorMessage = "You need to be signed in to reply."
            return
        }

        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await store.addReply(
                parentCommentID: parentCommentID,
                text: text,
                userID: currentUserID,
                username: currentUsername
            )
            replyText = ""
            replyTargetCommentID = nil
            await loadComments()
        } catch {
            errorMessage = "Unable to post reply."
        }
    }

    func voteComment(commentID: String, direction: VoteDirection) async {
        guard let currentUserID else {
            errorMessage = "You need to be signed in to vote."
            return
        }

        do {
            try await store.voteComment(commentID: commentID, userID: currentUserID, direction: direction)
            await loadComments()
        } catch {
            errorMessage = "Unable to update vote."
        }
    }

    func voteReply(commentID: String, replyID: String, direction: VoteDirection) async {
        guard let currentUserID else {
            errorMessage = "You need to be signed in to vote."
            return
        }

        do {
            try await store.voteReply(commentID: commentID, replyID: replyID, userID: currentUserID, direction: direction)
            await loadComments()
        } catch {
            errorMessage = "Unable to update vote."
        }
    }

    func toggleReplyComposer(for commentID: String) {
        if replyTargetCommentID == commentID {
            replyTargetCommentID = nil
            replyText = ""
        } else {
            replyTargetCommentID = commentID
            replyText = ""
        }
    }
}

private struct CommentThreadItem: Identifiable {
    let id: String
    let text: String
    let userID: String
    let username: String
    let avatarColorHex: String
    let avatarImageBase64: String?
    let createdAt: Date
    let upvotes: Int
    let downvotes: Int
    let userVote: Int
    let replies: [ReplyItem]

    var score: Int {
        upvotes - downvotes
    }
}

private struct ReplyItem: Identifiable {
    let id: String
    let text: String
    let userID: String
    let username: String
    let avatarColorHex: String
    let avatarImageBase64: String?
    let createdAt: Date
    let upvotes: Int
    let downvotes: Int
    let userVote: Int

    var score: Int {
        upvotes - downvotes
    }
}

private struct CommentAuthorSnapshot {
    let username: String
    let avatarColorHex: String
    let avatarImageBase64: String?

    static let defaultAvatarColorHex = "#0984E3"
}

private enum VoteDirection {
    case up
    case down

    var rawValue: Int {
        switch self {
        case .up:
            return 1
        case .down:
            return -1
        }
    }
}

private struct NewsCommentsStore {
    private let db = Firestore.firestore()
    private let newsID: String

    init(newsID: String) {
        self.newsID = newsID
    }

    private var commentsRef: CollectionReference {
        db.collection("newsComments").document(newsID).collection("comments")
    }

    func fetchComments(currentUserID: String?) async throws -> [CommentThreadItem] {
        let snapshot = try await commentsRef
            .order(by: "createdAt", descending: false)
            .getDocuments()

        var result: [CommentThreadItem] = []
        result.reserveCapacity(snapshot.documents.count)
        var authorCache: [String: CommentAuthorSnapshot] = [:]

        for document in snapshot.documents {
            let data = document.data()
            let commentID = document.documentID
            let commentRef = commentsRef.document(commentID)

            let repliesSnapshot = try await commentRef.collection("replies")
                .order(by: "createdAt", descending: false)
                .getDocuments()

            let commentVote = try await fetchUserVote(
                from: commentRef.collection("votes"),
                userID: currentUserID
            )

            var replies: [ReplyItem] = []
            replies.reserveCapacity(repliesSnapshot.documents.count)

            for replyDocument in repliesSnapshot.documents {
                let replyData = replyDocument.data()
                let replyUserID = (replyData["userID"] as? String) ?? ""
                let replyRef = commentRef.collection("replies").document(replyDocument.documentID)
                let replyVote = try await fetchUserVote(
                    from: replyRef.collection("votes"),
                    userID: currentUserID
                )
                let replyFallback = CommentAuthorSnapshot(
                    username: (replyData["username"] as? String) ?? "User",
                    avatarColorHex: (replyData["avatarColorHex"] as? String) ?? CommentAuthorSnapshot.defaultAvatarColorHex,
                    avatarImageBase64: replyData["avatarImageBase64"] as? String
                )
                let replyAuthor: CommentAuthorSnapshot
                if let cachedAuthor = authorCache[replyUserID], !replyUserID.isEmpty {
                    replyAuthor = cachedAuthor
                } else {
                    replyAuthor = await resolveAuthor(userID: replyUserID, fallback: replyFallback)
                    if !replyUserID.isEmpty {
                        authorCache[replyUserID] = replyAuthor
                    }
                }

                replies.append(
                    ReplyItem(
                        id: replyDocument.documentID,
                        text: (replyData["text"] as? String) ?? "",
                        userID: replyUserID,
                        username: replyAuthor.username,
                        avatarColorHex: replyAuthor.avatarColorHex,
                        avatarImageBase64: replyAuthor.avatarImageBase64,
                        createdAt: timestamp(from: replyData["createdAt"]),
                        upvotes: (replyData["upvoteCount"] as? Int) ?? 0,
                        downvotes: (replyData["downvoteCount"] as? Int) ?? 0,
                        userVote: replyVote
                    )
                )
            }

            let commentUserID = (data["userID"] as? String) ?? ""
            let commentFallback = CommentAuthorSnapshot(
                username: (data["username"] as? String) ?? "User",
                avatarColorHex: (data["avatarColorHex"] as? String) ?? CommentAuthorSnapshot.defaultAvatarColorHex,
                avatarImageBase64: data["avatarImageBase64"] as? String
            )
            let commentAuthor: CommentAuthorSnapshot
            if let cachedAuthor = authorCache[commentUserID], !commentUserID.isEmpty {
                commentAuthor = cachedAuthor
            } else {
                commentAuthor = await resolveAuthor(userID: commentUserID, fallback: commentFallback)
                if !commentUserID.isEmpty {
                    authorCache[commentUserID] = commentAuthor
                }
            }

            result.append(
                CommentThreadItem(
                    id: commentID,
                    text: (data["text"] as? String) ?? "",
                    userID: commentUserID,
                    username: commentAuthor.username,
                    avatarColorHex: commentAuthor.avatarColorHex,
                    avatarImageBase64: commentAuthor.avatarImageBase64,
                    createdAt: timestamp(from: data["createdAt"]),
                    upvotes: (data["upvoteCount"] as? Int) ?? 0,
                    downvotes: (data["downvoteCount"] as? Int) ?? 0,
                    userVote: commentVote,
                    replies: replies
                )
            )
        }

        return result
    }

    func addComment(text: String, userID: String, username: String) async throws {
        let author = await currentAuthorSnapshot(userID: userID, fallbackUsername: username)
        let doc = commentsRef.document()
        var payload: [String: Any] = [
            "id": doc.documentID,
            "newsID": newsID,
            "text": text,
            "userID": userID,
            "username": author.username,
            "avatarColorHex": author.avatarColorHex,
            "upvoteCount": 0,
            "downvoteCount": 0,
            "replyCount": 0,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let avatarImageBase64 = author.avatarImageBase64, !avatarImageBase64.isEmpty {
            payload["avatarImageBase64"] = avatarImageBase64
        }

        try await doc.setData(payload, merge: false)
    }

    func addReply(parentCommentID: String, text: String, userID: String, username: String) async throws {
        let author = await currentAuthorSnapshot(userID: userID, fallbackUsername: username)
        let commentRef = commentsRef.document(parentCommentID)
        let replyRef = commentRef.collection("replies").document()

        var payload: [String: Any] = [
            "id": replyRef.documentID,
            "newsID": newsID,
            "parentCommentID": parentCommentID,
            "text": text,
            "userID": userID,
            "username": author.username,
            "avatarColorHex": author.avatarColorHex,
            "upvoteCount": 0,
            "downvoteCount": 0,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let avatarImageBase64 = author.avatarImageBase64, !avatarImageBase64.isEmpty {
            payload["avatarImageBase64"] = avatarImageBase64
        }

        try await replyRef.setData(payload, merge: false)

        try await commentRef.setData([
            "replyCount": FieldValue.increment(Int64(1))
        ], merge: true)
    }

    func voteComment(commentID: String, userID: String, direction: VoteDirection) async throws {
        let commentRef = commentsRef.document(commentID)
        try await vote(
            targetRef: commentRef,
            votesCollection: commentRef.collection("votes"),
            userID: userID,
            newVote: direction.rawValue
        )
    }

    func voteReply(commentID: String, replyID: String, userID: String, direction: VoteDirection) async throws {
        let replyRef = commentsRef.document(commentID).collection("replies").document(replyID)
        try await vote(
            targetRef: replyRef,
            votesCollection: replyRef.collection("votes"),
            userID: userID,
            newVote: direction.rawValue
        )
    }

    private func vote(
        targetRef: DocumentReference,
        votesCollection: CollectionReference,
        userID: String,
        newVote: Int
    ) async throws {
        let voteRef = votesCollection.document(userID)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction { transaction, errorPointer in
                do {
                    let voteSnapshot = try transaction.getDocument(voteRef)
                    let previousVote = voteSnapshot.data()?["value"] as? Int ?? 0
                    let effectiveVote = previousVote == newVote ? 0 : newVote

                    let upvoteDelta = (effectiveVote == 1 ? 1 : 0) - (previousVote == 1 ? 1 : 0)
                    let downvoteDelta = (effectiveVote == -1 ? 1 : 0) - (previousVote == -1 ? 1 : 0)

                    transaction.setData([
                        "upvoteCount": FieldValue.increment(Int64(upvoteDelta)),
                        "downvoteCount": FieldValue.increment(Int64(downvoteDelta))
                    ], forDocument: targetRef, merge: true)

                    if effectiveVote == 0 {
                        transaction.deleteDocument(voteRef)
                    } else {
                        transaction.setData([
                            "userID": userID,
                            "value": effectiveVote,
                            "updatedAt": FieldValue.serverTimestamp()
                        ], forDocument: voteRef, merge: true)
                    }

                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            } completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func fetchUserVote(from votesRef: CollectionReference, userID: String?) async throws -> Int {
        guard let userID, !userID.isEmpty else { return 0 }

        let voteSnapshot = try await votesRef.document(userID).getDocument()
        return voteSnapshot.data()?["value"] as? Int ?? 0
    }

    private func currentAuthorSnapshot(userID: String, fallbackUsername: String) async -> CommentAuthorSnapshot {
        guard !userID.isEmpty else {
            return CommentAuthorSnapshot(
                username: fallbackUsername,
                avatarColorHex: CommentAuthorSnapshot.defaultAvatarColorHex,
                avatarImageBase64: nil
            )
        }

        do {
            let snapshot = try await db.collection("users").document(userID).getDocument()
            let data = snapshot.data() ?? [:]

            return CommentAuthorSnapshot(
                username: (data["username"] as? String) ?? fallbackUsername,
                avatarColorHex: (data["avatarColorHex"] as? String) ?? CommentAuthorSnapshot.defaultAvatarColorHex,
                avatarImageBase64: data["avatarImageBase64"] as? String
            )
        } catch {
            return CommentAuthorSnapshot(
                username: fallbackUsername,
                avatarColorHex: CommentAuthorSnapshot.defaultAvatarColorHex,
                avatarImageBase64: nil
            )
        }
    }

    private func resolveAuthor(
        userID: String,
        fallback: CommentAuthorSnapshot
    ) async -> CommentAuthorSnapshot {
        guard !userID.isEmpty else { return fallback }

        do {
            let snapshot = try await db.collection("users").document(userID).getDocument()
            let data = snapshot.data() ?? [:]
            return CommentAuthorSnapshot(
                username: (data["username"] as? String) ?? fallback.username,
                avatarColorHex: (data["avatarColorHex"] as? String) ?? fallback.avatarColorHex,
                avatarImageBase64: (data["avatarImageBase64"] as? String) ?? fallback.avatarImageBase64
            )
        } catch {
            return fallback
        }
    }

    private func timestamp(from value: Any?) -> Date {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        return Date()
    }
}
