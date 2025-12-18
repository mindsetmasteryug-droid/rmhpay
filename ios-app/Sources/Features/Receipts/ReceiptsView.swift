import SwiftUI

struct ReceiptsView: View {
    @StateObject private var viewModel = ReceiptsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading receipts...")
            } else if viewModel.transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No receipts yet")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Your payment receipts will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(viewModel.transactions) { transaction in
                        if transaction.state == .success {
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadTransactions()
                }
            }
        }
        .navigationTitle("Receipts")
        .task {
            await viewModel.loadTransactions()
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let receiptNumber = transaction.receiptNumber {
                        Text(receiptNumber)
                            .font(.headline)
                    }

                    Text(formatDate(transaction.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("UGX \(transaction.amount.formatted())")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            HStack {
                Text("\(transaction.months) month\(transaction.months == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(transaction.paymentMethod.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@MainActor
class ReceiptsViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadTransactions() async {
        isLoading = true
        errorMessage = nil

        do {
            transactions = try await PaymentsAPI.shared.getTransactionHistory()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
