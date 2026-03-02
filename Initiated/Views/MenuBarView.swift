import AppKit
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
        .frame(width: 340, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            contentSection
            Divider().opacity(0.3)
            footerBar
        }
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

    // MARK: - Workflow List (grouped by status)

    private var runningWorkflows: [WorkflowRun] {
        viewModel.workflows.filter { $0.workflowStatus == .running }
    }

    private var recentWorkflows: [WorkflowRun] {
        viewModel.workflows.filter { $0.workflowStatus != .running }
    }

    private var workflowListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Running section
                if !runningWorkflows.isEmpty {
                    Section {
                        ForEach(runningWorkflows) { workflow in
                            WorkflowRowView(workflow: workflow) {
                                if let url = URL(string: workflow.htmlUrl) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    } header: {
                        sectionHeader(title: "Running", count: runningWorkflows.count)
                    }
                }

                // Recent section
                if !recentWorkflows.isEmpty {
                    Section {
                        ForEach(recentWorkflows) { workflow in
                            WorkflowRowView(workflow: workflow) {
                                if let url = URL(string: workflow.htmlUrl) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    } header: {
                        sectionHeader(title: "Recent", count: nil)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    private func sectionHeader(title: String, count: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)

            if let count = count {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.07))
                    )
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack(spacing: 0) {
            // Refresh button
            Button {
                Task {
                    await viewModel.fetchWorkflowRuns()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(viewModel.isLoading ? .quaternary : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)

            Spacer()

            // Status
            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(viewModel.statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Settings button
            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Empty States

    private var notAuthenticatedView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("Connect GitHub")
                    .font(.system(size: 14, weight: .semibold))

                Text("Open settings to link your account")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            Button {
                showSettings = true
            } label: {
                Text("Open Settings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer()

            ProgressView()
                .scaleEffect(0.8)
                .tint(.secondary)

            Text("Loading workflows...")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.orange)

            VStack(spacing: 4) {
                Text("Something went wrong")
                    .font(.system(size: 13, weight: .semibold))

                Text(message)
                    .font(.system(size: 11))
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.green)

            VStack(spacing: 4) {
                Text("All clear")
                    .font(.system(size: 14, weight: .semibold))

                Text("No active workflow runs")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
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


