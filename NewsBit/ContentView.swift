import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabShellView(authViewModel: authViewModel)
            } else {
                AuthenticationView(authViewModel: authViewModel)
            }
        }
        .onAppear {
            authViewModel.restoreSession()
        }
    }
}

#Preview {
    ContentView()
}
