import SwiftUI

enum HomePalette {
    static let background = Color(red: 0.96, green: 0.97, blue: 0.95)
    static let surface = Color.white
    static let accent = Color(red: 0.11, green: 0.36, blue: 0.24)
    static let accentSoft = accent.opacity(0.12)
    static let softFill = Color.black.opacity(0.035)
    static let softStroke = Color.black.opacity(0.06)
    static let primaryText = Color(red: 0.12, green: 0.15, blue: 0.13)
    static let mutedText = Color(red: 0.43, green: 0.47, blue: 0.44)
    static let shadow = Color.black.opacity(0.08)
}

struct HomeScreenLayout {
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let sectionSpacing: CGFloat
    let categoryHeight: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let deckHeight: CGFloat
    let previewOffset: CGFloat

    init(size: CGSize, safeAreaInsets: EdgeInsets) {
        let isLandscape = size.width > size.height

        horizontalPadding = max(min(size.width * (isLandscape ? 0.028 : 0.032), 14), 10)
        topPadding = safeAreaInsets.top + 4
        bottomPadding = max(safeAreaInsets.bottom, PremiumNavigationMetrics.contentSpacing)
        sectionSpacing = isLandscape ? 8 : 10
        categoryHeight = isLandscape ? 42 : 44
        previewOffset = 0

        let availableWidth = max(0, size.width - (horizontalPadding * 2))
        let availableHeight = max(
            0,
            size.height - topPadding - bottomPadding - categoryHeight - sectionSpacing
        )

        cardWidth = availableWidth
        cardHeight = availableHeight
        deckHeight = availableHeight
    }
}

struct PremiumHomeBackground: View {
    var body: some View {
        ZStack {
            HomePalette.background
                .ignoresSafeArea()

            Circle()
                .fill(HomePalette.accent.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: 145, y: -240)

            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: -150, y: 250)
        }
    }
}

struct HomeTopHeaderView: View {
    let title: String
    let subtitle: String
    let onSearchTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(HomePalette.accent)

                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(HomePalette.primaryText)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HomePalette.mutedText)
                }
            }

            Spacer(minLength: 0)

            Button(action: onSearchTap) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(HomePalette.accent)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.92))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 68)
        .homeGlassCard(cornerRadius: 24)
    }
}

struct HomeCategoryChipsView: View {
    let categories: [NewsCategoryFilter]
    let selectedCategory: NewsCategoryFilter
    let isLoading: Bool
    let onSelect: (NewsCategoryFilter) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories) { category in
                        Button {
                            withAnimation(.easeInOut(duration: 0.24)) {
                                proxy.scrollTo(category.id, anchor: .center)
                            }
                            onSelect(category)
                        } label: {
                            HomeCategoryChip(
                                label: category.label,
                                isSelected: selectedCategory == category
                            )
                        }
                        .buttonStyle(.plain)
                        .id(category.id)
                    }
                }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.hidden)
            .frame(height: 42)
            .homeGlassCard(cornerRadius: 18)
            .overlay(alignment: .trailing) {
                if isLoading {
                    ProgressView()
                        .tint(HomePalette.accent)
                        .scaleEffect(0.75)
                        .padding(.trailing, 14)
                }
            }
            .onChange(of: selectedCategory.id, initial: true) { _, selectedID in
                withAnimation(.easeInOut(duration: 0.24)) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
    }
}

struct HomeCategoryChip: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(isSelected ? Color.white : HomePalette.mutedText)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? HomePalette.accent : HomePalette.softFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? HomePalette.accent.opacity(0.18) : HomePalette.softStroke, lineWidth: 1)
            )
    }
}

struct NewsSwipeDeckView: View {
    let cards: [NewsCard]
    let categoryLabel: String
    let cardSize: CGSize
    let deckHeight: CGFloat
    let isLoading: Bool
    let loadError: String?
    let emptyTitle: String
    let canAdvance: Bool
    let canRewind: Bool
    let favoriteIDs: Set<String>
    let highlightedIDs: Set<String>
    let onReload: () -> Void
    let onOpen: (NewsCard) -> Void
    let onSwipeForward: (NewsCard) -> Void
    let onSwipeBackward: (NewsCard) -> Void
    let onFavorite: (NewsCard) -> Void
    let onComment: (NewsCard) -> Void
    let onHighlight: (NewsCard) -> Void
    let onShare: (NewsCard) -> Void

    @State private var activeDragOffset: CGSize = .zero

