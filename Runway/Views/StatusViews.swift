import SwiftUI

/// Centered loading indicator with an optional message.
struct LoadingStateView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            ProgressView()
                .scaleEffect(0.8)
                .tint(.secondary)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }
}

/// Centered error display with an icon, title, message, and optional retry action.
struct ErrorStateView: View {
    var title: String = "Something went wrong"
    var message: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.orange)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let onRetry {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

/// Centered empty state with an icon, title, and subtitle.
struct EmptyStateView: View {
    var icon: String
    var iconColor: Color = .secondary
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(iconColor)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
    }
}
