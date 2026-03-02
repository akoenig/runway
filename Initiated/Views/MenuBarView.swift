import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(viewModel: viewModel, showSettings: $showSettings)
            } else {
                headerSection
                contentSection
                footerSection
            }
        }
        .frame(width: 260, height: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
    }

    private var headerSection: some View {
        HStack(spacing: 8) {
            statusIndicator
            
            Text("Initiated")
                .font(.system(size: 13, weight: .semibold))
            
            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch viewModel.overallStatus {
        case .idle:
            return .gray
        case .running:
            return .orange
        case .success:
            return .green
        case .failure:
            return .red
        }
    }

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
            
            Image(systemName: "link.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)

            VStack(spacing: 2) {
                Text("Connect GitHub")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("Link your account to monitor workflows")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings = true
                }
            } label: {
                Text("Connect")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer()
            
            ProgressView()
                .scaleEffect(0.8)
                .tint(.secondary)
            
            Text("Loading...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            VStack(spacing: 2) {
                Text("Connection Error")
                    .font(.system(size: 14, weight: .semibold))
                
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            VStack(spacing: 2) {
                Text("All Clear")
                    .font(.system(size: 14, weight: .semibold))
                
                Text("No active workflows")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var workflowListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.workflows) { workflow in
                    WorkflowRowView(workflow: workflow) {
                        if let url = URL(string: workflow.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    private var footerSection: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
            
            Text(viewModel.statusText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    await viewModel.fetchWorkflowRuns()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(viewModel.isLoading ? .tertiary : .secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
            .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
