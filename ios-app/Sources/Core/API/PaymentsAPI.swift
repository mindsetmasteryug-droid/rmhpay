import Foundation

struct InitiatePaymentRequest: Codable {
    let accountNumber: String
    let months: Int
    let paymentMethod: String
    let paymentPhone: String
    let idempotencyKey: String

    enum CodingKeys: String, CodingKey {
        case accountNumber = "account_number"
        case months
        case paymentMethod = "payment_method"
        case paymentPhone = "payment_phone"
        case idempotencyKey = "idempotency_key"
    }
}

struct PaymentResponse: Codable {
    let transaction: Transaction
    let message: String?
    let receipt: Receipt?
}

struct ConfirmPaymentRequest: Codable {
    let transactionId: String
    let pin: String?

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case pin
    }
}

struct TransactionHistoryResponse: Codable {
    let transactions: [Transaction]
}

class PaymentsAPI {
    static let shared = PaymentsAPI()
    private let client = APIClient.shared

    func initiatePayment(
        accountNumber: String,
        months: Int,
        paymentMethod: PaymentMethod,
        paymentPhone: String
    ) async throws -> Transaction {
        let idempotencyKey = UUID().uuidString

        let request = InitiatePaymentRequest(
            accountNumber: accountNumber,
            months: months,
            paymentMethod: paymentMethod.rawValue,
            paymentPhone: paymentPhone,
            idempotencyKey: idempotencyKey
        )

        let response: PaymentResponse = try await client.request(
            endpoint: "/payments/initiate",
            method: "POST",
            body: request,
            requiresAuth: true
        )

        return response.transaction
    }

    func confirmPayment(transactionId: String, pin: String? = nil) async throws -> (Transaction, Receipt?) {
        let request = ConfirmPaymentRequest(transactionId: transactionId, pin: pin)

        let response: PaymentResponse = try await client.request(
            endpoint: "/payments/confirm",
            method: "POST",
            body: request,
            requiresAuth: true
        )

        return (response.transaction, response.receipt)
    }

    func getTransaction(id: String) async throws -> Transaction {
        let response: PaymentResponse = try await client.request(
            endpoint: "/payments/transaction/\(id)",
            requiresAuth: true
        )
        return response.transaction
    }

    func getTransactionHistory(limit: Int = 50) async throws -> [Transaction] {
        let response: TransactionHistoryResponse = try await client.request(
            endpoint: "/payments/history?limit=\(limit)",
            requiresAuth: true
        )
        return response.transactions
    }
}
