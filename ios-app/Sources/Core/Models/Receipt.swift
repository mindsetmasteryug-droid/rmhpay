import Foundation

struct Receipt: Codable, Identifiable {
    let id: String
    let transactionId: String
    let receiptNumber: String
    let accountNumber: String
    let customerName: String
    let amount: Int
    let months: Int
    let paymentMethod: String
    let paymentPhone: String
    let oldExpiry: Date
    let newExpiry: Date
    let issuedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case transactionId = "transaction_id"
        case receiptNumber = "receipt_number"
        case accountNumber = "account_number"
        case customerName = "customer_name"
        case amount
        case months
        case paymentMethod = "payment_method"
        case paymentPhone = "payment_phone"
        case oldExpiry = "old_expiry"
        case newExpiry = "new_expiry"
        case issuedAt = "issued_at"
    }

    var formattedText: String {
        """
        RMH PAY RECEIPT
        ================

        Receipt #: \(receiptNumber)
        Date: \(formatDate(issuedAt))

        ACCOUNT DETAILS
        ---------------
        Account: \(accountNumber)
        Customer: \(customerName)

        PAYMENT DETAILS
        ---------------
        Amount: UGX \(amount.formatted())
        Months: \(months)
        Method: \(paymentMethod.uppercased())
        Phone: \(paymentPhone)

        SUBSCRIPTION
        ------------
        Previous Expiry: \(formatDate(oldExpiry))
        New Expiry: \(formatDate(newExpiry))

        Thank you for your payment!
        """
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
