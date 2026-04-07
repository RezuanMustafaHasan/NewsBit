import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = NewsFeedViewModel()
    @State private var selectedNews: NewsCard?
    @State private var isShowingDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.6), Color.black.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                GeometryReader { geometry in
                    let cardWidth = geometry.size.width

                    ZStack {
                        ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                            SwipeableNewsCardView(
                                card: card,
                                isTopCard: index == viewModel.cards.count - 1,
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
                                }
                            )
                            .frame(width: cardWidth, height: geometry.size.height)
                            .offset(y: CGFloat(viewModel.cards.count - 1 - index) * 6)
                            .scaleEffect(1 - CGFloat(viewModel.cards.count - 1 - index) * 0.03)
                            .zIndex(Double(index))
                            .clipped()
                        }

                        if viewModel.cards.isEmpty {
                            VStack(spacing: 12) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("No more stories")
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
                    .frame(width: cardWidth, height: geometry.size.height)
                    .clipped()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $isShowingDetail) {
                if let selectedNews {
                    NewsDetailView(card: selectedNews)
                }
            }
            .task {
                await viewModel.loadInitialIfNeeded()
            }
        }
    }
}

struct SwipeableNewsCardView: View {
    let card: NewsCard
    let isTopCard: Bool
    let onTap: () -> Void
    let onSwipe: () -> Void

    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let imageURL = card.imageURL {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Rectangle()
                                        .fill(card.imageGradient)
                                        .overlay(alignment: .center) {
                                            Image(systemName: card.thumbnailSymbol)
                                                .font(.system(size: 78, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(card.imageGradient)
                                .overlay(alignment: .center) {
                                    Image(systemName: card.thumbnailSymbol)
                                        .font(.system(size: 78, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                        }
                    }
                    .clipped()
                        .overlay(alignment: .bottomLeading) {
                            Text(card.source)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(14)
                        }

                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(12)
                }
                .frame(height: geometry.size.height * 0.5)

                VStack(alignment: .leading, spacing: 10) {
                    Text(card.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(card.time)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(card.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .frame(height: geometry.size.height * 0.5)
                .background(Color.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 18)))
            .contentShape(Rectangle())
            .onTapGesture {
                if isTopCard {
                    onTap()
                }
            }
            .gesture(isTopCard ? dragGesture : nil)
            .allowsHitTesting(isTopCard)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: offset)
        }
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
}

struct NewsDetailView: View {
    let card: NewsCard

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let imageURL = card.imageURL {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Rectangle()
                                        .fill(card.imageGradient)
                                        .overlay {
                                            Image(systemName: card.thumbnailSymbol)
                                                .font(.system(size: 96, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(card.imageGradient)
                                .overlay {
                                    Image(systemName: card.thumbnailSymbol)
                                        .font(.system(size: 96, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                        }
                    }
                    .frame(height: 300)
                    .clipped()

                    Text(card.source)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(16)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(card.title)
                        .font(.title2.weight(.bold))

                    Text(card.time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Label(card.source, systemImage: "newspaper")
                        Label("\(card.commentCount)", systemImage: "bubble.left")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                    Text(card.summary)
                        .font(.body.weight(.semibold))
                        .padding(.top, 4)

                    Text(card.fullText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("News")
        .navigationBarTitleDisplayMode(.inline)
    }
}
