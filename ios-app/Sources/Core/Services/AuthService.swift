import Foundation
import Combine

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var currentUser: User?

    private let authAPI = AuthAPI.shared
    private let keychain = KeychainService.shared

    private init() {
        checkAuthStatus()
    }

    func checkAuthStatus() {
        if let token = keychain.getAccessToken(),
           let userData = UserDefaults.standard.data(forKey: Constants.Storage.userKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }

    func sendOTP(phoneNumber: String, purpose: String = "login") async throws {
        try await authAPI.sendOTP(phoneNumber: phoneNumber, purpose: purpose)
    }

    func verifyOTP(phoneNumber: String, code: String, purpose: String = "login") async throws {
        let response = try await authAPI.verifyOTP(phoneNumber: phoneNumber, code: code, purpose: purpose)
        try saveAuthData(response)
    }

    func login(phoneNumber: String, password: String) async throws {
        let response = try await authAPI.login(phoneNumber: phoneNumber, password: password)
        try saveAuthData(response)
    }

    func logout() {
        keychain.deleteAccessToken()
        keychain.deleteRefreshToken()
        UserDefaults.standard.removeObject(forKey: Constants.Storage.userKey)

        currentUser = nil
        isAuthenticated = false
    }

    private func saveAuthData(_ response: AuthResponse) throws {
        keychain.saveAccessToken(response.accessToken)
        keychain.saveRefreshToken(response.refreshToken)

        let userData = try JSONEncoder().encode(response.user)
        UserDefaults.standard.set(userData, forKey: Constants.Storage.userKey)

        currentUser = response.user
        isAuthenticated = true
    }
}
