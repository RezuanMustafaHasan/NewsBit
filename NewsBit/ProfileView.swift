import SwiftUI
import FirebaseAuth
import PhotosUI

@MainActor
struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false

    private let avatarColors = ["#0984E3", "#6C5CE7", "#00B894", "#E17055", "#E84393", "#2D3436"]

    var body: some View {
        let currentProfile = authViewModel.profile

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ProfileInitialAvatarView(profile: currentProfile)
                            .frame(width: 130, height: 130)

                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            Label(
                                currentProfile?.avatarImageBase64 == nil ? "Upload Profile Photo" : "Change Profile Photo",
                                systemImage: "photo.on.rectangle"
                            )
                            .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUploadingPhoto)

                        if isUploadingPhoto {
                            ProgressView("Uploading photo...")
                                .font(.caption)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Avatar Color")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            ForEach(avatarColors, id: \.self) { hex in
                                Button {
                                    Task {
                                        await authViewModel.updateAvatarColor(hex: hex)
                                    }
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle().stroke(
                                                (currentProfile?.avatarColorHex == hex) ? Color.black : Color.clear,
                                                lineWidth: 2
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 14) {
                        profileRow(title: "Username", value: currentProfile?.username ?? authViewModel.currentUser?.displayName ?? "-")
                        profileRow(title: "Email", value: currentProfile?.email ?? authViewModel.currentUser?.email ?? "-")
                        profileRow(title: "Gender", value: currentProfile?.gender ?? "-")
                        profileRow(title: "Color Code", value: currentProfile?.avatarColorHex ?? "-")
                        profileRow(title: "Member Since", value: memberSinceText(from: currentProfile?.createdAt))
                        profileRow(title: "On Platform", value: memberDurationText(from: currentProfile?.createdAt))
                    }
                    .padding(18)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.07), lineWidth: 1)
                    )

                    if let authError = authViewModel.authError {
                        Text(authError)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("Log Out") {
                        authViewModel.signOut()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .task {
                await authViewModel.fetchProfile()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }

                Task {
                    await uploadProfilePhoto(from: newItem)
                }
            }
        }
    }

    @ViewBuilder
    private func profileRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    private func memberSinceText(from date: Date?) -> String {
        guard let date else { return "-" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func memberDurationText(from date: Date?) -> String {
        guard let date else { return "-" }

        let components = Calendar.current.dateComponents([.year, .month, .day], from: date, to: Date())

        if let years = components.year, years > 0 {
            return years == 1 ? "1 year" : "\(years) years"
        }

        if let months = components.month, months > 0 {
            return months == 1 ? "1 month" : "\(months) months"
        }

        let days = max(components.day ?? 0, 0)
        return days == 1 ? "1 day" : "\(days) days"
    }

    private func uploadProfilePhoto(from item: PhotosPickerItem) async {
        isUploadingPhoto = true
        defer {
            isUploadingPhoto = false
            selectedPhotoItem = nil
        }

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                authViewModel.authError = "Unable to read the selected photo."
                return
            }

            await authViewModel.updateProfilePhoto(with: imageData)
        } catch {
            authViewModel.authError = "Unable to load the selected photo."
        }
    }
}

struct ProfileInitialAvatarView: View {
    let profile: UserProfile?

    var body: some View {
        AvatarCircleView(
            username: profile?.username ?? "User",
            avatarColorHex: profile?.avatarColorHex ?? "#0984E3",
            avatarImageBase64: profile?.avatarImageBase64,
            fontSize: 54
        )
        .overlay(Circle().stroke(Color.white, lineWidth: 4))
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 4)
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}
