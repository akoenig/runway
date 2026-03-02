import Foundation

enum WorkflowStatus: String, Codable {
    case idle
    case running
    case success
    case failure

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .success: return "Success"
        case .failure: return "Failed"
        }
    }
}

struct WorkflowRun: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let workflowId: Int
    let headBranch: String
    let headSha: String
    let status: String
    let conclusion: String?
    let createdAt: Date
    let updatedAt: Date
    let htmlUrl: String
    let repository: Repository

    var workflowStatus: WorkflowStatus {
        if status == "completed" {
            return conclusion == "success" ? .success : .failure
        }
        return .running
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var shortSha: String {
        String(headSha.prefix(7))
    }

    static func == (lhs: WorkflowRun, rhs: WorkflowRun) -> Bool {
        lhs.id == rhs.id
    }
}

struct Repository: Codable, Equatable {
    let id: Int
    let name: String
    let fullName: String?
    let htmlUrl: String?
    let owner: GitHubUser?

    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case fullName = "full_name"
        case htmlUrl = "html_url"
    }
    
    var displayFullName: String {
        fullName ?? "\(owner?.login ?? "unknown")/\(name)"
    }
}

struct WorkflowRunsResponse: Codable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}
