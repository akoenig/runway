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
        .frame(width: 360, height: 480)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }

    private var headerSection: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .foregroundStyle(statusColor)
                    .font(.system(size: 10))
                
                Text("Initiated")
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
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
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("Welcome to Initiated")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Connect your GitHub account to start monitoring your workflows.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                    Text("Connect GitHub")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(.secondary)
            
            Text("Loading workflows...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 8) {
                Text("Connection Error")
                    .font(.system(size: 18, weight: .semibold))
                
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            Button {
                Task {
                    await viewModel.fetchWorkflowRuns()
                }
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("All Workflows Complete")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("No active workflow runs found. You're all caught up!")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            Spacer()
        }
        .padding()
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var footerSection: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await viewModel.fetchWorkflowRuns()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(viewModel.isLoading ? .tertiary : .secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
            .animation(viewModel.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoading)
            .help("Refresh")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}
