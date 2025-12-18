import Foundation

struct SendOTPRequest: Codable {
    let phoneNumber: String
    let purpose: String

    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case purpose
    }
}

struct VerifyOTPRequest: Codable {
    let phoneNumber: String
    let code: String
    let purpose: String
    let deviceId: String
    let deviceName: String?

    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case code
        case purpose
        case deviceId = "device_id"
        case deviceName = "device_name"
    }
}

struct LoginRequest: Codable {
    let phoneNumber: String
    let password: String
    let deviceId: String
    let deviceName: String?

    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case password
        case deviceId = "device_id"
        case deviceName = "device_name"
    }
}

class AuthAPI {
    static let shared = AuthAPI()
    private let client = APIClient.shared

    func sendOTP(phoneNumber: String, purpose: String) async throws {
        let request = SendOTPRequest(phoneNumber: phoneNumber, purpose: purpose)
        let _: APIResponse<[String: String]> = try await client.request(
            endpoint: "/auth/send-otp",
            method: "POST",
            body: request
        )
    }

    func verifyOTP(phoneNumber: String, code: String, purpose: String) async throws -> AuthResponse {
        let deviceId = await getDeviceId()
        let deviceName = await getDeviceName()

        let request = VerifyOTPRequest(
            phoneNumber: phoneNumber,
            code: code,
            purpose: purpose,
            deviceId: deviceId,
            deviceName: deviceName
        )

        return try await client.request(
            endpoint: "/auth/verify-otp",
            method: "POST",
            body: request
        )
    }

    func login(phoneNumber: String, password: String) async throws -> AuthResponse {
        let deviceId = await getDeviceId()
        let deviceName = await getDeviceName()

        let request = LoginRequest(
            phoneNumber: phoneNumber,
            password: password,
            deviceId: deviceId,
            deviceName: deviceName
        )

        return try await client.request(
            endpoint: "/auth/login",
            method: "POST",
            body: request
        )
    }

    private func getDeviceId() async -> String {
        if let saved = UserDefaults.standard.string(forKey: Constants.Storage.deviceIdKey) {
            return saved
        }

        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: Constants.Storage.deviceIdKey)
        return newId
    }

    private func getDeviceName() async -> String {
        await UIDevice.current.name
    }
}
