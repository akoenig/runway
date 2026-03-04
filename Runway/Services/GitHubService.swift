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

    func validateToken() async throws -> GitHubUser {
        let request = try createRequest(path: "/user")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(GitHubUser.self, from: data)
        } catch {
            // Log the actual response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode user response: \(jsonString)")
            }
            throw GitHubAPIError.decodingError(error)
        }
    }

    func fetchUserRepos(perPage: Int = 10) async throws -> [Repository] {
        let request = try createRequest(path: "/user/repos?sort=updated&per_page=\(perPage)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode([Repository].self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode repos response: \(jsonString)")
            }
            throw GitHubAPIError.decodingError(error)
        }
    }

    func fetchWorkflowRuns(for repo: Repository, perPage: Int = 5) async throws -> [WorkflowRun] {
        let ownerLogin = repo.owner?.login ?? "unknown"
        let request = try createRequest(path: "/repos/\(ownerLogin)/\(repo.name)/actions/runs?per_page=\(perPage)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Handle ISO8601 dates with or without fractional seconds.
            // Use two separate formatter instances to avoid mutation bugs —
            // a single formatter whose formatOptions is changed inside the closure
            // permanently loses the fractional-seconds capability after the first
            // date string that lacks them.
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

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
            }
            
            let runsResponse = try decoder.decode(WorkflowRunsResponse.self, from: data)
            return runsResponse.workflowRuns
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode workflow runs response: \(jsonString)")
            }
            throw GitHubAPIError.decodingError(error)
        }
    }

    func fetchSingleWorkflowRun(runId: Int, repo: Repository) async throws -> WorkflowRun {
        let owner = repo.owner?.login ?? "unknown"
        let request = try createRequest(
            path: "/repos/\(owner)/\(repo.name)/actions/runs/\(runId)"
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let withoutFractional = ISO8601DateFormatter()
            withoutFractional.formatOptions = [.withInternetDateTime]

            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                if let date = withFractional.date(from: dateString) { return date }
                if let date = withoutFractional.date(from: dateString) { return date }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date: \(dateString)"
                )
            }

            return try decoder.decode(WorkflowRun.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode workflow run response: \(jsonString)")
            }
            throw GitHubAPIError.decodingError(error)
        }
    }

    func fetchJobs(runId: Int, repo: Repository) async throws -> [WorkflowJob] {
        let owner = repo.owner?.login ?? "unknown"
        let request = try createRequest(
            path: "/repos/\(owner)/\(repo.name)/actions/runs/\(runId)/jobs?per_page=100"
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8)
            throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let withFractional = ISO8601DateFormatter()
                withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let withoutFractional = ISO8601DateFormatter()
                withoutFractional.formatOptions = [.withInternetDateTime]
                if let date = withFractional.date(from: dateString) { return date }
                if let date = withoutFractional.date(from: dateString) { return date }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date: \(dateString)"
                )
            }
            let jobsResponse = try decoder.decode(WorkflowJobsResponse.self, from: data)
            return jobsResponse.jobs
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }

    func fetchJobLogs(jobId: Int, repo: Repository) async throws -> [LogLine] {
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
        return GitHubService.parseLogLines(raw)
    }

    /// Parse raw GitHub Actions log text into structured `LogLine` values.
    /// Each `##[group]` marker starts a new step section; `stepNumber` increments
    /// with each group so callers can filter lines per step by matching
    /// `LogLine.stepNumber` to `WorkflowStep.number`.
    static func parseLogLines(_ raw: String) -> [LogLine] {
        // Regex to strip the leading ISO8601 timestamp: "2024-01-15T10:23:45.1234567Z "
        let timestampPattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z "#
        let timestampRegex = try? NSRegularExpression(pattern: timestampPattern)

        // ANSI escape code pattern
        let ansiPattern = #"\x1B\[[0-9;]*[mGKHF]"#
        let ansiRegex = try? NSRegularExpression(pattern: ansiPattern)

        var lines: [LogLine] = []
        var currentStep = 1

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

            // Each ##[group] starts a new step section
            if line.hasPrefix("##[group]") {
                currentStep += 1
                // Skip the bare group header line itself (it duplicates the step name)
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

    func fetchWorkflowRuns(forSelectedRepos selectedRepoNames: [String], maxRuns: Int = 10) async throws -> [WorkflowRun] {
        // First, get user's repos
        let repos = try await fetchUserRepos(perPage: 100)
        
        // Filter to only selected repos
        let selectedRepos = repos.filter { selectedRepoNames.contains($0.displayFullName) }
        
        // Then fetch workflow runs for each selected repo
        var allRuns: [WorkflowRun] = []
        
        for repo in selectedRepos {
            do {
                let runs = try await fetchWorkflowRuns(for: repo, perPage: 3)
                allRuns.append(contentsOf: runs)
            } catch {
                // Skip repos that don't have workflows
                continue
            }
        }
        
        // Sort by created date (newest first) and limit
        allRuns.sort { $0.createdAt > $1.createdAt }
        return Array(allRuns.prefix(maxRuns))
    }
}
