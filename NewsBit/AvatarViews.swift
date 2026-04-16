import SwiftUI
import UIKit

struct AvatarCircleView: View {
    let username: String
    let avatarColorHex: String
    let avatarImageBase64: String?
    var fontSize: CGFloat = 18

    var body: some View {
        Group {
            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(AvatarPalette.color(for: avatarColorHex))

                    Text(initial)
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .clipShape(Circle())
        .contentShape(Circle())
    }

    private var initial: String {
        let trimmedName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmedName.first else { return "U" }
        return String(first).uppercased()
    }

    private var avatarImage: UIImage? {
        AvatarImageCodec.image(fromBase64: avatarImageBase64)
    }
}

enum AvatarImageCodec {
    static func image(fromBase64 base64: String?) -> UIImage? {
        guard let base64, !base64.isEmpty, let data = Data(base64Encoded: base64) else {
            return nil
        }

        return UIImage(data: data)
    }

    static func preparedJPEGData(
        from originalData: Data,
        maxPixelSize: CGFloat = 320,
        compressionQuality: CGFloat = 0.72
    ) -> Data? {
        guard let image = UIImage(data: originalData) else {
            return nil
        }

        let resizedImage = resizedImage(from: image, maxPixelSize: maxPixelSize)
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }

    private static func resizedImage(from image: UIImage, maxPixelSize: CGFloat) -> UIImage {
        let maxDimension = max(image.size.width, image.size.height)
        guard maxDimension > maxPixelSize, maxDimension > 0 else {
            return image
        }

        let scale = maxPixelSize / maxDimension
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1

        return UIGraphicsImageRenderer(size: newSize, format: rendererFormat).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

enum AvatarPalette {
    static func color(for hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}
