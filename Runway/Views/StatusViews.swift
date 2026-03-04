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
    }
}

/// GitHub's Invertocat mark rendered as a SwiftUI `Shape` so it can be
/// styled with `foregroundStyle` and scaled to any size.
struct GitHubLogo: Shape {
    func path(in rect: CGRect) -> Path {
        // Normalized from the official GitHub mark (viewBox 0 0 98 96).
        let sx = rect.width / 98
        let sy = rect.height / 96
        var p = Path()

        p.move(to: CGPoint(x: 49 * sx, y: 0))
        p.addCurve(
            to: CGPoint(x: 0, y: 48 * sy),
            control1: CGPoint(x: 21.94 * sx, y: 0),
            control2: CGPoint(x: 0, y: 21.47 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 33.5 * sx, y: 93.45 * sy),
            control1: CGPoint(x: 0, y: 69.26 * sy),
            control2: CGPoint(x: 14.1 * sx, y: 87.58 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 36.37 * sx, y: 89.58 * sy),
            control1: CGPoint(x: 35.87 * sx, y: 93.89 * sy),
            control2: CGPoint(x: 36.96 * sx, y: 91.86 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 36.37 * sx, y: 82.17 * sy),
            control1: CGPoint(x: 35.78 * sx, y: 87.3 * sy),
            control2: CGPoint(x: 36.37 * sx, y: 82.17 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 21.56 * sx, y: 78.36 * sy),
            control1: CGPoint(x: 25.2 * sx, y: 84.62 * sy),
            control2: CGPoint(x: 21.56 * sx, y: 78.36 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 16.33 * sx, y: 71.17 * sy),
            control1: CGPoint(x: 19.16 * sx, y: 72.6 * sy),
            control2: CGPoint(x: 16.33 * sx, y: 71.17 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 24.71 * sx, y: 71.17 * sy),
            control1: CGPoint(x: 16.33 * sx, y: 71.17 * sy),
            control2: CGPoint(x: 20.58 * sx, y: 67.4 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 31.12 * sx, y: 79.56 * sy),
            control1: CGPoint(x: 28.84 * sx, y: 74.94 * sy),
            control2: CGPoint(x: 31.12 * sx, y: 79.56 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 47.77 * sx, y: 76.72 * sy),
            control1: CGPoint(x: 36.37 * sx, y: 88.65 * sy),
            control2: CGPoint(x: 47.18 * sx, y: 80.49 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 35.18 * sx, y: 66.92 * sy),
            control1: CGPoint(x: 38.79 * sx, y: 75.04 * sy),
            control2: CGPoint(x: 35.18 * sx, y: 71.89 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 49 * sx, y: 48 * sy),
            control1: CGPoint(x: 35.18 * sx, y: 56.66 * sy),
            control2: CGPoint(x: 40.82 * sx, y: 48 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 62.82 * sx, y: 66.92 * sy),
            control1: CGPoint(x: 57.18 * sx, y: 48 * sy),
            control2: CGPoint(x: 62.82 * sx, y: 56.66 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 50.23 * sx, y: 76.72 * sy),
            control1: CGPoint(x: 62.82 * sx, y: 71.89 * sy),
            control2: CGPoint(x: 59.21 * sx, y: 75.04 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 61.63 * sx, y: 82.17 * sy),
            control1: CGPoint(x: 51.43 * sx, y: 77.92 * sy),
            control2: CGPoint(x: 61.63 * sx, y: 82.17 * sy)
        )
        p.addLine(to: CGPoint(x: 61.63 * sx, y: 89.58 * sy))
        p.addCurve(
            to: CGPoint(x: 64.5 * sx, y: 93.45 * sy),
            control1: CGPoint(x: 61.04 * sx, y: 91.86 * sy),
            control2: CGPoint(x: 62.13 * sx, y: 93.89 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 98 * sx, y: 48 * sy),
            control1: CGPoint(x: 83.9 * sx, y: 87.58 * sy),
            control2: CGPoint(x: 98 * sx, y: 69.26 * sy)
        )
        p.addCurve(
            to: CGPoint(x: 49 * sx, y: 0),
            control1: CGPoint(x: 98 * sx, y: 21.47 * sy),
            control2: CGPoint(x: 76.06 * sx, y: 0)
        )
        p.closeSubpath()

        return p
    }
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
