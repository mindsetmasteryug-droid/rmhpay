import SwiftUI

struct PaymentConfirmationView: View {
    let transaction: Transaction
    @ObservedObject var viewModel: PaymentViewModel
    @Environment(\.dismiss) var dismiss
    @State private var pin = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Confirm Payment")
                        .font(.title2.bold())

                    Text("A payment request has been sent to \(transaction.paymentPhone)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)

                VStack(spacing: 16) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("UGX \(transaction.amount.formatted())")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Status")
                        Spacer()
                        Text(transaction.state.displayName)
                            .foregroundColor(statusColor(for: transaction.state))
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(Constants.UI.cornerRadius)

                if viewModel.isLoading {
                    ProgressView("Processing payment...")
                        .padding()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()

                VStack(spacing: 12) {
                    Text("Please approve the payment on your phone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        Task {
                            await viewModel.confirmPayment()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Check Payment Status")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.UI.buttonHeight)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(Constants.UI.cornerRadius)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func statusColor(for state: TransactionState) -> Color {
        switch state {
        case .success: return .green
        case .failed, .timeout: return .red
        case .pendingConfirmation, .pinSent, .paymentInitiated: return .orange
        default: return .secondary
        }
    }
}
