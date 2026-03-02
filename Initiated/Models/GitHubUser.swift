import Foundation

// NOTE: No explicit CodingKeys — all decoders use .convertFromSnakeCase,
// which handles avatar_url → avatarUrl automatically.
struct GitHubUser: Codable, Equatable {
    let id: Int
    let login: String
    let name: String?
    let avatarUrl: String?
}
