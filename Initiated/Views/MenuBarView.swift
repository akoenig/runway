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
        .frame(width: 300, height: 380)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            statusIndicator
            
            Text("Initiated")
                .font(.system(size: 15, weight: .semibold))
            
            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.12))
                .frame(width: 28, height: 28)
            
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
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
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)

                VStack(spacing: 4) {
                    Text("Connect GitHub")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Link your account to monitor workflows")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings = true
                }
            } label: {
                Text("Connect")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            
            ProgressView()
                .scaleEffect(0.9)
                .tint(.secondary)
            
            Text("Loading...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)

                VStack(spacing: 4) {
                    Text("Connection Error")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }

            Button {
                Task {
                    await viewModel.fetchWorkflowRuns()
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)

                VStack(spacing: 4) {
                    Text("All Clear")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("No active workflows")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }

    private var workflowListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.workflows) { workflow in
                    WorkflowRowView(workflow: workflow) {
                        if let url = URL(string: workflow.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var footerSection: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                
                Text(viewModel.statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.fetchWorkflowRuns()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(viewModel.isLoading ? .tertiary : .secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
            .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.03))
    }
}
