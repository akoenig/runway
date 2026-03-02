import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(viewModel: viewModel, showSettings: $showSettings)
            } else {
                mainContent
            }
        }
        .frame(width: 300, height: 360)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().opacity(0.4)
            contentSection
            Divider().opacity(0.4)
            footerSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            Text("Initiated")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.05))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        if !viewModel.isAuthenticated {
            notAuthenticatedView
        } else if viewModel.isLoading && viewModel.workflows.isEmpty {
            loadingView
        } else if let error = viewModel.errorMessage, viewModel.workflows.isEmpty {
            errorView(message: error)
        } else if viewModel.workflows.isEmpty {
            emptyStateView
        } else {
            workflowListView
        }
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Connect GitHub")
                    .font(.system(size: 13, weight: .medium))

                Text("Open settings to link your account")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showSettings = true
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer()

            ProgressView()
                .scaleEffect(0.7)
                .tint(.secondary)

            Text("Loading workflows...")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 10) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.orange)

            VStack(spacing: 3) {
                Text("Something went wrong")
                    .font(.system(size: 12, weight: .medium))

                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Button {
                Task {
                    await viewModel.fetchWorkflowRuns()
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 14)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.green)

            VStack(spacing: 3) {
                Text("All clear")
                    .font(.system(size: 13, weight: .medium))

                Text("No active workflow runs")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    private var workflowListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.workflows.enumerated()), id: \.element.id) { index, workflow in
                    WorkflowRowView(workflow: workflow) {
                        if let url = URL(string: workflow.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    if index < viewModel.workflows.count - 1 {
                        Divider()
                            .padding(.leading, 30)
                            .opacity(0.3)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)

            Text(viewModel.statusText)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                Task {
                    await viewModel.fetchWorkflowRuns()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(viewModel.isLoading ? .quaternary : .secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.primary.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
            .animation(
                viewModel.isLoading
                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                    : .default,
                value: viewModel.isLoading
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch viewModel.overallStatus {
        case .idle: return .gray
        case .running: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }
}
