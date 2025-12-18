import Foundation

struct User: Codable, Identifiable {
    let id: String
    let phoneNumber: String
    let email: String?
    let fullName: String?
    let isVerified: Bool
    let isAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber = "phone_number"
        case email
        case fullName = "full_name"
        case isVerified = "is_verified"
        case isAdmin = "is_admin"
    }
}

struct AuthResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
