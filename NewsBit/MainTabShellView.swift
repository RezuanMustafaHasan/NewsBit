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
        ZStack(alignment: .bottom) {
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
            .padding(.bottom, PremiumNavigationMetrics.barReservedHeight)

            PremiumBottomNavigationBar(selectedTab: $selectedTab)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .background(HomePalette.background.ignoresSafeArea())
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedTab)
    }
}
