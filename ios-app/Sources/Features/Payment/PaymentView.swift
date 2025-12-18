import SwiftUI

struct PaymentView: View {
    let account: PPPoEAccount
    @StateObject private var viewModel = PaymentViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Payment Details")
                            .font(.headline)

                        VStack(spacing: 12) {
                            HStack {
                                Text("Account")
                                Spacer()
                                Text(account.accountNumber)
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Text("Customer")
                                Spacer()
                                Text(account.customerName)
                                    .fontWeight(.semibold)
                            }

                            Divider()

                            HStack {
                                Text("Monthly Rate")
                                Spacer()
                                Text("UGX \(account.monthlyAmount.formatted())")
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(Constants.UI.cornerRadius)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Number of Months")
                            .font(.headline)

                        Picker("Months", selection: $viewModel.selectedMonths) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month) month\(month == 1 ? "" : "s")").tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .background(Color(.systemGray6))
                        .cornerRadius(Constants.UI.cornerRadius)

                        HStack {
                            Text("Total Amount")
                                .font(.headline)
                            Spacer()
                            Text("UGX \((account.monthlyAmount * viewModel.selectedMonths).formatted())")
                                .font(.title2.bold())
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(Constants.UI.cornerRadius)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Payment Method")
                            .font(.headline)

                        ForEach(PaymentMethod.allCases, id: \.self) { method in
                            PaymentMethodButton(
                                method: method,
                                isSelected: viewModel.selectedMethod == method
                            ) {
                                viewModel.selectedMethod = method
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Payment Phone Number")
                            .font(.headline)

                        HStack {
                            Text("+256")
                                .foregroundColor(.primary)
                                .padding(.leading)

                            TextField("700000000", text: $viewModel.paymentPhone)
                                .keyboardType(.numberPad)
                                .textContentType(.telephoneNumber)
                                .padding(.vertical)
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(Constants.UI.cornerRadius)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }

                    Button(action: {
                        Task {
                            await viewModel.initiatePayment(account: account)
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Pay UGX \((account.monthlyAmount * viewModel.selectedMonths).formatted())")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.UI.buttonHeight)
                    .background(viewModel.canInitiatePayment ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(Constants.UI.cornerRadius)
                    .disabled(!viewModel.canInitiatePayment || viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("Pay Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showConfirmation) {
                if let transaction = viewModel.currentTransaction {
                    PaymentConfirmationView(transaction: transaction, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $viewModel.showReceipt) {
                if let receipt = viewModel.receipt {
                    ReceiptDetailView(receipt: receipt)
                }
            }
        }
    }
}

struct PaymentMethodButton: View {
    let method: PaymentMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(method.icon)
                    .font(.title2)

                Text(method.displayName)
                    .font(.body)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(Constants.UI.cornerRadius)
        }
        .foregroundColor(.primary)
    }
}

@MainActor
class PaymentViewModel: ObservableObject {
    @Published var selectedMonths = 1
    @Published var selectedMethod: PaymentMethod = .mtnMomo
    @Published var paymentPhone = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentTransaction: Transaction?
    @Published var showConfirmation = false
    @Published var showReceipt = false
    @Published var receipt: Receipt?

    var canInitiatePayment: Bool {
        paymentPhone.count == 9
    }

    func initiatePayment(account: PPPoEAccount) async {
        errorMessage = nil
        isLoading = true

        let fullPhone = "+256\(paymentPhone)"

        do {
            let transaction = try await PaymentsAPI.shared.initiatePayment(
                accountNumber: account.accountNumber,
                months: selectedMonths,
                paymentMethod: selectedMethod,
                paymentPhone: fullPhone
            )

            currentTransaction = transaction

            if transaction.state == .pinSent || transaction.state == .pendingConfirmation {
                showConfirmation = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func confirmPayment(pin: String? = nil) async {
        guard let transactionId = currentTransaction?.id else { return }

        errorMessage = nil
        isLoading = true

        do {
            let (transaction, receipt) = try await PaymentsAPI.shared.confirmPayment(
                transactionId: transactionId,
                pin: pin
            )

            currentTransaction = transaction

            if transaction.state == .success, let receipt = receipt {
                self.receipt = receipt
                showConfirmation = false
                showReceipt = true
            } else if transaction.state == .failed {
                errorMessage = transaction.errorMessage ?? "Payment failed"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
