import SwiftUI

struct OTPInputView: View {
    @Binding var code: String
    let length: Int = 6

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Hidden field to capture input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .accentColor(.clear)
                .foregroundColor(.clear)
                .disableAutocorrection(true)
                .focused($isFocused)
                .onChange(of: code) { newValue in
                    code = String(newValue.prefix(length))
                        .filter { $0.isNumber }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isFocused = true
                    }
                }

            HStack(spacing: 12) {
                ForEach(0..<length, id: \.self) { index in
                    let digit = index < code.count
                        ? String(code[code.index(code.startIndex, offsetBy: index)])
                        : ""
                    Text(digit)
                        .frame(width: 44, height: 44, alignment: .center)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isFocused ? Color.blue : Color.gray, lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
    }
}
