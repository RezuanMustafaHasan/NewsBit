import SwiftUI

enum PremiumNavigationMetrics {
    static let barReservedHeight: CGFloat = 104
    static let contentSpacing: CGFloat = 14
    static let composerClearance: CGFloat = 10
}

struct PremiumBottomNavigationBar: View {
    @Binding var selectedTab: MainTabShellView.Tab

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    HomePalette.background.opacity(0),
                    HomePalette.background.opacity(0.78),
                    HomePalette.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 18)

            HStack(spacing: 8) {
                tabButton(title: "Home", icon: "house.fill", tab: .home)
                tabButton(title: "Favorites", icon: "heart.fill", tab: .favorites)
                tabButton(title: "Messages", icon: "paperplane.fill", tab: .messages)
                tabButton(title: "Search", icon: "magnifyingglass", tab: .search)
                tabButton(title: "Profile", icon: "person.crop.circle.fill", tab: .profile)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.86))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(HomePalette.softStroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
                    .shadow(color: HomePalette.accent.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .background(HomePalette.background.opacity(0.94))
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private func tabButton(title: String, icon: String, tab: MainTabShellView.Tab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : HomePalette.mutedText)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(isSelected ? HomePalette.accent : Color.clear)
                    )

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? HomePalette.accent : HomePalette.mutedText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? HomePalette.accentSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