    var body: some View {
        let dragProgress = min(abs(activeDragOffset.width) / 180, 1)

        ZStack(alignment: .top) {
            if cards.isEmpty {
                EmptyNewsDeckView(
                    title: emptyTitle,
                    loadError: loadError,
                    isLoading: isLoading,
                    onReload: onReload
                )
                .frame(width: cardSize.width, height: max(cardSize.height * 0.78, 320))
            } else {
                // The front card owns the drag gesture while the preview card subtly reacts underneath it.
                ForEach(Array(cards.enumerated().reversed()), id: \.element.id) { entry in
                    let relativeIndex = entry.offset
                    let card = entry.element
                    let isTopCard = relativeIndex == 0

                    PremiumSwipeNewsCardView(
                        card: card,
                        categoryLabel: categoryLabel,
                        isTopCard: isTopCard,
                        canSwipeForward: isTopCard && canAdvance,
                        canSwipeBackward: isTopCard && canRewind,
                        isFavorite: favoriteIDs.contains(card.id),
                        isHighlighted: highlightedIDs.contains(card.id),
                        onTap: {
                            if isTopCard {
                                onOpen(card)
                            }
                        },
                        onSwipeForward: {
                            onSwipeForward(card)
                        },
                        onSwipeBackward: {
                            onSwipeBackward(card)
                        },
                        onFavoriteTap: {
                            onFavorite(card)
                        },
                        onCommentTap: {
                            onComment(card)
                        },
                        onHighlightTap: {
                            onHighlight(card)
                        },
                        onShareTap: {
                            onShare(card)
                        },
                        onShareSwipe: {
                            onShare(card)
                        },
                        onDragChanged: { newOffset in
                            guard isTopCard else { return }
                            activeDragOffset = newOffset
                        }
                    )
                    .frame(width: cardSize.width, height: cardSize.height)
                    .scaleEffect(relativeIndex == 0 ? 1 : (0.972 + (dragProgress * 0.01)), anchor: .top)
                    .offset(y: relativeIndex == 0 ? 0 : (18 - (dragProgress * 6)))
                    .opacity(relativeIndex == 0 ? 1 : 0.94)
                    .saturation(relativeIndex == 0 ? 1 : 0.92)
                    .zIndex(Double(cards.count - relativeIndex))
                }
            }
        }
        .frame(width: cardSize.width, height: deckHeight, alignment: .top)
    }
}

struct PremiumSwipeNewsCardView: View {
    let card: NewsCard
    let categoryLabel: String
    let isTopCard: Bool
    let canSwipeForward: Bool
    let canSwipeBackward: Bool
    let isFavorite: Bool
    let isHighlighted: Bool
    let onTap: () -> Void
    let onSwipeForward: () -> Void
    let onSwipeBackward: () -> Void
    let onFavoriteTap: () -> Void
    let onCommentTap: () -> Void
    let onHighlightTap: () -> Void
    let onShareTap: () -> Void
    let onShareSwipe: () -> Void
    let onDragChanged: (CGSize) -> Void

    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let layout = PremiumNewsCardLayout(size: geometry.size)
            let leftFeedbackOpacity = max(0, min((-offset.width - 18) / 92, 1))
            let rightFeedbackOpacity = max(0, min((offset.width - 18) / 92, 1))

            ZStack {
                RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                    .fill(HomePalette.surface)

                VStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        newsImage
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()

                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.04),
                                Color.clear,
                                Color.black.opacity(0.26)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                imageBadge(
                                    title: categoryLabel,
                                    systemImage: "square.grid.2x2.fill",
                                    emphasized: true
                                )

