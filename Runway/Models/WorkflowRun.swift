import AppKit
import Foundation
import SwiftUI

enum WorkflowStatus: String, Codable {
    case idle
    case queued
    case running
    case success
    case failure

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .queued: return "Queued"
        case .running: return "Running"
        case .success: return "Success"
        case .failure: return "Failed"
        }
    }

    /// SwiftUI color for status indicators throughout the app.
    var color: Color {
        switch self {
        case .idle: .gray
        case .queued: .gray
        case .running: .orange
        case .success: .green
        case .failure: .red
        }
    }

    /// AppKit color for the menu bar status dot.
    var nsColor: NSColor {
        switch self {
        case .idle: .systemGray
        case .queued: .systemGray
        case .running: .systemOrange
        case .success: .systemGreen
        case .failure: .systemRed
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
        if status == "in_progress" {
            return .running
        }
        // queued, waiting, requested, pending — all waiting for a runner
        return .queued
    }

    var formattedDate: String {
        let interval = Date().timeIntervalSince(createdAt)

        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }

    var shortSha: String {
        String(headSha.prefix(7))
    }

    static func == (lhs: WorkflowRun, rhs: WorkflowRun) -> Bool {
        lhs.id == rhs.id
    }
}

// NOTE: No explicit CodingKeys here. All decoders use .convertFromSnakeCase,
// which automatically maps full_name → fullName, html_url → htmlUrl, etc.
// Explicit CodingKeys with snake_case raw values CONFLICT with convertFromSnakeCase
// because the strategy converts JSON keys to camelCase before matching against
// CodingKey.stringValue — causing silent decode failures.
struct Repository: Codable, Equatable {
    let id: Int
    let name: String
    let fullName: String?
    let htmlUrl: String?
    let owner: GitHubUser?

    var displayFullName: String {
        fullName ?? "\(owner?.login ?? "unknown")/\(name)"
    }
}

// NOTE: Same as Repository — no explicit CodingKeys. convertFromSnakeCase handles
// total_count → totalCount and workflow_runs → workflowRuns automatically.
struct WorkflowRunsResponse: Codable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]
}
