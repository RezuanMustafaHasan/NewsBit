import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var authError: String?

    private let db: Firestore?
    private let usesFirebase: Bool
    private let errorDomain = "NewsBitAuth"

    static func previewMock() -> AuthViewModel {
        let viewModel = AuthViewModel(usesFirebase: true)
        viewModel.currentUser = nil
        viewModel.profile = nil
        viewModel.authError = nil
        return viewModel
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    private var firestore: Firestore {
        guard let db else {
            fatalError("Firestore used while Firebase is disabled")
        }
        return db
    }

    init(usesFirebase: Bool = true) {
        self.usesFirebase = usesFirebase
        self.db = usesFirebase ? Firestore.firestore() : nil
        currentUser = usesFirebase ? Auth.auth().currentUser : nil
    }

    func restoreSession() {
        guard usesFirebase else { return }

        currentUser = Auth.auth().currentUser

        guard currentUser != nil else {
            profile = nil
            return
        }

        Task {
            await fetchProfile()
        }
    }

    func signIn(identifier: String, password: String) async {
        guard usesFirebase else { return }

        authError = nil

        let cleanedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedIdentifier.isEmpty, !cleanedPassword.isEmpty else {
            authError = "Enter username/email and password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let loginEmail: String
            if cleanedIdentifier.contains("@") {
                loginEmail = cleanedIdentifier.lowercased()
            } else {
                loginEmail = try await resolveEmail(forUsername: cleanedIdentifier.lowercased())
            }

            let result = try await signInWithEmail(loginEmail, password: cleanedPassword)
            currentUser = result.user
            await fetchProfile()
        } catch {
            let nsError = error as NSError
            print("[Auth][SignIn] \(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription) userInfo=\(nsError.userInfo)")
            authError = mapError(error)
        }
    }

    func register(username: String, email: String, password: String, gender: String) async {
        guard usesFirebase else { return }

        authError = nil

        let cleanedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let usernameKey = cleanedUsername.lowercased()

        guard !cleanedUsername.isEmpty, !cleanedEmail.isEmpty, !cleanedPassword.isEmpty else {
            authError = "Fill all registration fields."
            return
        }

        guard cleanedPassword.count >= 6 else {
            authError = "Password must be at least 6 characters."
            return
        }

        guard ["Male", "Female"].contains(gender) else {
            authError = "Please select a gender."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let authResult = try await createUserWithEmail(cleanedEmail, password: cleanedPassword)

            do {
                try await reserveUniqueUsername(
                    usernameKey: usernameKey,
                    username: cleanedUsername,
                    uid: authResult.user.uid,
                    email: cleanedEmail
                )
            } catch {
                try? await deleteUser(authResult.user)
                throw error
            }

            try await updateDisplayName(for: authResult.user, displayName: cleanedUsername)
            try await saveUserProfile(
                uid: authResult.user.uid,
                username: cleanedUsername,
                email: cleanedEmail,
                gender: gender,
                avatarColorHex: defaultAvatarColorHex(for: gender),
                avatarImageBase64: nil,
                coverImageBase64: nil
            )

            currentUser = authResult.user
            await fetchProfile()
        } catch {
            let nsError = error as NSError
            print("[Auth][Register] \(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription) userInfo=\(nsError.userInfo)")
            authError = mapError(error)
        }
    }

    func signOut() {
        guard usesFirebase else {
            currentUser = nil
            profile = nil
            authError = nil
            return
        }

        do {
            try Auth.auth().signOut()
            currentUser = nil
            profile = nil
            authError = nil
        } catch {
            authError = "Unable to sign out right now."
        }
    }

    func fetchProfile() async {
        guard usesFirebase else { return }

        guard let uid = currentUser?.uid else {
            profile = nil
            return
        }

        do {
            let snapshot = try await getDocument(collection: "users", documentID: uid)
            guard let data = snapshot.data() else {
                return
            }

            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            let gender = data["gender"] as? String ?? "Male"
            profile = UserProfile(
                uid: uid,
                username: data["username"] as? String ?? currentUser?.displayName ?? "Unknown",
                email: data["email"] as? String ?? currentUser?.email ?? "",
                gender: gender,
                createdAt: createdAt,
                avatarColorHex: data["avatarColorHex"] as? String ?? defaultAvatarColorHex(for: gender),
                avatarImageBase64: data["avatarImageBase64"] as? String,
                coverImageBase64: data["coverImageBase64"] as? String
            )
        } catch {
            let nsError = error as NSError
            print("[Profile][Fetch] \(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)")
        }
    }

    func updateAvatarColor(hex: String) async {
        guard usesFirebase else { return }
        guard let uid = currentUser?.uid else { return }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                firestore.collection("users").document(uid).setData([
                    "avatarColorHex": hex,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            await fetchProfile()
        } catch {
            authError = mapError(error)
        }
    }

    func updateProfilePhoto(with imageData: Data) async {
        guard usesFirebase else { return }
        guard let uid = currentUser?.uid else { return }

        authError = nil

        guard let preparedData = AvatarImageCodec.preparedJPEGData(from: imageData) else {
            authError = "Unable to process the selected photo."
            return
        }

        let base64 = preparedData.base64EncodedString()

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                firestore.collection("users").document(uid).setData([
                    "avatarImageBase64": base64,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            await fetchProfile()
        } catch {
            authError = mapError(error)
        }
    }

    func updateCoverPhoto(with imageData: Data) async {
        guard usesFirebase else { return }
        guard let uid = currentUser?.uid else { return }

        authError = nil

        guard let preparedData = AvatarImageCodec.preparedJPEGData(
            from: imageData,
            maxPixelSize: 1400,
            compressionQuality: 0.76
        ) else {
            authError = "Unable to process the selected cover photo."
            return
        }

        let base64 = preparedData.base64EncodedString()

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                firestore.collection("users").document(uid).setData([
                    "coverImageBase64": base64,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }

            await fetchProfile()
        } catch {
            authError = mapError(error)
        }
    }

    private func resolveEmail(forUsername usernameKey: String) async throws -> String {
        let snapshot = try await getDocument(collection: "usernames", documentID: usernameKey)

        guard snapshot.exists,
              let email = snapshot.data()?["email"] as? String,
              !email.isEmpty
        else {
            throw AuthFlowError.usernameNotFound
        }

        return email
    }

    private func reserveUniqueUsername(usernameKey: String, username: String, uid: String, email: String) async throws {
        let takenError = NSError(
            domain: errorDomain,
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "Username already taken."]
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            firestore.runTransaction { transaction, errorPointer in
                let usernameRef = self.firestore.collection("usernames").document(usernameKey)

                do {
                    let snapshot = try transaction.getDocument(usernameRef)
                    if snapshot.exists {
                        errorPointer?.pointee = takenError
                        return nil
                    }

                    transaction.setData([
                        "uid": uid,
                        "username": username,
                        "email": email,
                        "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: usernameRef)

                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            } completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func saveUserProfile(
        uid: String,
        username: String,
        email: String,
        gender: String,
        avatarColorHex: String,
        avatarImageBase64: String?,
        coverImageBase64: String?
    ) async throws {
        var data: [String: Any] = [
            "uid": uid,
            "username": username,
            "email": email,
            "gender": gender,
            "avatarColorHex": avatarColorHex,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let avatarImageBase64, !avatarImageBase64.isEmpty {
            data["avatarImageBase64"] = avatarImageBase64
        }

        if let coverImageBase64, !coverImageBase64.isEmpty {
            data["coverImageBase64"] = coverImageBase64
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            firestore.collection("users").document(uid).setData(data) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func getDocument(collection: String, documentID: String) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
            firestore.collection(collection).document(documentID).getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: AuthFlowError.unknown)
                }
            }
        }
    }

    private func signInWithEmail(_ email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthFlowError.unknown)
                }
            }
        }
    }

    private func createUserWithEmail(_ email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthFlowError.unknown)
                }
            }
        }
    }

    private func deleteUser(_ user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func updateDisplayName(for user: User, displayName: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            changeRequest.commitChanges { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func defaultAvatarColorHex(for gender: String) -> String {
        gender.lowercased() == "female" ? "#E84393" : "#0984E3"
    }

    private func authErrorDebugDetails(_ nsError: NSError) -> String {
        var details: [String] = []

        if let name = nsError.userInfo["FIRAuthErrorUserInfoNameKey"] as? String {
            details.append("name=\(name)")
        }

        if let response = nsError.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] {
            details.append("response=\(response)")
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            details.append("underlying=\(underlying.domain)(\(underlying.code)): \(underlying.localizedDescription)")
        }

        return details.isEmpty ? nsError.localizedDescription : details.joined(separator: " | ")
    }

    private func mapInternalAuthError(_ nsError: NSError) -> String {
        let details = authErrorDebugDetails(nsError)
        let normalizedDetails = details.uppercased()

        if normalizedDetails.contains("CONFIGURATION_NOT_FOUND") {
            return "Firebase app config mismatch. Download a fresh GoogleService-Info.plist for this exact bundle ID and replace it in the app target."
        }

        if normalizedDetails.contains("API_KEY") || normalizedDetails.contains("INVALID_KEY") {
            return "Firebase API key/config is invalid for this app. Verify GoogleService-Info.plist belongs to this Firebase project."
        }

        if normalizedDetails.contains("BUNDLE") || normalizedDetails.contains("APP") {
            return "Bundle ID mismatch detected. Ensure Xcode bundle identifier exactly matches the iOS app in Firebase project settings."
        }

        return "Firebase internal auth error: \(details)"
    }

    private func mapError(_ error: Error) -> String {
        if let flowError = error as? AuthFlowError {
            return flowError.localizedDescription
        }

        let nsError = error as NSError
        if nsError.domain == errorDomain, nsError.code == 1001 {
            return "Username is already taken."
        }

        if nsError.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidEmail:
                return "Invalid email format."
            case .emailAlreadyInUse:
                return "This email is already registered."
            case .wrongPassword, .invalidCredential:
                return "Invalid credentials."
            case .userNotFound:
                return "User not found."
            case .networkError:
                return "Network issue. Please try again."
            case .operationNotAllowed:
                return "Email/password sign-in is not enabled in Firebase Auth."
            case .weakPassword:
                return "Password is too weak. Use at least 6 characters."
            case .internalError:
                return mapInternalAuthError(nsError)
            default:
                return "Authentication failed: \(authErrorDebugDetails(nsError))"
            }
        }

        if nsError.domain == FirestoreErrorDomain {
            switch nsError.code {
            case 7:
                return "Firestore permission denied. Update Firestore security rules for registration writes."
            case 16:
                return "Firestore request was unauthenticated. Please try again."
            case 14:
                return "Firestore is unavailable right now. Please try again."
            case 5:
                return "Firestore database is not set up yet. Create a Firestore database in Firebase Console."
            default:
                return "Database error: \(nsError.localizedDescription)"
            }
        }

        return nsError.localizedDescription
    }
}

struct UserProfile {
    let uid: String
    let username: String
    let email: String
    let gender: String
    let createdAt: Date?
    let avatarColorHex: String
    let avatarImageBase64: String?
    let coverImageBase64: String?
}

enum AuthFlowError: LocalizedError {
    case usernameNotFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .usernameNotFound:
            return "Username not found."
        case .unknown:
            return "Unexpected error."
        }
    }
}
