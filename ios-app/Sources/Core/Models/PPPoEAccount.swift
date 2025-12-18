import Foundation

struct PPPoEAccount: Codable, Identifiable {
    let id: String
    let accountNumber: String
    let customerName: String
    let phoneNumber: String
    let monthlyAmount: Int
    let expiryDate: Date
    let status: AccountStatus

    enum CodingKeys: String, CodingKey {
        case id
        case accountNumber = "account_number"
        case customerName = "customer_name"
        case phoneNumber = "phone_number"
        case monthlyAmount = "monthly_amount"
        case expiryDate = "expiry_date"
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        accountNumber = try container.decode(String.self, forKey: .accountNumber)
        customerName = try container.decode(String.self, forKey: .customerName)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        monthlyAmount = try container.decode(Int.self, forKey: .monthlyAmount)

        let dateString = try container.decode(String.self, forKey: .expiryDate)
        let formatter = ISO8601DateFormatter()
        expiryDate = formatter.date(from: dateString) ?? Date()

        let statusString = try container.decode(String.self, forKey: .status)
        status = AccountStatus(rawValue: statusString) ?? .disabled
    }

    var isExpired: Bool {
        expiryDate < Date()
    }

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    }
}

enum AccountStatus: String, Codable {
    case active
    case expired
    case suspended
    case disabled

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .active: return "green"
        case .expired: return "red"
        case .suspended: return "orange"
        case .disabled: return "gray"
        }
    }
}

struct SavedAccount: Codable, Identifiable {
    let id: String
    let userId: String
    let pppoeAccountId: String
    let nickname: String?
    let customPhone: String?
    let isFavorite: Bool
    let createdAt: Date
    let pppoeAccount: PPPoEAccount

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case pppoeAccountId = "pppoe_account_id"
        case nickname
        case customPhone = "custom_phone"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case pppoeAccount = "pppoe_accounts"
    }
}
