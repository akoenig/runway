import Foundation

struct GitHubUser: Codable, Equatable {
    let id: Int
    let login: String
    let name: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, login, name
        case avatarUrl = "avatar_url"
    }
}
