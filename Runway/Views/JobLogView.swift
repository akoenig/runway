import AppKit
import SwiftUI

struct JobLogView: View {
    let job: WorkflowJob
    let step: WorkflowStep
    let repo: Repository
    let onBack: () -> Void

    @State private var allLines: [LogLine] = []
    @State private var isLoading = true
    @State private var fetchError: String?
    @State private var copied = false

    private var stepLines: [LogLine] {
        allLines.filter { $0.stepNumber == step.number }
    }

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
                Text(step.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(job.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            stepStatusBadge
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var stepStatusBadge: some View {
        let color: Color = step.isFailed ? .red : (step.isInProgress ? .orange : .green)
        let label: String = step.isFailed ? "Failed" : (step.isInProgress ? "Running" : "Success")
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingView
        } else if let error = fetchError {
            errorView(message: error)
        } else if stepLines.isEmpty {
            emptyView
        } else {
            logScrollView
        }
    }

    private var loadingView: some View {
        LoadingStateView(message: "Loading log...")
    }

    private func errorView(message: String) -> some View {
        ErrorStateView(title: "Couldn't load log", message: message)
    }

    private var emptyView: some View {
        EmptyStateView(icon: "doc.text", title: "No log output for this step")
    }

    private var logScrollView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(stepLines) { line in
                    Text(line.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(lineColor(line))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 1)
                        .background(line.isError ? Color.red.opacity(0.06) : Color.clear)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func lineColor(_ line: LogLine) -> Color {
        if line.isError { return .red }
        if line.isWarning { return .orange }
        return .secondary
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 8) {
            Button {
                copyStepLog()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                    Text(copied ? "Copied" : "Copy Log")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(copied ? .green : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(stepLines.isEmpty)

            Spacer()

            Button {
                if let url = URL(string: job.htmlUrl) {
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

    private func copyStepLog() {
        let text = stepLines.map(\.content).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        withAnimation(.easeInOut(duration: 0.15)) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeInOut(duration: 0.15)) { copied = false }
        }
    }

    private func load() async {
        isLoading = true
        fetchError = nil
        do {
            allLines = try await GitHubService.shared.fetchJobLogs(jobId: job.id, repo: repo, steps: job.steps)
        } catch {
            fetchError = error.localizedDescription
        }
        isLoading = false
    }
}
