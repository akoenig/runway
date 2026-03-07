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
    /// Monotonically increasing tick that forces SwiftUI to re-render
    /// after each poll, even when the fetched data is structurally identical.
    @State private var refreshTick: UInt64 = 0

    init(workflow: WorkflowRun, onBack: @escaping () -> Void) {
        _workflow = State(initialValue: workflow)
        self.onBack = onBack
    }

    /// True only when the workflow is actively executing — drives the pulse animation.
    private var isRunning: Bool {
        workflow.workflowStatus == .running
    }

    /// True while the workflow is waiting or executing — drives the polling loop.
    private var isActive: Bool {
        workflow.workflowStatus == .running || workflow.workflowStatus == .queued
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
        (workflow.workflowStatus.color, workflow.workflowStatus.displayName)
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
        LoadingStateView(message: "Loading details...")
    }

    private func errorView(message: String) -> some View {
        ErrorStateView(title: "Couldn't load details", message: message)
    }

    private var emptyJobsView: some View {
        EmptyStateView(icon: "tray", title: "No job details available")
    }

    private var jobsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                metaRow
                Divider().opacity(0.15).padding(.horizontal, 16)
                let now = Date()
                ForEach(jobs) { job in
                    JobRowView(job: job, now: now, onViewLog: { step in
                        selectedLog = (job: job, step: step)
                    })
                    .id("\(job.id)-\(refreshTick)")
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

    @State private var didCopyURL: Bool = false

    private var footerBar: some View {
        HStack {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(workflow.htmlUrl, forType: .string)
                didCopyURL = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    didCopyURL = false
                }
            } label: {
                Image(systemName: didCopyURL ? "checkmark" : "link")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

    /// Initial load + polling loop while the workflow is active (queued or running).
    private func loadAndPoll() async {
        await fetchJobs()
        guard isActive else { return }
        // Poll every 5 seconds while workflow is queued or in-progress
        while !Task.isCancelled && isActive {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if Task.isCancelled { break }
            await refreshWorkflow()
            await refreshJobs()
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

    /// Initial fetch — shows loading indicator.
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

    /// Subsequent refresh — no loading indicator, bumps refreshTick
    /// to guarantee SwiftUI re-renders even if the data is identical.
    private func refreshJobs() async {
        do {
            jobs = try await GitHubService.shared.fetchJobs(
                runId: workflow.id,
                repo: workflow.repository
            )
            refreshTick &+= 1
        } catch {
            // Silently ignore — keep showing last known jobs
        }
    }
}

// MARK: - Job Row

private struct JobRowView: View {
    let job: WorkflowJob
    let now: Date
    let onViewLog: (WorkflowStep) -> Void
    @State private var expanded: Bool

    init(job: WorkflowJob, now: Date, onViewLog: @escaping (WorkflowStep) -> Void) {
        self.job = job
        self.now = now
        self.onViewLog = onViewLog
        // Auto-expand failed and in-progress jobs
        _expanded = State(initialValue: job.isFailed || job.isInProgress)
    }

    private var stepProgress: String {
        let completed = job.completedStepCount
        let total = job.steps.count
        return "\(completed)/\(total)"
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

                    if job.isInProgress {
                        // Step progress + elapsed time for running jobs
                        HStack(spacing: 6) {
                            Text(stepProgress)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.orange.opacity(0.7))

                            if let elapsed = job.elapsedSince(now) {
                                Text(elapsed)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.quaternary)
                            }
                        }
                    } else if let dur = job.formattedDuration {
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
                    ForEach(job.steps) { step in
                        StepRowView(
                            step: step,
                            isLogAvailable: step.isSuccess || step.isFailed,
                            onViewLog: { onViewLog(step) }
                        )
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
            HStack(spacing: 8) {
                // Indent line
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 1)
                    .padding(.leading, 27)

                stepStatusIcon

                Text(step.name)
                    .font(.system(size: 11))
                    .foregroundStyle(stepTextColor)
                    .lineLimit(2)

                Spacer()

                if let dur = step.formattedDuration {
                    Text(dur)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }

                stepStatusLabel

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

    // MARK: - Step Status Icon

    @ViewBuilder
    private var stepStatusIcon: some View {
        if step.isInProgress {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
        } else if step.isSuccess {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
        } else if step.isFailed {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        } else if step.isSkipped {
            Image(systemName: "minus.circle")
                .font(.system(size: 12))
                .foregroundStyle(.gray.opacity(0.5))
        } else {
            // Pending / queued
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                .frame(width: 12, height: 12)
        }
    }

    // MARK: - Step Status Label

    @ViewBuilder
    private var stepStatusLabel: some View {
        if step.isFailed {
            Text("failed")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.red.opacity(0.8))
        } else if step.isInProgress {
            Text("running")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.orange.opacity(0.8))
        } else if step.isSkipped {
            Text("skipped")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.gray.opacity(0.5))
        } else if step.isPending {
            Text("pending")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.gray.opacity(0.5))
        }
        // Success steps show no label — the checkmark icon is enough
    }

    // MARK: - Styling

    private var stepTextColor: Color {
        if step.isFailed { return .primary }
        if step.isInProgress { return .primary }
        if step.isSkipped { return .secondary.opacity(0.5) }
        if step.isPending { return .secondary.opacity(0.5) }
        return .secondary
    }

    private var rowBackground: Color {
        if isHovered && isLogAvailable { return Color.primary.opacity(0.05) }
        if step.isFailed { return Color.red.opacity(0.04) }
        if step.isInProgress { return Color.orange.opacity(0.03) }
        return Color.clear
    }
}
