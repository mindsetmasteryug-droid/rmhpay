import SwiftUI

struct AccountDetailsView: View {
    let account: PPPoEAccount
    @State private var showPaymentView = false
    @State private var showSaveDialog = false
    @State private var nickname = ""

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.customerName)
                            .font(.title2.bold())

                        Text(account.accountNumber)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    StatusBadge(status: account.status)
                }

                Divider()

                HStack {
                    DetailRow(title: "Phone", value: account.phoneNumber)
                    Spacer()
                }

                HStack {
                    DetailRow(title: "Monthly Amount", value: "UGX \(account.monthlyAmount.formatted())")
                    Spacer()
                }

                HStack {
                    DetailRow(title: "Expires", value: formatDate(account.expiryDate))
                    Spacer()
                }

                if account.daysUntilExpiry < 7 && account.daysUntilExpiry >= 0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Expires in \(account.daysUntilExpiry) day\(account.daysUntilExpiry == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } else if account.isExpired {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Account expired")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(Constants.UI.cornerRadius)
            .padding(.horizontal)

            HStack(spacing: 12) {
                Button(action: {
                    showSaveDialog = true
                }) {
                    Label("Save", systemImage: "bookmark")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(Constants.UI.cornerRadius)

                Button(action: {
                    showPaymentView = true
                }) {
                    Label("Pay Now", systemImage: "creditcard.fill")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(Constants.UI.cornerRadius)
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showPaymentView) {
            PaymentView(account: account)
        }
        .alert("Save Account", isPresented: $showSaveDialog) {
            TextField("Nickname (optional)", text: $nickname)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Task {
                    await saveAccount()
                }
            }
        } message: {
            Text("Add this account to your saved accounts for quick access.")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func saveAccount() async {
        do {
            try await AccountsAPI.shared.saveAccount(
                accountNumber: account.accountNumber,
                nickname: nickname.isEmpty ? nil : nickname,
                customPhone: nil
            )
        } catch {
            print("Failed to save account: \(error)")
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

struct StatusBadge: View {
    let status: AccountStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .active: return .green
        case .expired: return .red
        case .suspended: return .orange
        case .disabled: return .gray
        }
    }
}
