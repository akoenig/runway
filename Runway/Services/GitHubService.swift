import Foundation

enum GitHubAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case noToken
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from GitHub"
        case .httpError(let statusCode, let message):
            return "GitHub API error (\(statusCode)): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noToken:
            return "No GitHub token configured"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

final class GitHubService: @unchecked Sendable {
    static let shared = GitHubService()
    
    private let baseURL = "https://api.github.com"
    private let session: URLSession

    /// Shared decoder configured for the GitHub API. Uses `convertFromSnakeCase`
    /// and a custom ISO8601 date strategy that handles both fractional and
    /// non-fractional second formats GitHub returns.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = withFractional.date(from: dateString) {
                return date
            }
            if let date = withoutFractional.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(dateString)"
            )
        }

        return decoder
    }()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    private func createRequest(path: String, method: String = "GET") throws -> URLRequest {
        guard let token = try? KeychainService.shared.getToken() else {
            throw GitHubAPIError.noToken
        }

        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw GitHubAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return request
    }

    /// Performs a GitHub API request, validates the HTTP response, and decodes
    /// the result into the requested type using the shared decoder.
    private func fetch<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        let request = try createRequest(path: path)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try Self.decoder.decode(type, from: data)
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    func validateToken() async throws -> GitHubUser {
        try await fetch(GitHubUser.self, path: "/user")
    }

    func fetchUserRepos(perPage: Int = 10) async throws -> [Repository] {
        try await fetch([Repository].self, path: "/user/repos?sort=updated&per_page=\(perPage)")
    }

    func fetchWorkflowRuns(for repo: Repository, perPage: Int = 5) async throws -> [WorkflowRun] {
        let owner = repo.owner?.login ?? "unknown"
        let response = try await fetch(
            WorkflowRunsResponse.self,
            path: "/repos/\(owner)/\(repo.name)/actions/runs?per_page=\(perPage)"
        )
        return response.workflowRuns
    }

    func fetchSingleWorkflowRun(runId: Int, repo: Repository) async throws -> WorkflowRun {
        let owner = repo.owner?.login ?? "unknown"
        return try await fetch(
            WorkflowRun.self,
            path: "/repos/\(owner)/\(repo.name)/actions/runs/\(runId)"
        )
    }

    func fetchJobs(runId: Int, repo: Repository) async throws -> [WorkflowJob] {
        let owner = repo.owner?.login ?? "unknown"
        let response = try await fetch(
            WorkflowJobsResponse.self,
            path: "/repos/\(owner)/\(repo.name)/actions/runs/\(runId)/jobs?per_page=100"
        )
        return response.jobs
    }

    func fetchJobLogs(jobId: Int, repo: Repository, steps: [WorkflowStep]) async throws -> [LogLine] {
        let owner = repo.owner?.login ?? "unknown"
        let request = try createRequest(
            path: "/repos/\(owner)/\(repo.name)/actions/jobs/\(jobId)/logs"
        )

        // URLSession follows the 302 redirect automatically; the final response is plain text.
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let raw = String(data: data, encoding: .utf8) ?? ""
        return GitHubService.parseLogLines(raw, steps: steps)
    }

    /// Parse raw GitHub Actions log text into structured `LogLine` values.
    ///
    /// The raw log uses `##[group]` markers for both top-level step
    /// boundaries and inner sub-sections within actions. The YAML step
    /// `name:` is **not** used in the log — instead, top-level groups
    /// always start with `"Run "` followed by the command or action ref.
    /// Inner sub-groups (e.g. "Getting Git version info" from
    /// actions/checkout) never start with `"Run "`.
    ///
    /// Strategy: map `"Run …"` groups sequentially to user-facing API
    /// steps (excluding internal steps like "Set up job", "Post …", and
    /// "Complete job"). Non-`"Run "` groups are treated as sub-sections
    /// of the current step.
    static func parseLogLines(_ raw: String, steps: [WorkflowStep]) -> [LogLine] {
        // User-facing steps sorted by number. Internal runner steps
        // ("Set up job", "Post …", "Complete job") don't have "Run …"
        // groups in the log, so we exclude them from the sequential map.
        let userSteps = steps
            .filter { !isInternalStepName($0.name) }
            .sorted { $0.number < $1.number }
        var userStepIndex = 0

        // Assign pre-"Run …" log lines (runner info, etc.) to "Set up job"
        // if it exists, so clicking that step still shows content.
        let setupStepNumber = steps.first { $0.name == "Set up job" }?.number ?? 0
        var currentStep = setupStepNumber

        // Regex to strip the leading ISO8601 timestamp: "2024-01-15T10:23:45.1234567Z "
        let timestampPattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z "#
        let timestampRegex = try? NSRegularExpression(pattern: timestampPattern)

        // ANSI escape code pattern
        let ansiPattern = #"\x1B\[[0-9;]*[mGKHF]"#
        let ansiRegex = try? NSRegularExpression(pattern: ansiPattern)

        var lines: [LogLine] = []

        for rawLine in raw.components(separatedBy: "\n") {
            var line = rawLine

            // Strip timestamp prefix
            if let regex = timestampRegex {
                let range = NSRange(line.startIndex..., in: line)
                line = regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
            }

            // Strip ANSI codes
            if let regex = ansiRegex {
                let range = NSRange(line.startIndex..., in: line)
                line = regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
            }

            if line.hasPrefix("##[group]") {
                let groupName = String(line.dropFirst("##[group]".count))

                if groupName.hasPrefix("Run ") {
                    // Top-level step group — map to the next user step.
                    if userStepIndex < userSteps.count {
                        currentStep = userSteps[userStepIndex].number
                        userStepIndex += 1
                    }
                }
                // Non-"Run " groups are inner sub-sections (e.g.
                // "Getting Git version info") or setup metadata
                // ("Runner Image Provisioner") — keep currentStep.
                continue
            }

            // Skip endgroup markers and blank lines
            if line.hasPrefix("##[endgroup]") || line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            let isError = line.hasPrefix("##[error]")
            let isWarning = line.hasPrefix("##[warning]")

            // Strip directive prefix so UI shows clean content
            if isError {
                line = String(line.dropFirst("##[error]".count))
            } else if isWarning {
                line = String(line.dropFirst("##[warning]".count))
            }

            lines.append(LogLine(content: line, isError: isError, isWarning: isWarning, stepNumber: currentStep))
        }

        return lines
    }

    /// Internal runner steps that don't have corresponding "Run …" groups
    /// in the raw log. These are managed by the Actions runner itself.
    private static func isInternalStepName(_ name: String) -> Bool {
        name == "Set up job" ||
        name == "Complete job" ||
        name.hasPrefix("Post ")
    }

    /// Cached list of user repos so the polling loop doesn't re-fetch them
    /// on every cycle. Call `invalidateRepoCache()` to force a refresh.
    private var cachedRepos: [Repository]?

    func invalidateRepoCache() {
        cachedRepos = nil
    }

    /// Returns cached repos or fetches them if the cache is empty.
    private func resolveRepos() async throws -> [Repository] {
        if let cached = cachedRepos {
            return cached
        }
        let repos = try await fetchUserRepos(perPage: 100)
        cachedRepos = repos
        return repos
    }

    func fetchWorkflowRuns(forSelectedRepos selectedRepoNames: [String], maxRuns: Int = 10) async throws -> [WorkflowRun] {
        let repos = try await resolveRepos()

        // Filter to only selected repos
        let selectedRepos = repos.filter { selectedRepoNames.contains($0.displayFullName) }

        // Fetch workflow runs concurrently across all selected repos
        let allRuns = try await withThrowingTaskGroup(of: [WorkflowRun].self) { group in
            for repo in selectedRepos {
                group.addTask {
                    do {
                        return try await self.fetchWorkflowRuns(for: repo, perPage: 3)
                    } catch {
                        // Skip repos that don't have workflows
                        return []
                    }
                }
            }

            var collected: [WorkflowRun] = []
            for try await runs in group {
                collected.append(contentsOf: runs)
            }
            return collected
        }

        // Sort by created date (newest first) and limit
        return allRuns.sorted { $0.createdAt > $1.createdAt }
            .prefix(maxRuns)
            .map { $0 }
    }
}
