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
                let screenAspectRatio = geometry.size.width / max(geometry.size.height, 1)
                let isLandscape = screenAspectRatio > 1
                let horizontalPadding = max(geometry.size.width * (isLandscape ? 0.05 : 0.04), 12)
                let topPadding = max(geometry.safeAreaInsets.top + 8, 12)
                let bottomPadding = max(geometry.safeAreaInsets.bottom + 8, 12)
                let contentSpacing = max(min(geometry.size.height * 0.02, 18), 12)
                let categoryBarHeight = max(min(geometry.size.height * (isLandscape ? 0.11 : 0.08), 56), 48)
                let availableCardWidth = max(0, geometry.size.width - (horizontalPadding * 2))
                let availableContentHeight = max(0, geometry.size.height - topPadding - bottomPadding)
                let availableCardHeight = max(0, availableContentHeight - categoryBarHeight - contentSpacing)
                let stackSpacing: CGFloat = 8
                let visibleStackDepth = 2
                let stackLift = CGFloat(visibleStackDepth) * stackSpacing
                let preferredCardAspectRatio = isLandscape
                    ? min(max(screenAspectRatio * 0.85, 0.95), 1.35)
                    : min(max(screenAspectRatio * 1.08, 0.50), 0.68)
                let maxCardHeight = max(0, availableCardHeight - stackLift)
                let cardWidth = min(availableCardWidth, maxCardHeight * preferredCardAspectRatio)
                let cardHeight = min(maxCardHeight, cardWidth / preferredCardAspectRatio)

                ZStack {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.85),
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: contentSpacing) {
                        categoryBar(height: categoryBarHeight)

                        ZStack {
                            ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                                let depth = min(max(viewModel.cards.count - 1 - index, 0), visibleStackDepth)

                                SwipeableNewsCardView(
                                    card: card,
                                    isTopCard: index == viewModel.cards.count - 1,
                                    isFavorite: viewModel.isFavorite(card),
                                    isHighlighted: viewModel.isHighlighted(card),
                                    onTap: {
                                        if index == viewModel.cards.count - 1 {
                                            selectedNews = card
                                            isShowingDetail = true
                                        }
                                    },
                                    onSwipe: {
                                        if index == viewModel.cards.count - 1 {
                                            Task {
                                                await viewModel.consumeTopCard()
                                            }
                                        }
                                    },
                                    onFavoriteTap: {
                                        Task {
                                            await viewModel.toggleFavorite(for: card)
                                        }
                                    },
                                    onCommentTap: {
                                        activeSheet = .comments(card)
                                    },
                                    onHighlightTap: {
                                        Task {
                                            await viewModel.toggleHighlight(for: card)
                                        }
                                    },
                                    onShareSwipe: {
                                        if index == viewModel.cards.count - 1 {
                                            activeSheet = .share(card)
                                        }
                                    }
                                )
                                .frame(width: cardWidth)
                                .frame(height: cardHeight)
                                .offset(y: CGFloat(depth) * stackSpacing)
                                .zIndex(Double(index))
                            }

                            if viewModel.cards.isEmpty {
                                VStack(spacing: 12) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text(emptyStateTitle)
                                            .font(.headline)
                                            .foregroundStyle(.white)

                                        if let loadError = viewModel.loadError {
                                            Text(loadError)
                                                .font(.footnote)
                                                .multilineTextAlignment(.center)
                                                .foregroundStyle(.white.opacity(0.85))
                                        }

                                        Button("Reload") {
                                            Task {
                                                await viewModel.refresh()
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .frame(width: cardWidth)
                        .frame(height: cardHeight + stackLift)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)
                }
            }
            .navigationBarHidden(true)
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

    private func categoryBar(height: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.categories) { category in
                        let isSelected = viewModel.selectedCategory == category

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(category.id, anchor: .center)
                            }

                            Task {
                                await viewModel.selectCategory(category)
                            }
                        } label: {
                            categoryChip(label: category.label, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                        .id(category.id)
                    }
                }
                .padding(.horizontal, 14)
            }
            .scrollIndicators(.hidden)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .overlay(alignment: .trailing) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                        .padding(.trailing, 16)
                }
            }
            .onChange(of: viewModel.selectedCategory.id, initial: true) { _, selectedID in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
    }

    private func categoryChip(label: String, isSelected: Bool) -> some View {
        let foregroundColor: Color = isSelected ? .black : Color.white.opacity(0.94)
        let backgroundColor: Color = isSelected ? .white : Color.white.opacity(0.12)
        let borderColor: Color = isSelected ? Color.white.opacity(0.8) : Color.white.opacity(0.16)

        return Text(label)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(foregroundColor)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
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

struct SwipeableNewsCardView: View {
    let card: NewsCard
    let isTopCard: Bool
    let isFavorite: Bool
    let isHighlighted: Bool
    let onTap: () -> Void
    let onSwipe: () -> Void
    let onFavoriteTap: () -> Void
    let onCommentTap: () -> Void
    let onHighlightTap: () -> Void
    let onShareSwipe: () -> Void

    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let layout = layoutMetrics(for: geometry.size)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    newsImage
                        .frame(maxWidth: .infinity)
                        .frame(height: layout.imageHeight)
                        .clipped()

                    VStack(alignment: .leading, spacing: layout.contentSpacing) {
                        Text(card.title)
                            .font(.system(size: layout.titleFontSize, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(layout.titleLineLimit)
                            .multilineTextAlignment(.leading)

                        Text(card.time)
                            .font(.system(size: layout.metadataFontSize, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(card.summary)
                            .font(.system(size: layout.summaryFontSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(layout.summaryLineLimit)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: layout.contentSpacing)

                        Text(card.source)
                            .font(.system(size: layout.sourceFontSize, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.95), in: Capsule())
                    }
                    .padding(layout.contentPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.white)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isTopCard {
                        onTap()
                    }
                }

                Divider()

                HStack(spacing: 0) {
                    actionButton(
                        title: "Favorite",
                        systemImage: isFavorite ? "heart.fill" : "heart",
                        isActive: isFavorite,
                        activeColor: .red,
                        action: onFavoriteTap
                    )
                    actionButton(
                        title: "Comment",
                        systemImage: "bubble.right",
                        action: onCommentTap
                    )
                    actionButton(
                        title: "Highlight",
                        systemImage: isHighlighted ? "highlighter" : "highlighter",
                        isActive: isHighlighted,
                        activeColor: .yellow,
                        action: onHighlightTap
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, layout.actionBarPadding)
                .background(Color.white)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "ellipsis")
                    .font(.system(size: layout.ellipsisFontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(layout.ellipsisInnerPadding)
                    .background(.black.opacity(0.95), in: Circle())
                    .padding(layout.overlayPadding)
            }
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 18)))
            .contentShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
            .gesture(isTopCard ? dragGesture : nil)
            .allowsHitTesting(isTopCard)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: offset)
        }
    }

    @ViewBuilder
    private var newsImage: some View {
        if let imageURL = card.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure(_), .empty:
                    placeholderImage

                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(card.imageGradient)
            .overlay {
                Image(systemName: card.thumbnailSymbol)
                    .font(.system(size: 78, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        systemImage: String,
        isActive: Bool = false,
        activeColor: Color = .red,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(isActive ? activeColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                let threshold: CGFloat = 110
                let isShareSwipe = height < -threshold && abs(height) > abs(width) * 1.1

                if isShareSwipe {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                        offset = CGSize(width: 0, height: -54)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        onShareSwipe()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            offset = .zero
                        }
                    }
                    return
                }

                if abs(width) > threshold || abs(height) > threshold {
                    let swipeX = width == 0 ? 0 : (width > 0 ? 900 : -900)
                    let swipeY = height == 0 ? 0 : (height > 0 ? 900 : -900)

                    withAnimation(.easeIn(duration: 0.22)) {
                        offset = CGSize(width: swipeX, height: swipeY)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onSwipe()
                    }
                } else {
                    offset = .zero
                }
            }
    }

    private func layoutMetrics(for size: CGSize) -> LayoutMetrics {
        let width = size.width
        let height = size.height
        let aspectRatio = width / max(height, 1)
        let isCompactHeight = height < 620
        let isCompactWidth = width < 360
        let contentPadding = isCompactWidth ? 14.0 : 18.0
        let contentSpacing = isCompactHeight ? 8.0 : 10.0
        let titleFontSize = min(max(width * 0.066, isCompactWidth ? 20.0 : 22.0), 30.0)
        let metadataFontSize = isCompactHeight ? 13.0 : 15.0
        let summaryFontSize = isCompactHeight || isCompactWidth ? 14.0 : 16.0
        let sourceFontSize = max(metadataFontSize - 1.0, 12.0)
        let titleLineLimit = isCompactHeight || isCompactWidth ? 2 : 3
        let imageHeightRatio = min(max(0.52 - (aspectRatio * 0.14), 0.33), isCompactHeight ? 0.42 : 0.47)
        let imageHeight = min(max(height * imageHeightRatio, isCompactHeight ? 190.0 : 220.0), height * 0.5)
        let actionBarPadding = isCompactHeight ? 8.0 : 10.0
        let actionSectionHeight = actionBarPadding * 2 + 34.0
        let estimatedTitleHeight = CGFloat(titleLineLimit) * titleFontSize * 1.16
        let estimatedSummaryLineHeight = summaryFontSize * 1.35
        let reservedContentHeight = (contentPadding * 2) + (contentSpacing * 3) + estimatedTitleHeight + (metadataFontSize * 1.3) + 36.0
        let summaryAvailableHeight = max(estimatedSummaryLineHeight * 2, height - imageHeight - actionSectionHeight - reservedContentHeight)
        let summaryLineLimit = min(max(Int(summaryAvailableHeight / estimatedSummaryLineHeight), 2), isCompactHeight ? 4 : 6)
        let overlayPadding = isCompactWidth ? 12.0 : 14.0
        let ellipsisFontSize = isCompactWidth ? 14.0 : 16.0
        let ellipsisInnerPadding = isCompactWidth ? 11.0 : 12.0

        return LayoutMetrics(
            cornerRadius: 24,
            imageHeight: imageHeight,
            contentPadding: contentPadding,
            contentSpacing: contentSpacing,
            titleFontSize: titleFontSize,
            metadataFontSize: metadataFontSize,
            summaryFontSize: summaryFontSize,
            sourceFontSize: sourceFontSize,
            titleLineLimit: titleLineLimit,
            summaryLineLimit: summaryLineLimit,
            actionBarPadding: actionBarPadding,
            overlayPadding: overlayPadding,
            ellipsisFontSize: ellipsisFontSize,
            ellipsisInnerPadding: ellipsisInnerPadding
        )
    }

    private struct LayoutMetrics {
        let cornerRadius: CGFloat
        let imageHeight: CGFloat
        let contentPadding: CGFloat
        let contentSpacing: CGFloat
        let titleFontSize: CGFloat
        let metadataFontSize: CGFloat
        let summaryFontSize: CGFloat
        let sourceFontSize: CGFloat
        let titleLineLimit: Int
        let summaryLineLimit: Int
        let actionBarPadding: CGFloat
        let overlayPadding: CGFloat
        let ellipsisFontSize: CGFloat
        let ellipsisInnerPadding: CGFloat
    }
}

struct NewsDetailView: View {
    let card: NewsCard

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    if let imageURL = card.imageURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                placeholderHero
                            }
                        }
                    } else {
                        placeholderHero
                    }

                    Text(card.source)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(16)
                }
                .frame(height: 300)
                .clipped()

                VStack(alignment: .leading, spacing: 14) {
                    Text(card.title)
                        .font(.title2.weight(.bold))

                    Text(card.time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(card.summary)
                        .font(.body.weight(.semibold))
                        .padding(.top, 4)

                    Text(card.fullText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal,50)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholderHero: some View {
        Rectangle()
            .fill(card.imageGradient)
            .overlay {
                Image(systemName: card.thumbnailSymbol)
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
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
