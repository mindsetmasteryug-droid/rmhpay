import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("Payment Successful!")
                            .font(.title2.bold())

                        Text(receipt.receiptNumber)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)

                    VStack(spacing: 0) {
                        ReceiptDetailRow(
                            label: "Account",
                            value: receipt.accountNumber,
                            isFirst: true
                        )

                        ReceiptDetailRow(
                            label: "Customer",
                            value: receipt.customerName
                        )

                        ReceiptDetailRow(
                            label: "Amount",
                            value: "UGX \(receipt.amount.formatted())"
                        )

                        ReceiptDetailRow(
                            label: "Months",
                            value: "\(receipt.months)"
                        )

                        ReceiptDetailRow(
                            label: "Payment Method",
                            value: receipt.paymentMethod.uppercased()
                        )

                        ReceiptDetailRow(
                            label: "New Expiry",
                            value: formatDate(receipt.newExpiry)
                        )

                        ReceiptDetailRow(
                            label: "Date",
                            value: formatDate(receipt.issuedAt),
                            isLast: true
                        )
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(Constants.UI.cornerRadius)

                    Button(action: shareReceipt) {
                        Label("Share Receipt", systemImage: "square.and.arrow.up")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.UI.buttonHeight)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(Constants.UI.cornerRadius)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func shareReceipt() {
        let activityVC = UIActivityViewController(
            activityItems: [receipt.formattedText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct ReceiptDetailRow: View {
    let label: String
    let value: String
    var isFirst: Bool = false
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(value)
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .padding()

            if !isLast {
                Divider()
                    .padding(.leading)
            }
        }
    }
}
