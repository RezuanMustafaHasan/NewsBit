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

struct HomeView: View {
    @StateObject private var viewModel = NewsFeedViewModel()
    @State private var selectedNews: NewsCard?
    @State private var isShowingDetail = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let horizontalPadding = geometry.size.width * 0.02
                let verticalPadding = geometry.size.height * 0
                let availableCardHeight = max(0, geometry.size.height - (verticalPadding * 2))
                let stackSpacing: CGFloat = 8
                let visibleStackDepth = 2
                let stackLift = CGFloat(visibleStackDepth) * stackSpacing
                let cardHeight = max(0, availableCardHeight - stackLift)

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

                    VStack {
                        ZStack {
                            ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                                let depth = min(max(viewModel.cards.count - 1 - index, 0), visibleStackDepth)

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
                                .frame(maxWidth: .infinity)
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
                        .frame(width: max(0, geometry.size.width - (horizontalPadding * 2)))
                        .frame(height: cardHeight + stackLift)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                }
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
            let cornerRadius: CGFloat = 24
            let imageHeight = min(max(geometry.size.height * 0.48, 260), 340)

            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    newsImage
                        .frame(maxWidth: .infinity)
                        .frame(height: imageHeight)
                        .clipped()
                        .overlay(alignment: .bottomLeading) {
                            Text(card.source)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.95), in: Capsule())
                                .padding(14)
                                .position(x:90,y:320)
                        }

                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.black.opacity(0.95), in: Circle())
                        .padding(12)
                        .position(x:420, y:30)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(card.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(card.time)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text(card.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.white)
            }
            .frame(width: geometry.size.width, height: geometry.size.height*0.97)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 18)))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
