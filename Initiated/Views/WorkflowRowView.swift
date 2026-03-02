import SwiftUI

struct WorkflowRowView: View {
    let workflow: WorkflowRun
    let onTap: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                statusIcon
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(workflow.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(workflow.repository.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        
                        Text(workflow.shortSha)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    statusBadge
                    
                    Text(workflow.formattedDate)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.secondary.opacity(0.08) : Color.clear)
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

    @ViewBuilder
    private var statusIcon: some View {
        switch workflow.workflowStatus {
        case .running:
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
            }
        case .success:
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
            }
        case .failure:
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
            }
        case .idle:
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch workflow.workflowStatus {
        case .running:
            Text("Running")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
        case .success:
            Text("Success")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
        case .failure:
            Text("Failed")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
        case .idle:
            Text("Idle")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}
