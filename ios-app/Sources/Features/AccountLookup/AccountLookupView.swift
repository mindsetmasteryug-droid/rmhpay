import SwiftUI

struct AccountLookupView: View {
    @StateObject private var viewModel = AccountLookupViewModel()
    @State private var accountNumber = ""

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Account Number")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("LUB0001 or RMH0001", text: $accountNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal)

            Button(action: {
                Task {
                    await viewModel.lookupAccount(accountNumber: accountNumber)
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Look Up")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Constants.UI.buttonHeight)
            .background(accountNumber.isEmpty ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(Constants.UI.cornerRadius)
            .disabled(viewModel.isLoading || accountNumber.isEmpty)
            .padding(.horizontal)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            if let account = viewModel.account {
                AccountDetailsView(account: account)
            }

            Spacer()
        }
        .padding(.top, 20)
        .navigationTitle("Account Lookup")
    }
}

@MainActor
class AccountLookupViewModel: ObservableObject {
    @Published var account: PPPoEAccount?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func lookupAccount(accountNumber: String) async {
        errorMessage = nil
        isLoading = true
        account = nil

        do {
            account = try await AccountsAPI.shared.lookupAccount(accountNumber: accountNumber.trimmingCharacters(in: .whitespaces))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
