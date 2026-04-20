import SwiftUI
import FirebaseAuth
import PhotosUI

@MainActor
struct ProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedCoverPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var isUploadingCoverPhoto = false

    private let avatarColors = ["#0984E3", "#6C5CE7", "#00B894", "#E17055", "#E84393", "#2D3436"]

    var body: some View {
        let currentProfile = authViewModel.profile
        let displayName = currentProfile?.username ?? authViewModel.currentUser?.displayName ?? "User"
        let displayEmail = currentProfile?.email ?? authViewModel.currentUser?.email ?? "-"

        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    profileHeader(
                        profile: currentProfile,
                        displayName: displayName,
                        displayEmail: displayEmail
                    )

                    uploadPanel(profile: currentProfile)

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
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.black.opacity(0.07), lineWidth: 1)
                    )

                    VStack(spacing: 14) {
                        profileRow(title: "Username", value: displayName)
                        profileRow(title: "Email", value: displayEmail)
                        profileRow(title: "Gender", value: currentProfile?.gender ?? "-")
                        profileRow(title: "Color Code", value: currentProfile?.avatarColorHex ?? "-")
                        profileRow(title: "Member Since", value: memberSinceText(from: currentProfile?.createdAt))
                        profileRow(title: "On Platform", value: memberDurationText(from: currentProfile?.createdAt))
                    }
                    .padding(18)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
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
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
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
            .onChange(of: selectedCoverPhotoItem) { _, newItem in
                guard let newItem else { return }

                Task {
                    await uploadCoverPhoto(from: newItem)
                }
            }
        }
    }

    @ViewBuilder
    private func profileHeader(profile: UserProfile?, displayName: String, displayEmail: String) -> some View {
        ZStack(alignment: .topTrailing) {
            profileCoverArtwork(profile: profile)
                .frame(height: 240)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.04),
                            Color.black.opacity(0.16),
                            Color.black.opacity(0.56)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 16) {
                        ProfileInitialAvatarView(profile: profile)
                            .frame(width: 98, height: 98)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(displayEmail)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.86))
                                .lineLimit(1)

                            Text("Make the profile feel personal with a cover photo and avatar.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(18)
                }

            PhotosPicker(
                selection: $selectedCoverPhotoItem,
                matching: .images
            ) {
                Label(
                    profile?.coverImageBase64 == nil ? "Add Cover" : "Change Cover",
                    systemImage: "photo.badge.plus"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .disabled(isUploadingCoverPhoto)
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private func profileCoverArtwork(profile: UserProfile?) -> some View {
        if let coverImage = AvatarImageCodec.image(fromBase64: profile?.coverImageBase64) {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    Color(hex: profile?.avatarColorHex ?? "#0984E3"),
                    Color(hex: profile?.avatarColorHex ?? "#0984E3").opacity(0.58),
                    Color.black.opacity(0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 160, height: 160)
                    .blur(radius: 8)
                    .offset(x: -32, y: -44)
            }
        }
    }

    @ViewBuilder
    private func uploadPanel(profile: UserProfile?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images
            ) {
                Label(
                    profile?.avatarImageBase64 == nil ? "Upload Profile Photo" : "Change Profile Photo",
                    systemImage: "person.crop.circle.badge.plus"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: profile?.avatarColorHex ?? "#0984E3"))
            .disabled(isUploadingPhoto)

            if isUploadingPhoto || isUploadingCoverPhoto {
                VStack(alignment: .leading, spacing: 8) {
                    if isUploadingPhoto {
                        uploadStatusLabel("Uploading profile photo...")
                    }

                    if isUploadingCoverPhoto {
                        uploadStatusLabel("Uploading cover photo...")
                    }
                }
            } else {
                Text("Use a portrait image for the avatar and a wide landscape image for the cover.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func uploadStatusLabel(_ title: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
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

    private func uploadCoverPhoto(from item: PhotosPickerItem) async {
        isUploadingCoverPhoto = true
        defer {
            isUploadingCoverPhoto = false
            selectedCoverPhotoItem = nil
        }

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                authViewModel.authError = "Unable to read the selected cover photo."
                return
            }

            await authViewModel.updateCoverPhoto(with: imageData)
        } catch {
            authViewModel.authError = "Unable to load the selected cover photo."
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
