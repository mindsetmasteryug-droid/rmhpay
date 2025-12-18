import Foundation

struct Transaction: Codable, Identifiable {
    let id: String
    let idempotencyKey: String
    let userId: String
    let pppoeAccountId: String
    let amount: Int
    let months: Int
    let paymentMethod: PaymentMethod
    let paymentPhone: String
    let state: TransactionState
    let receiptNumber: String?
    let errorMessage: String?
    let createdAt: Date
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case idempotencyKey = "idempotency_key"
        case userId = "user_id"
        case pppoeAccountId = "pppoe_account_id"
        case amount
        case months
        case paymentMethod = "payment_method"
        case paymentPhone = "payment_phone"
        case state
        case receiptNumber = "receipt_number"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

enum PaymentMethod: String, Codable, CaseIterable {
    case mtnMomo = "mtn_momo"
    case airtelMoney = "airtel_money"
    case card = "card"

    var displayName: String {
        switch self {
        case .mtnMomo: return "MTN Mobile Money"
        case .airtelMoney: return "Airtel Money"
        case .card: return "Card Payment"
        }
    }

    var icon: String {
        switch self {
        case .mtnMomo: return "📱"
        case .airtelMoney: return "💰"
        case .card: return "💳"
        }
    }
}

enum TransactionState: String, Codable {
    case created
    case lookupVerified = "lookup_verified"
    case paymentInitiated = "payment_initiated"
    case pinSent = "pin_sent"
    case pendingConfirmation = "pending_confirmation"
    case success
    case failed
    case timeout
    case reversed

    var displayName: String {
        switch self {
        case .created: return "Created"
        case .lookupVerified: return "Account Verified"
        case .paymentInitiated: return "Payment Initiated"
        case .pinSent: return "PIN Sent"
        case .pendingConfirmation: return "Confirming"
        case .success: return "Success"
        case .failed: return "Failed"
        case .timeout: return "Timeout"
        case .reversed: return "Reversed"
        }
    }

    var isPending: Bool {
        switch self {
        case .paymentInitiated, .pinSent, .pendingConfirmation:
            return true
        default:
            return false
        }
    }

    var isComplete: Bool {
        switch self {
        case .success, .failed, .timeout, .reversed:
            return true
        default:
            return false
        }
    }
}
