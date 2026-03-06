import AppKit
import SwiftUI

struct MenuBarView: View {
    var viewModel: AppViewModel
    @State private var showSettings: Bool = false
    @State private var selectedWorkflow: WorkflowRun?

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(viewModel: viewModel, showSettings: $showSettings)
            } else if let workflow = selectedWorkflow {
                WorkflowDetailView(workflow: workflow) {
                    selectedWorkflow = nil
                }
            } else {
                mainContent
            }
        }
        .frame(width: 340, height: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.onNavigateToMainList = {
                showSettings = false
                selectedWorkflow = nil
            }
        }
        .onChange(of: showSettings) { _, new in
            viewModel.isShowingSubview = new || selectedWorkflow != nil
        }
        .onChange(of: selectedWorkflow) { _, new in
            viewModel.isShowingSubview = showSettings || new != nil
        }
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
        } else if viewModel.selectedRepos.isEmpty {
            noReposSelectedView
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

    private var queuedWorkflows: [WorkflowRun] {
        viewModel.workflows.filter { $0.workflowStatus == .queued }
    }

    private var recentWorkflows: [WorkflowRun] {
        viewModel.workflows.filter { $0.workflowStatus != .running && $0.workflowStatus != .queued }
    }

    private var workflowListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Running section
                if !runningWorkflows.isEmpty {
                    Section {
                        ForEach(runningWorkflows) { workflow in
                            WorkflowRowView(
                                workflow: workflow,
                                onDetail: { selectedWorkflow = workflow }
                            )
                        }
                    } header: {
                        sectionHeader(title: "Running", count: runningWorkflows.count)
                    }
                }

                // Queued section
                if !queuedWorkflows.isEmpty {
                    Section {
                        ForEach(queuedWorkflows) { workflow in
                            WorkflowRowView(
                                workflow: workflow,
                                onDetail: { selectedWorkflow = workflow }
                            )
                        }
                    } header: {
                        sectionHeader(title: "Queued", count: queuedWorkflows.count)
                    }
                }

                // Recent section
                if !recentWorkflows.isEmpty {
                    Section {
                        ForEach(recentWorkflows) { workflow in
                            WorkflowRowView(
                                workflow: workflow,
                                onDetail: { selectedWorkflow = workflow }
                            )
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

    @State private var spinDegrees: Double = 0

    private var footerBar: some View {
        HStack(spacing: 0) {
            // Refresh button
            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    spinDegrees += 360
                }
                Task {
                    await viewModel.fetchWorkflowRuns()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(viewModel.isLoading ? .quaternary : .secondary)
                    .rotationEffect(.degrees(spinDegrees))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)

            Spacer()

            // Status
            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.overallStatus.color)
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

    private var noReposSelectedView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("No repositories selected")
                    .font(.system(size: 14, weight: .semibold))

                Text("Choose which repositories to monitor in settings")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
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
        .padding(.horizontal, 20)
    }

    private var loadingView: some View {
        LoadingStateView(message: "Loading workflows...")
    }

    private func errorView(message: String) -> some View {
        ErrorStateView(message: message) {
            Task { await viewModel.fetchWorkflowRuns() }
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "checkmark.circle",
            iconColor: .green,
            title: "All clear",
            subtitle: "No active workflow runs"
        )
    }
}


