import SwiftUI

struct AuthenticationView: View {
    enum AuthMode: String, CaseIterable {
        case login = "Login"
        case register = "Register"
    }

    @ObservedObject var authViewModel: AuthViewModel

    @State private var mode: AuthMode = .login
    @State private var username = ""
    @State private var emailOrUsername = ""
    @State private var email = ""
    @State private var password = ""
    @State private var gender = "Male"

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.25), Color.cyan.opacity(0.2), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("NewsBit")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.85))

                        Text(mode == .login ? "Welcome back" : "Create your account")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 48)

                    Picker("Mode", selection: $mode) {
                        ForEach(AuthMode.allCases, id: \.rawValue) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    VStack(spacing: 14) {
                        if mode == .login {
                            AuthTextField(
                                title: "Email or Username",
                                systemImage: "person",
                                text: $emailOrUsername
                            )
                        } else {
                            AuthTextField(
                                title: "Username",
                                systemImage: "person.text.rectangle",
                                text: $username
                            )

                            AuthTextField(
                                title: "Email",
                                systemImage: "envelope",
                                text: $email,
                                keyboard: .emailAddress,
                                autocapitalization: .never
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Gender")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Picker("Gender", selection: $gender) {
                                    Text("Male").tag("Male")
                                    Text("Female").tag("Female")
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                        }

                        SecureFieldRow(title: "Password", text: $password)
                    }
                    .padding(.horizontal, 20)

                    if let authError = authViewModel.authError {
                        Text(authError)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                    }

                    Button {
                        Task {
                            if mode == .login {
                                await authViewModel.signIn(identifier: emailOrUsername, password: password)
                            } else {
                                await authViewModel.register(
                                    username: username,
                                    email: email,
                                    password: password,
                                    gender: gender
                                )
                            }
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.blue)
                                .frame(height: 54)

                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(mode == .login ? "Login" : "Create Account")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .disabled(authViewModel.isLoading)
                    .padding(.horizontal, 20)

                    Text(mode == .login ? "Login with username or email" : "Registration requires username, email, password and gender")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                }
            }
        }
    }
}

struct AuthTextField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            TextField(title, text: $text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(true)
                .keyboardType(keyboard)
        }
        .padding(14)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SecureFieldRow: View {
    let title: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock")
                .foregroundStyle(.secondary)
                .frame(width: 22)

            Group {
                if isVisible {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
    }
}
