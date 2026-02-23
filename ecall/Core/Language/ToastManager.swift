import SwiftUI
import UIKit

/// UIWindow that allows touch passthrough (does not block interactions underneath)
final class PassthroughWindow: UIWindow {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Always allow hit-testing in this window; we will decide pass-through in hitTest
        return true
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // When focused: block the background with a scrim (UIKit resolves as normal)
        if ToastManager.shared.blockBackgroundTouches {
            return super.hitTest(point, with: event)
        }
        // When not focused: only allow touches if inside the toast area
        let screenPoint = self.convert(point, to: nil)
        guard ToastManager.shared.isPointInsideAnyToast(screenPoint) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// Container SwiftUI binds directly to ToastManager to render overlay in a separate window
private struct ToastsContainer: View {
    @StateObject private var manager = ToastManager.shared
    var body: some View {
        ToastsView(toasts: $manager.toasts)
            .allowsHitTesting(true)
    }
}

class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var toasts: [Toast] = []
    private let queue = DispatchQueue(label: "toast.manager", qos: .userInitiated)
    private var overlayWindow: UIWindow?

    // Frames of visible toasts in screen (global) coordinates
    @Published private var toastFrames: [String: CGRect] = [:]
    @Published var blockBackgroundTouches: Bool = false

    func info(_ message: String?, position: ToastPosition = .bottom, offset: CGFloat = 100, duration: TimeInterval = 3) {
        guard let message = message else {return}
        show(message, style: .info, position: position, offset: offset, duration: duration)
    }

    func warning(_ message: String?, position: ToastPosition = .bottom, offset: CGFloat = 100, duration: TimeInterval = 3) {
        guard let message = message else {return}
        show(message, style: .warning, position: position, offset: offset, duration: duration)
    }

    func success(_ message: String?, position: ToastPosition = .bottom, offset: CGFloat = 100, duration: TimeInterval = 3) {
        guard let message = message else {return}
        show(message, style: .success, position: position, offset: offset, duration: duration)
    }

    func error(_ message: String?, position: ToastPosition = .bottom, offset: CGFloat = 100, duration: TimeInterval = 3) {
        guard let message = message else {return}
        show(message, style: .error, position: position, offset: offset, duration: duration)
    }

    func error(_ message: APIError?) {
        guard let message = message else {return}
        show(message.content, style: .error)
    }

    func show(_ message: String, style: ToastStyle = .info, position: ToastPosition = .bottom, offset: CGFloat = 15, duration: TimeInterval = 3) {
        let toast = Toast(message: message, style: style, position: position, verticalOffset: offset)

        queue.async {
            DispatchQueue.main.async {
                self.ensureOverlay()
                withAnimation {
                    self.toasts.append(toast)
                }
            }
        }

        // Auto-dismiss after `duration` seconds if positive
        if duration > 0 {
            queue.asyncAfter(deadline: .now() + duration) {
                self.remove(id: toast.id)
            }
        }
    }

    func remove(id: String) {
        queue.async {
            DispatchQueue.main.async {
                withAnimation {
                    self.toasts.removeAll { $0.id == id }
                }
                if self.toasts.isEmpty { self.teardownOverlayIfNeeded() }
            }
        }
    }

    // MARK: - Overlay window management (always-on-top)
    private func ensureOverlay() {
        guard overlayWindow == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        let hosting = UIHostingController(rootView: ToastsContainer())
        hosting.view.backgroundColor = .clear
        window.rootViewController = hosting
        window.isHidden = false
        overlayWindow = window
    }

    private func teardownOverlayIfNeeded() {
        guard let window = overlayWindow, toasts.isEmpty else { return }
        overlayWindow = nil
        window.isHidden = true
    }
}

// MARK: - Hit-test helpers
extension ToastManager {
    func updateToastFrame(id: String, frameInScreen: CGRect) {
        DispatchQueue.main.async {
            self.toastFrames[id] = frameInScreen
        }
    }
    func removeToastFrame(id: String) {
        DispatchQueue.main.async {
            self.toastFrames.removeValue(forKey: id)
        }
    }
    func isPointInsideAnyToast(_ screenPoint: CGPoint) -> Bool {
        // Read without publishing
        let frames = toastFrames
        for (_, frame) in frames { if frame.contains(screenPoint) { return true } }
        return false
    }
}

enum ToastStyle {
    case success, error, warning, info

