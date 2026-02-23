import SwiftUI

struct CallBusyModeView: View {
    let name: String
    let isRecallDisabled: Bool
    let recallCountdown: Int
    let onDismiss: () -> Void
    let onRecall: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.9)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                // Top: Name + state
                VStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 80)
                    Text(KeyLocalized.user_busy)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                // Bottom: buttons + labels
                HStack(spacing: 64) {
                    VStack(spacing: 12) {
                        Button(action: onDismiss) {
                            ZStack {
                                Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                                    .frame(width: 88, height: 88)
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        Text(KeyLocalized.cancel)
                            .foregroundColor(.white)
                            .font(.body)
                    }

                    VStack(spacing: 12) {
                        Button(action: onRecall) {
                            ZStack {
                                Circle()
                                    .fill(isRecallDisabled ? Color.gray : Color.green)
                                    .frame(width: 88, height: 88)
                                if isRecallDisabled {
                                    Text("\(recallCountdown)")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    CallMediaType.audio.icon
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isRecallDisabled)
                        Text(isRecallDisabled ? "\(recallCountdown)s" : KeyLocalized.call_back)
                            .foregroundColor(.white)
                            .font(.body)
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }
}
