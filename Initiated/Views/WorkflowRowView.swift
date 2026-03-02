import SwiftUI

struct WorkflowRowView: View {
    let workflow: WorkflowRun
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator — larger ring with inner dot
                ZStack {
                    Circle()
                        .stroke(statusColor.opacity(0.25), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)

                    // Pulse animation for running workflows
                    if workflow.workflowStatus == .running {
                        Circle()
                            .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                            .scaleEffect(isHovered ? 1.15 : 1.0)
                    }
                }

                // Workflow info
                VStack(alignment: .leading, spacing: 2) {
                    Text(workflow.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(workflow.repository.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Text("\u{2022}")
                            .font(.system(size: 7))
                            .foregroundStyle(.quaternary)

                        Text(workflow.headBranch)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Timestamp
                Text(workflow.formattedDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
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
