import SwiftUI

struct WorkflowRowView: View {
    let workflow: WorkflowRun
    /// Called for running/success rows — opens the run URL in the browser.
    let onTap: () -> Void
    /// Called for failed rows — shows the in-app detail view.
    let onDetail: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 10) {
                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                // Workflow info
                VStack(alignment: .leading, spacing: 3) {
                    Text(workflow.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 0) {
                        Text(workflow.repository.displayFullName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Text(" \u{2022} ")
                            .font(.system(size: 11))
                            .foregroundStyle(.quaternary)

                        Text(workflow.headBranch)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    // "Details" hint for failed rows
                    if workflow.workflowStatus == .failure {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.6))
                    }

                    Text(workflow.formattedDate)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? hoverColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    private func handleTap() {
        if workflow.workflowStatus == .failure {
            onDetail()
        } else {
            onTap()
        }
    }

    private var statusColor: Color {
        switch workflow.workflowStatus {
        case .running: return .orange
        case .success: return .green
        case .failure: return .red
        case .idle: return .gray
        }
    }

    private var hoverColor: Color {
        workflow.workflowStatus == .failure
            ? Color.red.opacity(0.05)
            : Color.primary.opacity(0.06)
    }
}
