import SwiftUI

struct CallHistoryRow: View {
    let call: CallRecord
    @Environment(\.editMode) private var editMode
    @Binding var selection: Set<UInt64>
    var onJoinTap: (() -> Void)?
    var onCallTap: (() -> Void)?
    var isDisabled: Bool = false
    var showButtons: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            let contactName = CallUtils.formatParticipantsDisplayNames(call.availableParticipants)

            // Checkmark for selection
            if editMode?.wrappedValue == .active, let callId = call.id {
                Image(systemName: selection.contains(callId) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selection.contains(callId) ? .blue : .gray)
                    .font(.title2)
            }

            if call.callCategory == .group {
                Image(systemName: "person.2.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.gray)

            } else {
                SmartAvatarView(
                    url: nil,
                    name: contactName,
                    size: 50
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(contactName)
                    .font(.headline)
                    .foregroundColor(call.contactNameColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Image(systemName: call.callIconName)
                        .foregroundColor(call.iconColor)
                    if let callType = call.callType {
                        Text(LocalizedStringKey(callType.rawValue))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(call.formattedDateWithRelativeDay)
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text(call.formattedTime)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Buttons only shown if showButtons is true
                if showButtons {
                    // Join button (for active calls)
                    if call.status == .active && editMode?.wrappedValue != .active {
                        Button(action: {
                            onJoinTap?()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.green)
                                    .frame(width: 50, height: 35)

                                Text(KeyLocalized.join)
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isDisabled)
                        .simultaneousGesture(TapGesture().onEnded { })
                    }

                    // Call button (for non-active calls)
                    if call.status != .active && editMode?.wrappedValue != .active {
                        Button(action: {
                            onCallTap?()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue)
                                    .frame(width: 50, height: 35)
                                (call.callMediaType ?? .defaultCase).icon
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isDisabled)
                        .simultaneousGesture(TapGesture().onEnded { })
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
