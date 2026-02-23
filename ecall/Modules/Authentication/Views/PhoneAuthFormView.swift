import SwiftUI

struct PhoneAuthFormView: View {
    @Environment(\.presentationMode) private var presentation
    @StateObject var viewModel: AuthViewModel
    @Binding var isLoading: Bool
    let onNext: () -> Void
    @FocusState private var focusedField: Bool
    @State private var isPhoneAvailable = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Phone icon and description
                VStack(spacing: 16) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)

                    Text(KeyLocalized.your_phone)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)

                    Text(KeyLocalized.phone_confirmation_description)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 20)

                CountryPhoneInputSection(
                    fullPhoneNumber: $viewModel.phoneNumber,
                    onPhoneAvailabilityChanged: { available in
                        isPhoneAvailable = available
                    }
                )
                .padding(.horizontal)

                Button(action: {
                    viewModel.resetState()
                    isLoading = true
                    viewModel.loginApp { success in
                        isLoading = false
                        if success {
                            onNext()
                        }
                    }
                }, label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1)
                        } else {
                            Text(KeyLocalized.next)
                                .font(.system(size: 18, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        !isLoading
                            ? Color.blue
                            : Color.gray.opacity(0.5)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                })
                .disabled(viewModel.phoneNumber.isEmpty || !isPhoneAvailable || isLoading)
                .padding(.horizontal)

                if viewModel.showError {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.vertical, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(KeyLocalized.cancel) {
                        viewModel.clearKeys()
                        viewModel.clearError()
                        presentation.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(KeyLocalized.continue_with_phone)
                        .font(.headline)
                }
            }
            .onAppear {
                focusedField = true
            }
            if isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .logViewName()
    }
}
