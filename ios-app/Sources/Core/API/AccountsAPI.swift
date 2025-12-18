import Foundation

struct AccountLookupResponse: Codable {
    let account: PPPoEAccount
}

struct SavedAccountsResponse: Codable {
    let accounts: [SavedAccount]
    let maxSaved: Int
    let count: Int

    enum CodingKeys: String, CodingKey {
        case accounts
        case maxSaved = "max_saved"
        case count
    }
}

struct SaveAccountRequest: Codable {
    let accountNumber: String
    let nickname: String?
    let customPhone: String?

    enum CodingKeys: String, CodingKey {
        case accountNumber = "account_number"
        case nickname
        case customPhone = "custom_phone"
    }
}

class AccountsAPI {
    static let shared = AccountsAPI()
    private let client = APIClient.shared

    func lookupAccount(accountNumber: String) async throws -> PPPoEAccount {
        let response: AccountLookupResponse = try await client.request(
            endpoint: "/accounts/lookup?account_number=\(accountNumber)"
        )
        return response.account
    }

    func getSavedAccounts() async throws -> [SavedAccount] {
        let response: SavedAccountsResponse = try await client.request(
            endpoint: "/accounts/saved",
            requiresAuth: true
        )
        return response.accounts
    }

    func saveAccount(accountNumber: String, nickname: String?, customPhone: String?) async throws {
        let request = SaveAccountRequest(
            accountNumber: accountNumber,
            nickname: nickname,
            customPhone: customPhone
        )

        let _: APIResponse<[String: String]> = try await client.request(
            endpoint: "/accounts/saved",
            method: "POST",
            body: request,
            requiresAuth: true
        )
    }

    func deleteSavedAccount(id: String) async throws {
        let _: APIResponse<[String: String]> = try await client.request(
            endpoint: "/accounts/saved/\(id)",
            method: "DELETE",
            requiresAuth: true
        )
    }
}