    var backgroundColor: Color {
        switch self {
        case .success: return Color.green.opacity(0.9)
        case .error: return Color.red.opacity(0.9)
        case .warning: return Color.orange.opacity(0.9)
        case .info: return Color.blue.opacity(0.9)
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

enum ToastPosition {
    case top, center, bottom
}

struct Toast: Identifiable, Equatable {
    private(set) var id: String = UUID().uuidString
    var message: String
    var style: ToastStyle = .info
    var offsetX: CGFloat = 0
    var position: ToastPosition = .bottom
    var verticalOffset: CGFloat = 15

    fileprivate var isDeleting = false
}

extension View {
    @ViewBuilder
    func interactiveToasts(_ toasts: Binding<[Toast]>) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { ToastsView(toasts: toasts) }
    }
}

struct ToastView: View {
    var toast: Toast
    @State private var isRemoving = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.style.icon)
                .foregroundColor(.white)
            Text(toast.message)
                .foregroundColor(.white)
            Spacer()
            Button {
                guard !isRemoving else { return }
                isRemoving = true
                ToastManager.shared.remove(id: toast.id)
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
            .disabled(isRemoving)
        }
        .padding()
        .background(toast.style.backgroundColor)
        .cornerRadius(12)
        .padding(.horizontal)
        .opacity(isRemoving ? 0.5 : 1.0)
    }
}

struct ToastsView: View {
    @Binding var toasts: [Toast]
    @State private var isExpanded: Bool = false

    var body: some View {
        ZStack {
            if isExpanded {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { isExpanded = false }
            }

            // Top group
            groupView(position: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Center group
            groupView(position: .center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            // Bottom group
            groupView(position: .bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .animation(.bouncy, value: isExpanded)
        .onChange(of: toasts.isEmpty) { isEmpty in
            if isEmpty {
                isExpanded = false
            }
        }
        .onChange(of: isExpanded) { newValue in
            ToastManager.shared.blockBackgroundTouches = newValue
        }
    }

    @ViewBuilder
    private func groupView(position: ToastPosition) -> some View {
        let positionToasts = toasts.filter { $0.position == position }
        if positionToasts.isEmpty {
            EmptyView()
        } else {
            let layout = isExpanded ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(ZStackLayout())
            layout {
                ForEach(Array(positionToasts.enumerated()), id: \.element.id) { _, toast in
                    if let globalIndex = toasts.firstIndex(where: { $0.id == toast.id }) {
                        ToastView(toast: toast)
                            .offset(x: toast.offsetX)
                            .contentShape(Rectangle())
                            .onTapGesture { isExpanded.toggle() }
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .onAppear {
                                            let frame = proxy.frame(in: .global)
                                            ToastManager.shared.updateToastFrame(id: toast.id, frameInScreen: frame)
                                        }
                                        .onChange(of: proxy.frame(in: .global)) { newFrame in
                                            ToastManager.shared.updateToastFrame(id: toast.id, frameInScreen: newFrame)
                                        }
                                        .onDisappear { ToastManager.shared.removeToastFrame(id: toast.id) }
                                }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if let toastIndex = toasts.firstIndex(where: { $0.id == toast.id }) {
                                            toasts[toastIndex].offsetX = value.translation.width < 0 ? value.translation.width : 0
                                        }
                                    }
                                    .onEnded { value in
                                        let xOffset = value.translation.width + (value.velocity.width / 2)
                                        if -xOffset > 200 {
                                            removeToast(id: toast.id)
                                        } else {
                                            withAnimation {
                                                if let toastIndex = toasts.firstIndex(where: { $0.id == toast.id }) {
                                                    toasts[toastIndex].offsetX = 0
                                                }
                                            }
                                        }
                                    }
                            )
                            .scaleEffect(isExpanded ? 1 : scale(globalIndex), anchor: position == .top ? .top : (position == .center ? .center : .bottom))
                            .offset(y: isExpanded ? 0 : offsetY(globalIndex, position: position))
                            .zIndex(toast.isDeleting ? 1000 : 0)
                            .frame(maxWidth: .infinity)
                            .transition(
                                .asymmetric(
                                    insertion: .offset(y: position == .top ? -100 : (position == .center ? 0 : 100)),
                                    removal: .move(edge: .leading)
                                )
                            )
                    }
                }
            }
            .padding(.top, position == .top ? (positionToasts.first?.verticalOffset ?? 0) : 0)
            .padding(.bottom, position == .bottom ? (positionToasts.first?.verticalOffset ?? 0) : 0)
            .offset(y: position == .center ? (positionToasts.first?.verticalOffset ?? 0) : 0)
        }
    }

    private func removeToast(id: String) {
        withAnimation(.bouncy) {
            toasts.removeAll { $0.id == id }
        }
    }

    nonisolated func offsetY(_ index: Int, position: ToastPosition = .bottom) -> CGFloat {
        let offset = min(CGFloat(index) * 15, 30)
        switch position {
        case .top:
            return offset
        case .center:
            return 0
        case .bottom:
            return -offset
        }
    }

    nonisolated func scale(_ index: Int) -> CGFloat {
        let scale = min(CGFloat(index) * 0.1, 1)
        return 1 - scale
    }
}
