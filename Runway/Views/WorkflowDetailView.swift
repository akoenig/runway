import AppKit
import SwiftUI

struct WorkflowDetailView: View {
    @State private var workflow: WorkflowRun
    let onBack: () -> Void

    @State private var jobs: [WorkflowJob] = []
    @State private var isLoading: Bool = false
    @State private var fetchError: String?
    /// When set, shows JobLogView for the selected (job, step) pair.
    @State private var selectedLog: (job: WorkflowJob, step: WorkflowStep)?

    init(workflow: WorkflowRun, onBack: @escaping () -> Void) {
        _workflow = State(initialValue: workflow)
        self.onBack = onBack
    }

    private var isRunning: Bool {
        workflow.workflowStatus == .running
    }

    var body: some View {
        if let selection = selectedLog {
            JobLogView(
                job: selection.job,
                step: selection.step,
                repo: workflow.repository
            ) {
                selectedLog = nil
            }
        } else {
            detailBody
        }
    }

    private var detailBody: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.3)
            content
            Divider().opacity(0.3)
            footerBar
        }
        .task { await loadAndPoll() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(workflow.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(workflow.repository.displayFullName)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            statusBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var statusBadge: some View {
        let (color, label) = badgeStyle
        return HStack(spacing: 4) {
            if isRunning {
                // Subtle pulse for running state
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .opacity(isLoading ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isLoading)
            } else {
                Circle().fill(color).frame(width: 6, height: 6)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var badgeStyle: (Color, String) {
        switch workflow.workflowStatus {
        case .running: return (.orange, "Running")
        case .success: return (.green, "Success")
        case .failure: return (.red, "Failed")
        case .idle:    return (.gray, "Idle")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading && jobs.isEmpty {
            loadingView
        } else if let error = fetchError, jobs.isEmpty {
            errorView(message: error)
        } else if jobs.isEmpty {
            emptyJobsView
        } else {
            jobsList
        }
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView().scaleEffect(0.8).tint(.secondary)
            Text("Loading details...")
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
                Text("Couldn't load details")
                    .font(.system(size: 13, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var emptyJobsView: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No job details available")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var jobsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                metaRow
                Divider().opacity(0.15).padding(.horizontal, 16)
                ForEach(jobs) { job in
                    JobRowView(job: job, onViewLog: { step in
                        selectedLog = (job: job, step: step)
                    })
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 16) {
            Label(workflow.headBranch, systemImage: "arrow.branch")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Label(workflow.formattedDate, systemImage: "clock")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Spacer()
            Button {
                if let url = URL(string: workflow.htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .medium))
                    Text("Open on GitHub")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Lifecycle

    /// Initial load + polling loop while the workflow is running.
    private func loadAndPoll() async {
        await fetchJobs()
        guard isRunning else { return }
        // Poll every 5 seconds while workflow is still in-progress
        while !Task.isCancelled && isRunning {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if Task.isCancelled { break }
            await refreshWorkflow()
            await fetchJobs()
        }
    }

    /// Re-fetch the workflow run so the status badge and `isRunning`
    /// flag stay current. When the run completes, the polling loop exits.
    private func refreshWorkflow() async {
        do {
            workflow = try await GitHubService.shared.fetchSingleWorkflowRun(
                runId: workflow.id,
                repo: workflow.repository
            )
        } catch {
            // Silently ignore — keep using last known state
        }
    }

    private func fetchJobs() async {
        isLoading = true
        fetchError = nil
        do {
            jobs = try await GitHubService.shared.fetchJobs(
                runId: workflow.id,
                repo: workflow.repository
            )
        } catch {
            fetchError = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Job Row

private struct JobRowView: View {
    let job: WorkflowJob
    let onViewLog: (WorkflowStep) -> Void
    @State private var expanded: Bool

    init(job: WorkflowJob, onViewLog: @escaping (WorkflowStep) -> Void) {
        self.job = job
        self.onViewLog = onViewLog
        // Auto-expand failed and in-progress jobs
        _expanded = State(initialValue: job.isFailed || job.isInProgress)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Job header — tappable to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    jobStatusIcon

                    Text(job.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    if let dur = job.formattedDuration {
                        Text(dur)
                            .font(.system(size: 11))
                            .foregroundStyle(.quaternary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.quaternary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Steps — visible when expanded
            if expanded {
                VStack(spacing: 0) {
                    ForEach(job.steps.filter { !$0.isSkipped }) { step in
                        StepRowView(step: step, isLogAvailable: !job.isInProgress, onViewLog: { onViewLog(step) })
                    }
                }
                .padding(.bottom, 4)
            }

            Divider().opacity(0.1).padding(.leading, 16)
        }
    }

    private var jobStatusIcon: some View {
        ZStack {
            Circle()
                .fill(jobColor.opacity(0.12))
                .frame(width: 24, height: 24)

            Image(systemName: jobIconName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(jobColor)
        }
    }

    private var jobColor: Color {
        if job.isFailed { return .red }
        if job.conclusion == "success" { return .green }
        if job.isInProgress { return .orange }
        return .gray
    }

    private var jobIconName: String {
        if job.isFailed { return "xmark" }
        if job.conclusion == "success" { return "checkmark" }
        if job.isInProgress { return "arrow.trianglehead.clockwise" }
        return "minus"
    }
}

// MARK: - Step Row

private struct StepRowView: View {
    let step: WorkflowStep
    let isLogAvailable: Bool
    let onViewLog: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onViewLog) {
            HStack(spacing: 10) {
                // Indent line
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1)
                    .padding(.leading, 27)

                Circle()
                    .fill(stepColor)
                    .frame(width: 5, height: 5)

                Text(step.name)
                    .font(.system(size: 11))
                    .foregroundStyle(step.isFailed ? .primary : .secondary)
                    .lineLimit(2)

                Spacer()

                if step.isFailed {
                    Text("failed")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                } else if step.isInProgress {
                    Text("running")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.8))
                }

                if isLogAvailable {
                    Image(systemName: "doc.plaintext")
                        .font(.system(size: 10))
                        .foregroundStyle(isHovered ? .primary : .quaternary)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 5)
            .background(rowBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isLogAvailable)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isHovered { return Color.primary.opacity(0.05) }
        if step.isFailed { return Color.red.opacity(0.04) }
        return Color.clear
    }

    private var stepColor: Color {
        if step.isFailed { return .red }
        if step.isInProgress { return .orange }
        if step.isSuccess { return .green }
        return .gray
    }
}
