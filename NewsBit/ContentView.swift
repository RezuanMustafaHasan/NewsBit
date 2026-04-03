import SwiftUI

struct ContentView: View {
    enum Tab {
        case home
        case search
        case profile
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .search:
                    SearchView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavigationBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct BottomNavigationBar: View {
    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                navButton(title: "Home", icon: "house.fill", tab: .home)
                navButton(title: "Search", icon: "magnifyingglass", tab: .search)
                navButton(title: "Profile", icon: "person.crop.circle", tab: .profile)
            }
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func navButton(title: String, icon: String, tab: ContentView.Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(selectedTab == tab ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeView: View {
    @State private var cards: [NewsCard] = NewsCard.mockCards
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
                        ZStack {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                SwipeableNewsCardView(
                                    card: card,
                                    isTopCard: index == cards.count - 1,
                                    onTap: {
                                        if index == cards.count - 1 {
                                            selectedNews = card
                                            isShowingDetail = true
                                        }
                                    },
                                    onSwipe: {
                                        if index == cards.count - 1 {
                                            cards.removeLast()
                                        }
                                    }
                                )
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                )
                                .offset(y: CGFloat(cards.count - 1 - index) * 6)
                                .scaleEffect(1 - CGFloat(cards.count - 1 - index) * 0.03)
                                .zIndex(Double(index))
                            }

                            if cards.isEmpty {
                                VStack(spacing: 10) {
                                    Text("No more stories")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Button("Reload") {
                                        cards = NewsCard.mockCards
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $isShowingDetail) {
                if let selectedNews {
                    NewsDetailView(card: selectedNews)
                }
            }
        }
    }
}

private struct SwipeableNewsCardView: View {
    let card: NewsCard
    let isTopCard: Bool
    let onTap: () -> Void
    let onSwipe: () -> Void

    @State private var offset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Rectangle()
                        .fill(card.imageGradient)
                        .overlay(alignment: .bottomLeading) {
                            Text(card.source)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(14)
                        }
                        .overlay(alignment: .center) {
                            Image(systemName: card.thumbnailSymbol)
                                .font(.system(size: 78, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
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

private struct NewsDetailView: View {
    let card: NewsCard

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 0)
                        .fill(card.imageGradient)
                        .frame(height: 300)
                        .overlay {
                            Image(systemName: card.thumbnailSymbol)
                                .font(.system(size: 96, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                        }

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

private struct SearchView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("This is the search page")
                    .font(.title2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search")
        }
    }
}

private struct ProfileView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("This is the profile page")
                    .font(.title2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
        }
    }
}

private struct NewsCard: Identifiable {
    let id = UUID()
    let source: String
    let title: String
    let time: String
    let summary: String
    let fullText: String
    let commentCount: Int
    let thumbnailSymbol: String
    let imageGradient: LinearGradient
}

private extension NewsCard {
    static let mockCards: [NewsCard] = [
        NewsCard(
            source: "Global Desk",
            title: "Markets rebound as investors react to new policy signals",
            time: "24 minutes ago",
            summary: "Stocks rose sharply in late trading as analysts pointed to stronger-than-expected guidance and easing concerns around inflation pressures.",
            fullText: "Markets closed higher after a volatile morning, with major indexes recovering losses by the final hour. Analysts said comments from policymakers helped reduce fears of another aggressive rate move. Traders also reacted positively to updated corporate forecasts, particularly from manufacturing and logistics firms. Despite the rally, experts cautioned that upcoming inflation data and labor reports could still reshape expectations in the weeks ahead.",
            commentCount: 126,
            thumbnailSymbol: "chart.line.uptrend.xyaxis",
            imageGradient: LinearGradient(
                colors: [.orange, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        NewsCard(
            source: "City Wire",
            title: "Metro expansion plan clears first stage with broad support",
            time: "1 hour ago",
            summary: "The transit board approved the initial route proposal, moving a major infrastructure project one step closer to construction.",
            fullText: "The city transit board voted to move the expansion plan into detailed engineering after months of public review. Officials said the project would improve commute times for densely populated neighborhoods and create new transfer points across existing lines. Community groups welcomed improved access but requested stronger guarantees on accessibility features and noise mitigation. Funding decisions are expected in the next budget session.",
            commentCount: 89,
            thumbnailSymbol: "tram.fill",
            imageGradient: LinearGradient(
                colors: [.blue, .mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        NewsCard(
            source: "Tech Brief",
            title: "New AI assistant tools target faster app development",
            time: "2 hours ago",
            summary: "Developers are getting a new wave of productivity features focused on reducing repetitive coding tasks and improving code quality.",
            fullText: "Several tool vendors announced AI-powered features aimed at helping teams move from prototype to production more quickly. The updates focus on structured code generation, improved in-editor context, and safer refactoring workflows. Engineering leads say these tools can reduce repetitive work, but emphasize that architecture and review standards still matter most. Early adopters report faster iteration cycles when assistants are paired with clear coding conventions.",
            commentCount: 214,
            thumbnailSymbol: "cpu",
            imageGradient: LinearGradient(
                colors: [.purple, .indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        NewsCard(
            source: "World Report",
            title: "Humanitarian corridors open as talks continue overnight",
            time: "3 hours ago",
            summary: "Aid agencies began transporting food and medical supplies through designated routes while negotiators continued discussions.",
            fullText: "International aid organizations confirmed that designated corridors opened at first light, allowing medical convoys and food shipments to reach affected districts. Negotiators from multiple parties continued overnight meetings focused on extending access windows and reducing risks to civilians. Relief officials said the immediate priority remains critical care and clean water distribution. Independent observers are expected to issue an updated situation report later today.",
            commentCount: 302,
            thumbnailSymbol: "globe.europe.africa.fill",
            imageGradient: LinearGradient(
                colors: [.teal, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    ]
}

#Preview {
    ContentView()
}
