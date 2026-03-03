import Foundation

struct WorkflowStep: Codable, Identifiable {
    let number: Int
    let name: String
    let status: String
    let conclusion: String?

    var id: Int { number }

    var isFailed: Bool {
        conclusion == "failure" || conclusion == "timed_out"
    }

    var isSkipped: Bool {
        conclusion == "skipped"
    }
}

struct WorkflowJob: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let startedAt: Date?
    let completedAt: Date?
    let htmlUrl: String
    let steps: [WorkflowStep]

    var isFailed: Bool {
        conclusion == "failure" || conclusion == "timed_out"
    }

    /// Duration in seconds, nil if not yet complete.
    var duration: TimeInterval? {
        guard let start = startedAt, let end = completedAt else { return nil }
        return end.timeIntervalSince(start)
    }

    var formattedDuration: String? {
        guard let d = duration else { return nil }
        if d < 60 { return "\(Int(d))s" }
        return "\(Int(d / 60))m \(Int(d.truncatingRemainder(dividingBy: 60)))s"
    }
}

struct WorkflowJobsResponse: Codable {
    let totalCount: Int
    let jobs: [WorkflowJob]
}
