class DevicesViewModel: ObservableObject {
    @Published var selectedDevice: Device?
    @Published var currentDevice: Device?
    @Published var otherDevices: [Device] = []
    @Published var isLoading = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    private let authService = AuthService()
    private var currentDeviceId = (KeyStorage.shared.readDeviceId() ?? "").toInt

    init() {
        loadDevices()
    }

    func loadDevices() {
        isLoading = true
        DeviceService.shared.fetchDevices { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let devices):
                    self?.currentDevice = devices.first { $0.id == self?.currentDeviceId }
                    self?.otherDevices = devices.filter { $0.id != self?.currentDeviceId }
                // debugLog("currentDevice: \(String(describing: self?.currentDevice))")
                // debugLog("otherDevices: \(String(describing: self?.otherDevices))")
                case .failure(let error):
                    debugLog("fetchDevices error: \(result)")
                    self?.errorMessage = error.content
                }
            }
        }
    }

    func terminateAllOtherSessions() {
        authService.terminateOthers { [weak self] result in
            switch result {
            case .success:
                debugLog("Remote logout successful")
                self?.clearError()
                self?.loadDevices()
            case .failure(let error):
                errorLog(error.content)
                self?.showErrorMessage(error.content)
            }
        }
    }

    func terminate(device: Device) {
        authService.terminateSession(deviceId: device.id) { [weak self] result in
            switch result {
            case .success:
                debugLog("Remote logout successful")
                self?.clearError()
                self?.loadDevices()
            case .failure(let error):
                errorLog(error.content)
                self?.showErrorMessage(error.content)
            }
        }
    }

    private func showErrorMessage(_ msg: String) {
        errorMessage = msg
        showError = true
    }

    func clearError() {
        errorMessage = ""
        showError = false
    }
}
