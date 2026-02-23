class DeviceService {
    static let shared = DeviceService()
    private init() {}

    func fetchDevices(completion: @escaping (Result<[Device], APIError>) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.devices.fullURLString) else {
            completion(.failure(.invalidURL))
            return
        }
        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }
        APIClient.shared.request(url, method: .get) { (result: Result<DevicesResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response.devices))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
