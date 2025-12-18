import SwiftUI

struct SavedAccountsView: View {
    @StateObject private var viewModel = SavedAccountsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading saved accounts...")
            } else if viewModel.savedAccounts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No saved accounts")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Save accounts for quick access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(viewModel.savedAccounts) { savedAccount in
                        SavedAccountRow(
                            savedAccount: savedAccount,
                            onDelete: {
                                Task {
                                    await viewModel.deleteSavedAccount(id: savedAccount.id)
                                }
                            },
                            onPay: {
                                viewModel.selectedAccount = savedAccount.pppoeAccount
                            }
                        )
                    }
                }
                .refreshable {
                    await viewModel.loadSavedAccounts()
                }
            }
        }
        .navigationTitle("Saved Accounts")
        .task {
            await viewModel.loadSavedAccounts()
        }
        .sheet(item: $viewModel.selectedAccount) { account in
            PaymentView(account: account)
        }
    }
}

struct SavedAccountRow: View {
    let savedAccount: SavedAccount
    let onDelete: () -> Void
    let onPay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let nickname = savedAccount.nickname {
                        Text(nickname)
                            .font(.headline)
                    }

                    Text(savedAccount.pppoeAccount.customerName)
                        .font(savedAccount.nickname == nil ? .headline : .subheadline)
                        .foregroundColor(savedAccount.nickname == nil ? .primary : .secondary)

                    Text(savedAccount.pppoeAccount.accountNumber)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if savedAccount.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }

                StatusBadge(status: savedAccount.pppoeAccount.status)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expires")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatDate(savedAccount.pppoeAccount.expiryDate))
                        .font(.caption)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Monthly")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("UGX \(savedAccount.pppoeAccount.monthlyAmount.formatted())")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }

            HStack(spacing: 8) {
                Button(action: onPay) {
                    Text("Pay Now")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

@MainActor
class SavedAccountsViewModel: ObservableObject {
    @Published var savedAccounts: [SavedAccount] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAccount: PPPoEAccount?

    func loadSavedAccounts() async {
        isLoading = true
        errorMessage = nil

        do {
            savedAccounts = try await AccountsAPI.shared.getSavedAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deleteSavedAccount(id: String) async {
        do {
            try await AccountsAPI.shared.deleteSavedAccount(id: id)
            await loadSavedAccounts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
