import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)

                            Text("RMH PAY")
                                .font(.system(size: 36, weight: .bold))

                            Text("Pay your internet subscription")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)

                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone Number")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Text("+256")
                                        .foregroundColor(.primary)
                                        .padding(.leading, 16)

                                    TextField("700000000", text: $viewModel.phoneNumber)
                                        .keyboardType(.numberPad)
                                        .textContentType(.telephoneNumber)
                                        .padding(.vertical, 16)
                                }
                                .background(Color(.systemGray6))
                                .cornerRadius(Constants.UI.cornerRadius)
                            }

                            Button(action: {
                                Task {
                                    await viewModel.sendOTP()
                                }
                            }) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Send OTP")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: Constants.UI.buttonHeight)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(Constants.UI.cornerRadius)
                            .disabled(viewModel.isLoading || viewModel.phoneNumber.count != 9)
                        }
                        .padding(.horizontal, 24)

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.showOTPView) {
                OTPView(phoneNumber: viewModel.fullPhoneNumber, viewModel: viewModel)
            }
        }
    }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published var otpCode = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showOTPView = false

    var fullPhoneNumber: String {
        "+256\(phoneNumber)"
    }

    func sendOTP() async {
        errorMessage = nil
        isLoading = true

        do {
            try await AuthService.shared.sendOTP(phoneNumber: fullPhoneNumber)
            showOTPView = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func verifyOTP() async {
        errorMessage = nil
        isLoading = true

        do {
            try await AuthService.shared.verifyOTP(phoneNumber: fullPhoneNumber, code: otpCode)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
