import SwiftUI

extension View {
    func clearButton(text: Binding<String>) -> some View {
        self.overlay(
            HStack {
                Spacer()
                if !text.wrappedValue.isEmpty {
                    Button(action: { text.wrappedValue = "" }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    })
                    .padding(.trailing, 8)
                }
            }
        )
    }
}

// MARK: - Debug
extension View {
    func logViewName(file: String = #file) -> some View {
        self
            .onAppear {
                let name = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
                debugLog("** Appeared View: \(name)")
            }
    }
}

#if DEBUG
func printLog(_ message: String) {
    print(message)
}

func debugLog(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line, separator: String = " ") {
    let filename = (file as NSString).lastPathComponent
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    print("🔹 [\(filename):\(line)] \(function) -> \(message)")
}

func errorLog(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line, separator: String = " ") {
    let filename = (file as NSString).lastPathComponent
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    print("❌ [\(filename):\(line)] \(function) -> \(message)")
}

func successLog(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line, separator: String = " ") {
    let filename = (file as NSString).lastPathComponent
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    print("✅ [\(filename):\(line)] \(function) -> \(message)")
}

func warningLog(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line, separator: String = " ") {
    let filename = (file as NSString).lastPathComponent
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    print("⚠️ [\(filename):\(line)] \(function) -> \(message)")
}

#else
func printLog(_ message: String) {}
func debugLog(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line, separator: String = " ") {}
func errorLog(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line, separator: String = " ") {}
func successLog(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line, separator: String = " ") {}
func warningLog(_ items: Any..., file: String = #file, function: String = #function, line: Int = #line, separator: String = " ") {}
#endif
