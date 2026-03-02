import SwiftUI

struct WorkflowRowView: View {
    let workflow: WorkflowRun
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                // Workflow info
                VStack(alignment: .leading, spacing: 2) {
                    Text(workflow.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 0) {
                        Text(workflow.repository.name)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        Text(" \u{00B7} ")
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)

                        Text(workflow.headBranch)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Timestamp
                Text(workflow.formattedDate)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
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

    private var statusColor: Color {
        switch workflow.workflowStatus {
        case .running: return .orange
        case .success: return .green
        case .failure: return .red
        case .idle: return .gray
        }
    }
}
