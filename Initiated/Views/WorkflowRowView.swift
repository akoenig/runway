import SwiftUI

struct WorkflowRowView: View {
    let workflow: WorkflowRun
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                statusIcon

                VStack(alignment: .leading, spacing: 1) {
                    Text(workflow.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)

                    Text("\(workflow.repository.name) · \(workflow.shortSha)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    statusBadge
                    
                    Text(workflow.formattedDate)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusBackgroundColor)
                .frame(width: 20, height: 20)
            
            Image(systemName: statusIconName)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(statusColor)
        }
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.system(size: 8, weight: .medium))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill(statusBackgroundColor)
            )
    }

    private var statusIconName: String {
        switch workflow.workflowStatus {
        case .running:
            return "arrow.clockwise"
        case .success:
            return "checkmark"
        case .failure:
            return "xmark"
        case .idle:
            return "circle"
        }
    }

    private var statusText: String {
        switch workflow.workflowStatus {
        case .running:
            return "Running"
        case .success:
            return "Success"
        case .failure:
            return "Failed"
        case .idle:
            return "Idle"
        }
    }

    private var statusColor: Color {
        switch workflow.workflowStatus {
        case .running:
            return .orange
        case .success:
            return .green
        case .failure:
            return .red
        case .idle:
            return .gray
        }
    }

    private var statusBackgroundColor: Color {
        statusColor.opacity(0.1)
    }
}