                                imageBadge(
                                    title: card.time,
                                    systemImage: "clock.fill"
                                )
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 34, height: 34)
                                .background(Color.black.opacity(0.28), in: Circle())
                        }
                        .padding(layout.overlayPadding)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: layout.imageHeight)
                    .clipped()

                    VStack(alignment: .leading, spacing: layout.contentSpacing) {
                        ViewThatFits(in: .vertical) {
                            cardTextBlock(
                                layout: layout,
                                titleLineLimit: layout.titleLineLimit,
                                summaryLineLimit: layout.summaryLineLimit
                            )

                            cardTextBlock(
                                layout: layout,
                                titleLineLimit: max(layout.titleLineLimit - 1, 2),
                                summaryLineLimit: layout.summaryLineLimit
                            )

                            cardTextBlock(
                                layout: layout,
                                titleLineLimit: max(layout.titleLineLimit - 1, 2),
                                summaryLineLimit: max(layout.summaryLineLimit - 1, 2)
                            )
                        }

                        Spacer(minLength: layout.bottomSpacer)

                        NewsFloatingActionBar(
                            isFavorite: isFavorite,
                            isHighlighted: isHighlighted,
                            onFavoriteTap: onFavoriteTap,
                            onCommentTap: onCommentTap,
                            onHighlightTap: onHighlightTap,
                            onShareTap: onShareTap
                        )
                    }
                    .padding(layout.contentPadding)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .frame(height: layout.contentHeight, alignment: .top)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                    .stroke(HomePalette.softStroke, lineWidth: 1)
            )
            .shadow(color: HomePalette.shadow, radius: 24, x: 0, y: 16)
            .shadow(color: HomePalette.accent.opacity(0.05), radius: 8, x: 0, y: 4)
            .overlay(alignment: .topLeading) {
                SwipeFeedbackBadge(
                    title: "Next",
                    systemImage: "arrow.left",
                    tint: HomePalette.primaryText.opacity(0.92)
                )
                .opacity(leftFeedbackOpacity)
                .padding(layout.feedbackPadding)
            }
            .overlay(alignment: .topTrailing) {
                SwipeFeedbackBadge(
                    title: "Back",
                    systemImage: "arrow.uturn.backward",
                    tint: HomePalette.accent
                )
                .opacity(rightFeedbackOpacity)
                .padding(layout.feedbackPadding)
            }
            .offset(x: offset.width, y: offset.height * 0.2)
            .rotationEffect(.degrees(Double(offset.width / 24)))
            .scaleEffect(1 - min(abs(offset.width) / 1800, 0.03))
            .contentShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
            .onTapGesture {
                if isTopCard {
                    onTap()
                }
            }
            .gesture(isTopCard ? dragGesture(for: geometry.size) : nil)
            .allowsHitTesting(isTopCard)
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.84), value: offset)
        }
    }

    @ViewBuilder
    private func cardTextBlock(
        layout: PremiumNewsCardLayout,
        titleLineLimit: Int,
        summaryLineLimit: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: layout.textSpacing) {
            Text(card.title)
                .font(.system(size: layout.titleFontSize, weight: .bold))
                .foregroundStyle(HomePalette.primaryText)
                .lineLimit(titleLineLimit)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            if !articlePreviewText.isEmpty {
                Text(articlePreviewText)
                    .font(.system(size: layout.summaryFontSize, weight: .regular))
                    .foregroundStyle(HomePalette.mutedText)
                    .lineLimit(summaryLineLimit)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    @ViewBuilder
    private var newsImage: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(card.imageGradient)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                if let imageURL = card.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        case .failure(_), .empty:
                            placeholderSymbol
                        @unknown default:
                            placeholderSymbol
                        }
                    }
                } else {
                    placeholderSymbol
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private var placeholderSymbol: some View {
        Image(systemName: card.thumbnailSymbol)
            .font(.system(size: 74, weight: .bold))
            .foregroundStyle(.white.opacity(0.84))
    }

    private func dragGesture(for size: CGSize) -> some Gesture {
        let horizontalThreshold = min(max(size.width * 0.22, 96), 132)
        let shareThreshold = min(max(size.height * 0.12, 88), 116)

        return DragGesture()
            .onChanged { value in
                offset = value.translation
                onDragChanged(offset)
            }
            .onEnded { value in
                let width = value.translation.width
                let height = value.translation.height
                let isShareSwipe = height < -shareThreshold && abs(height) > abs(width) * 1.12
                let isHorizontalSwipe = abs(width) > horizontalThreshold && abs(width) > abs(height)

                if isShareSwipe {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        offset = CGSize(width: 0, height: -52)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        onShareSwipe()
                        offset = .zero
                        onDragChanged(.zero)
                    }
                    return
                }

                // Keep the existing article navigation behavior: left moves forward, right goes back.
                if isHorizontalSwipe, width < 0, canSwipeForward {
                    withAnimation(.easeIn(duration: 0.2)) {
                        offset = CGSize(width: -size.width * 1.2, height: min(height * 0.25, 60))
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        onSwipeForward()
                        offset = .zero
                        onDragChanged(.zero)
                    }
                    return
                }

                if isHorizontalSwipe, width > 0, canSwipeBackward {
                    withAnimation(.easeIn(duration: 0.2)) {
                        offset = CGSize(width: size.width * 1.2, height: min(height * 0.25, 60))
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        onSwipeBackward()
                        offset = .zero
                        onDragChanged(.zero)
                    }
                    return
                }

                offset = .zero
                onDragChanged(.zero)
            }
    }

    private var articlePreviewText: String {
        let summary = card.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullText = card.fullText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !summary.isEmpty else { return fullText }
        guard !fullText.isEmpty, fullText != summary else { return summary }

        return fullText.count > summary.count ? fullText : summary
    }

    private func imageBadge(title: String, systemImage: String, emphasized: Bool = false) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(emphasized ? HomePalette.accent.opacity(0.94) : Color.black.opacity(0.56))
            )
    }
}

