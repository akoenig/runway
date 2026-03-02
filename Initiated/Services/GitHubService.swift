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

final class GitHubService {
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
            throw GitHubAPIError.decodingError(error)
        }
    }

    func fetchWorkflowRuns(actor: String, perPage: Int = 10) async throws -> [WorkflowRun] {
        let encodedActor = actor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? actor
        let path = "/users/\(encodedActor)/actions/runs?per_page=\(perPage)"

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
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Handle ISO8601 dates with or without fractional seconds
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                // Try without fractional seconds
                dateFormatter.formatOptions = [.withInternetDateTime]
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
            }
            
            let runsResponse = try decoder.decode(WorkflowRunsResponse.self, from: data)
            return runsResponse.workflowRuns
        } catch {
            throw GitHubAPIError.decodingError(error)
        }
    }
}
