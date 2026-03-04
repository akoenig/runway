import Foundation

struct LogLine: Identifiable {
    let id = UUID()
    let content: String
    let isError: Bool
    let isWarning: Bool
    /// 1-based step number this line belongs to, matching `WorkflowStep.number`.
    let stepNumber: Int
}

struct WorkflowStep: Codable, Identifiable {
    let number: Int
    let name: String
    let status: String
    let conclusion: String?
    let startedAt: Date?
    let completedAt: Date?

    var id: Int { number }

    var isFailed: Bool {
        conclusion == "failure" || conclusion == "timed_out"
    }

    var isInProgress: Bool {
        status == "in_progress"
    }

    var isSkipped: Bool {
        conclusion == "skipped"
    }

    var isSuccess: Bool {
        conclusion == "success"
    }

    var isPending: Bool {
        status == "queued"
    }

    var formattedDuration: String? {
        guard let start = startedAt, let end = completedAt else { return nil }
        let d = end.timeIntervalSince(start)
        if d < 1 { return "<1s" }
        if d < 60 { return "\(Int(d))s" }
        return "\(Int(d / 60))m \(Int(d.truncatingRemainder(dividingBy: 60)))s"
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

    var isInProgress: Bool {
        status == "in_progress"
    }

    /// Number of steps that have completed (success, failure, or skipped).
    var completedStepCount: Int {
        steps.filter { $0.status == "completed" }.count
    }

    /// Elapsed time since the job started, formatted for display.
    /// Returns nil if the job hasn't started.
    func elapsedSince(_ now: Date) -> String? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? now
        let d = end.timeIntervalSince(start)
        if d < 1 { return "<1s" }
        if d < 60 { return "\(Int(d))s" }
        return "\(Int(d / 60))m \(Int(d.truncatingRemainder(dividingBy: 60)))s"
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
