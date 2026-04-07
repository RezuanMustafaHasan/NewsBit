import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var authViewModel: AuthViewModel

    init() {
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
    }

    init(authViewModel: AuthViewModel) {
        _authViewModel = StateObject(wrappedValue: authViewModel)
    }

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
    ContentView(authViewModel: .previewMock())
}
