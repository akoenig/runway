import AppKit
import SwiftUI

struct WorkflowDetailView: View {
    let workflow: WorkflowRun
    let onBack: () -> Void

    @State private var jobs: [WorkflowJob] = []
    @State private var isLoading: Bool = false
    @State private var fetchError: String?
    @State private var copied: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.3)
            content
            Divider().opacity(0.3)
            footerBar
        }
        .task { await load() }
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

            // Status badge
            statusBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(workflow.workflowStatus == .failure ? "Failed" : "Success")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingView
        } else if let error = fetchError {
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
                // Branch + timing info
                metaRow

                Divider().opacity(0.15).padding(.horizontal, 16)

                // Jobs
                ForEach(jobs) { job in
                    JobRowView(job: job)
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
        HStack(spacing: 8) {
            // Copy summary button
            Button {
                copyToClipboard()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                    Text(copied ? "Copied" : "Copy Summary")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(copied ? .green : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)

            Spacer()

            // Open on GitHub
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

    // MARK: - Helpers

    private var statusColor: Color {
        workflow.workflowStatus == .failure ? .red : .green
    }

    private func copyToClipboard() {
        let summary = buildSummary()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)

        withAnimation(.easeInOut(duration: 0.15)) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.15)) {
                copied = false
            }
        }
    }

    private func buildSummary() -> String {
        var lines: [String] = []
        lines.append("Workflow: \(workflow.name)")
        lines.append("Repository: \(workflow.repository.displayFullName)")
        lines.append("Branch: \(workflow.headBranch)")
        lines.append("Status: \(workflow.workflowStatus == .failure ? "Failed" : "Success")")
        lines.append("URL: \(workflow.htmlUrl)")

        let failedJobs = jobs.filter { $0.isFailed }
        if !failedJobs.isEmpty {
            lines.append("")
            lines.append("Failed Jobs:")
            for job in failedJobs {
                lines.append("  • \(job.name)")
                let failedSteps = job.steps.filter { $0.isFailed }
                for step in failedSteps {
                    lines.append("    ✗ \(step.name)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Lifecycle

    func load() async {
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
    @State private var expanded: Bool

    init(job: WorkflowJob) {
        self.job = job
        // Auto-expand failed jobs
        _expanded = State(initialValue: job.isFailed)
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
                        StepRowView(step: step)
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
        if job.status == "in_progress" { return .orange }
        return .gray
    }

    private var jobIconName: String {
        if job.isFailed { return "xmark" }
        if job.conclusion == "success" { return "checkmark" }
        if job.status == "in_progress" { return "arrow.trianglehead.clockwise" }
        return "minus"
    }
}

// MARK: - Step Row

private struct StepRowView: View {
    let step: WorkflowStep

    var body: some View {
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
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 5)
        .background(step.isFailed ? Color.red.opacity(0.04) : Color.clear)
    }

    private var stepColor: Color {
        if step.isFailed { return .red }
        if step.conclusion == "success" { return .green }
        return .gray
    }
}
