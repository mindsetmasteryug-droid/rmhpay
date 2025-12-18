import SwiftUI

struct OTPView: View {
    let phoneNumber: String
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Enter OTP Code")
                        .font(.title2.bold())

                    Text("We sent a code to \(phoneNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)

                VStack(spacing: 24) {
                    TextField("000000", text: $viewModel.otpCode)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32, weight: .semibold))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(Constants.UI.cornerRadius)
                        .focused($isInputFocused)
                        .onChange(of: viewModel.otpCode) { newValue in
                            if newValue.count > 6 {
                                viewModel.otpCode = String(newValue.prefix(6))
                            }
                        }

                    Button(action: {
                        Task {
                            await viewModel.verifyOTP()
                        }
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Verify")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Constants.UI.buttonHeight)
                    .background(viewModel.otpCode.count == 6 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(Constants.UI.cornerRadius)
                    .disabled(viewModel.isLoading || viewModel.otpCode.count != 6)

                    Button("Resend Code") {
                        Task {
                            await viewModel.sendOTP()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 24)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
    }
}
