import SwiftUI

struct EmailAuthFormView: View {
    @Environment(\.presentationMode) private var presentation
    @StateObject var viewModel: AuthViewModel
    @Binding var isLoading: Bool
    let onNext: () -> Void
    @FocusState private var focusedField: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon + description
                VStack(spacing: 16) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)

                    Text(KeyLocalized.your_email)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)

                    Text(KeyLocalized.email_confirmation_description)
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    TextField(KeyLocalized.enter_email, text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField)
                        .textFieldStyle(LargeTextFieldStyle())
                        .padding(.horizontal)
                }

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
                        viewModel.email.isValidEmail
                            && !isLoading
                            ? Color.blue
                            : Color.gray.opacity(0.5)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                })
                .disabled(viewModel.email.isEmpty || isLoading)
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
                    Text(KeyLocalized.continue_with_email)
                        .font(.headline)
                }
            }
            .onAppear { focusedField = true }
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
