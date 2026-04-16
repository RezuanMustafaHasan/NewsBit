import SwiftUI
import FirebaseAuth

struct MainTabShellView: View {
    enum Tab {
        case home
        case favorites
        case messages
        case search
        case profile
    }

    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedTab: Tab = .home

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(userID: authViewModel.currentUser?.uid)
                case .favorites:
                    FavoritesView(userID: authViewModel.currentUser?.uid)
                case .messages:
                    MessagesView(currentUserID: authViewModel.currentUser?.uid)
                case .search:
                    SearchView()
                case .profile:
                    ProfileView(authViewModel: authViewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNavigationBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct BottomNavigationBar: View {
    @Binding var selectedTab: MainTabShellView.Tab

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                navButton(title: "Home", icon: "house.fill", tab: .home)
                navButton(title: "Favorites", icon: "heart.fill", tab: .favorites)
                navButton(title: "Messages", icon: "paperplane.fill", tab: .messages)
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
    private func navButton(title: String, icon: String, tab: MainTabShellView.Tab) -> some View {
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