struct NewsFloatingActionBar: View {
    let isFavorite: Bool
    let isHighlighted: Bool
    let onFavoriteTap: () -> Void
    let onCommentTap: () -> Void
    let onHighlightTap: () -> Void
    let onShareTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            floatingButton(
                icon: isFavorite ? "heart.fill" : "heart",
                tint: isFavorite ? Color.red : HomePalette.primaryText,
                action: onFavoriteTap
            )

            Spacer(minLength: 0)

            floatingButton(
                icon: "bubble.right",
                tint: HomePalette.primaryText,
                action: onCommentTap
            )

            Spacer(minLength: 0)

            floatingButton(
                icon: "highlighter",
                tint: isHighlighted ? Color.orange : HomePalette.primaryText,
                action: onHighlightTap
            )

            Spacer(minLength: 0)

            floatingButton(
                icon: "paperplane.fill",
                tint: HomePalette.accent,
                action: onShareTap
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.84))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(HomePalette.softStroke, lineWidth: 1)
                )
                .shadow(color: HomePalette.shadow, radius: 12, x: 0, y: 8)
        )
    }

    @ViewBuilder
    private func floatingButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.92))
                )
                .overlay(
                    Circle()
                        .stroke(HomePalette.softStroke, lineWidth: 1)
                )
        }
        .buttonStyle(PressableIconButtonStyle())
    }
}

struct HomeSwipeHintView: View {
    let canRewind: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left")
            Text(canRewind ? "Swipe left for next story, right to go back" : "Swipe left for next story")
            if canRewind {
                Image(systemName: "arrow.right")
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(HomePalette.mutedText)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(HomePalette.softStroke, lineWidth: 1)
        )
    }
}

struct EmptyNewsDeckView: View {
    let title: String
    let loadError: String?
    let isLoading: Bool
    let onReload: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(HomePalette.accentSoft)
                    .frame(width: 68, height: 68)

                Image(systemName: "newspaper.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(HomePalette.accent)
            }

            if isLoading {
                ProgressView("Loading stories...")
                    .tint(HomePalette.accent)
                    .foregroundStyle(HomePalette.mutedText)
            } else {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HomePalette.primaryText)

                if let loadError {
                    Text(loadError)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(HomePalette.mutedText)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Pull in a fresh batch of stories to continue swiping.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(HomePalette.mutedText)
                        .multilineTextAlignment(.center)
                }

                Button("Reload feed", action: onReload)
                    .buttonStyle(.borderedProminent)
                    .tint(HomePalette.accent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .homeGlassCard(cornerRadius: 30)
    }
}

struct NewsMetaTag: View {
    let systemImage: String
    let title: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(HomePalette.mutedText)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(HomePalette.softFill)
            )
    }
}

struct SwipeFeedbackBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.9))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
    }
}

struct PremiumNewsCardLayout {
    let cornerRadius: CGFloat
    let imageHeight: CGFloat
    let contentHeight: CGFloat
    let overlayPadding: CGFloat
    let contentPadding: CGFloat
    let contentSpacing: CGFloat
    let textSpacing: CGFloat
    let titleFontSize: CGFloat
    let summaryFontSize: CGFloat
    let titleLineLimit: Int
    let summaryLineLimit: Int
    let bottomSpacer: CGFloat
    let feedbackPadding: CGFloat

    init(size: CGSize) {
        let isCompactHeight = size.height < 610
        let isCompactWidth = size.width < 360
        let isTallCard = size.height > 720

        cornerRadius = isCompactWidth ? 26 : 30
        imageHeight = floor(size.height / 3)
        contentHeight = max(size.height - imageHeight, 0)
        overlayPadding = isCompactWidth ? 14 : 18
        contentPadding = isCompactWidth ? 16 : 18
        contentSpacing = isCompactHeight ? 8 : 10
        textSpacing = isCompactHeight ? 6 : 8
        titleFontSize = min(max(size.width * 0.068, isCompactWidth ? 22 : 24), isTallCard ? 30 : 28)
        summaryFontSize = isCompactHeight ? 14 : 15
        titleLineLimit = isCompactHeight ? 4 : 5
        summaryLineLimit = isCompactHeight ? 7 : 10
        bottomSpacer = isCompactHeight ? 4 : 8
        feedbackPadding = isCompactWidth ? 14 : 18
    }
}

struct PressableIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

extension View {
    func homeGlassCard(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(HomePalette.softStroke, lineWidth: 1)
                )
                .shadow(color: HomePalette.shadow, radius: 18, x: 0, y: 10)
        )
    }
}
