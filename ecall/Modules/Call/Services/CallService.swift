import Foundation

class CallService {
    static let shared = CallService()
    private init() {}

    private let callURL = APIEndpoint.calls.fullURL

    // Fetch call history for the current user (paged)
    // Returns list and total from `X-Total-Count` header
    func fetchCallHistory(page: Int = 0, size: Int = AppConfig.PageSize.medium, name: String? = nil, isMissed: Bool = false, completion: @escaping (_ records: [CallRecord], _ total: Int) -> Void) {
        var components = URLComponents(string: APIEndpoint.calls.fullURLString)
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]

        if let name = name, !name.isEmpty {
            queryItems.append(URLQueryItem(name: "displayName", value: name))
        }

        if isMissed {
            queryItems.append(URLQueryItem(name: "isMissed", value: String(isMissed)))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion([], 0)
            return
        }
        APIClient.shared.requestWithHTTPResponse(url, method: .get) { (result: Result<([CallRecord], HTTPURLResponse), APIError>) in
            switch result {
            case .success(let (records, http)):
                let totalString = http.value(forHTTPHeaderField: "X-Total-Count") ?? "0"
                let total = Int(totalString) ?? 0
                completion(records, total)
            case .failure(let error):
                errorLog(error)
                completion([], 0)
            }
        }
    }

    // Fetch call history for the current user
    func fetchCallParticipants(callId: UInt64, completion: @escaping (ParticipantsResponse?) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.participants(id: "\(callId)").fullURLString) else {
            completion(nil)
            return
        }
        guard let url = components.url else {
            completion(nil)
            return
        }
        APIClient.shared.request(url, method: .get) { (result: Result<ParticipantsResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(response)
            case .failure(let error):
                errorLog(error)
                completion(nil)
            }
        }
    }

    // Update partiticipant of the call
    func updateParticipantInCall(id: UInt64, callId: UInt64, userId: UInt64, status: ParticipantStatus? = nil, feedId: UInt64? = nil, isMuted: Bool? = nil, isVideoEnabled: Bool? = nil, completion: @escaping (Participant?) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.participants(id: "\(callId)").fullURLString) else {
            completion(nil)
            return
        }
        guard let url = components.url else {
            completion(nil)
            return
        }

        var body: [String: Any] = [
            "id": id,
            "callId": callId,
            "userId": userId
        ]

        if let data = feedId {
            body["feedId"] = data
        }

        if let data = status {
            body["status"] = data.rawValue
        }

        if let data = isMuted {
            body["isMuted"] = data
        }

        if let data = isVideoEnabled {
            body["isVideoEnabled"] = data
        }

        let httpBody = try? JSONSerialization.data(withJSONObject: body)

        APIClient.shared.request(url, method: .put, body: httpBody) { (result: Result<Participant, APIError>) in
            switch result {
            case .success(let response):
                completion(response)
            case .failure(let error):
                errorLog(error)
                completion(nil)
            }
        }
    }

    // Call the backend API to start a call. This will create a call record and trigger a push/notification to the callee.
    func startCall(calleeId: String, encryptedAESKey: String, isVideo: Bool = false, completion: @escaping (CallRecord?) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.calls.fullURLString) else {
            completion(nil)
            return
        }
        let body = [
            "calleeId": calleeId,
            "encryptedAESKey": encryptedAESKey,
            "isVideo": isVideo
        ] as [String: Any]
        let httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let url = components.url else {
            completion(nil)
            return
        }
        APIClient.shared.request(url, method: .post, body: httpBody) { (result: Result<CallRecord, APIError>) in
            switch result {
            case .success(let response):
                completion(response)
            case .failure(let error):
                errorLog(error)
                completion(nil)
            }
        }
    }

    // Call the backend API to start a call. This will create a call record and trigger a push/notification to the callee.
    func startGroupCall(
        roomId: UInt64,
        calleeIds: [UInt64],
        encryptedAESKeys: [String: String],
        isVideo: Bool = false,
        completion: @escaping (CallRecord?) -> Void
    ) {
        // 1) Build URL
        guard let url = URL(string: APIEndpoint.startCall.fullURLString) else {
            completion(nil)
            return
        }

        // 2) Prepare JSON body
        let body: [String: Any] = [
            "roomId": roomId,
            "calleeIds": calleeIds,
            "encryptedAESKeys": encryptedAESKeys,
            "isVideo": isVideo
        ]

        let httpBody: Data
        do {
            httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            errorLog("JSON serialization error: \(error)")
            completion(nil)
            return
        }

        // 3) Fire the request
        APIClient.shared.request(url, method: .post, body: httpBody) { (result: Result<Call, APIError>) in
            switch result {
            case .success(let record):
                completion(record.callRecord)
                for item in record.offlineCallees ?? [] {
                    ToastManager.shared.error(String(format: KeyLocalized.user_not_available_call, item.displayName.defaultValue))
                }

            case .failure(let errorResult):
                errorLog(errorResult.content)
                if case let .service(error) = errorResult {
                    if error.code == "ErrAllCalleesBusy" { // busy call
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: .callUserBusy,
                                object: nil
                            )
                        }
                    } else {
                        ToastManager.shared.error(errorResult.content)
                    }
                } else {
                    ToastManager.shared.error(KeyLocalized.invalid_data)
                }

                completion(nil)
            }
        }
    }

    // Call the backend API to start a call. This will create a call record and trigger a push/notification to the callee.
    func inviteToGroupCall(
        callId: UInt64,
        roomId: UInt64,
        calleeIds: [UInt64],
        encryptedAESKeys: [String: String],
        isVideo: Bool = false,
        completion: @escaping (Result<InviteResponse, APIError>) -> Void
    ) {
        guard
            let url = URL(string: APIEndpoint.inviteToCall(id: "\(callId)").fullURLString)
        else {
            completion(.failure(.invalidURL))
            return
        }

        let body: [String: Any] = [
            "roomId": roomId,
            "calleeIds": calleeIds,
            "encryptedAESKeys": encryptedAESKeys,
            "isVideo": isVideo
        ]

        let httpBody: Data
        do {
            httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(.invalidData))
            return
        }

        APIClient.shared.request(
            url,
            method: .post,
            body: httpBody
        ) { (result: Result<InviteResponse, APIError>) in
            completion(result)
        }
    }

    // Call the backend API to join a call.
    func joinGroupCall(callId: UInt64, completion: @escaping (CallRecord?) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.joinCall(id: "\(callId)").fullURLString) else {
            completion(nil)
            return
        }
        guard let url = components.url else {
            completion(nil)
            return
        }
        APIClient.shared.request(url, method: .post) { (result: Result<CallRecord, APIError>) in
            switch result {
            case .success(let response):
                completion(response)
            case .failure(let error):
                errorLog(error)
                completion(nil)
            }
        }
    }

    func rejoinGroupCall(callId: UInt64, completion: @escaping (Result<CallRecord, APIError>) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.rejoinCall(id: "\(callId)").fullURLString),
              let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }

        APIClient.shared.request(url, method: .post) { (result: Result<CallRecord, APIError>) in
            completion(result)
        }
    }

    func requestRejoinGroupCall(callId: UInt64, completion: @escaping (Result<Void, APIError>) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.requestRejoinCall(id: "\(callId)").fullURLString),
              let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }

        APIClient.shared.request(url, method: .post) { (result: Result<CallRecord, APIError>) in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func acceptCall(callId: UInt, completion: @escaping (Bool) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.acceptCall.fullURLString) else {
            completion(false)
            return
        }
        let body = ["callId": callId]
        let httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let url = components.url else {
            completion(false)
            return
        }
        APIClient.shared.request(url, method: .post, body: httpBody) { (result: Result<Data, APIError>) in
            switch result {
            case .success:
                completion(true)
            case .failure(let error):
                errorLog(error)
                completion(false)
            }
        }
    }

    func endCall(callId: UInt64?, completion: @escaping (Bool) -> Void) {
        let callIdVal = callId ?? GroupCallSessionManager.shared.currentCallId
        guard let url = URL(string: APIEndpoint.endCall.fullURLString) else {
            completion(false); return
        }
        let body = ["callId": callIdVal]
        let httpBody = try? JSONEncoder().encode(body)
        APIClient.shared.request(url, method: .post, body: httpBody) { (result: Result<EndCallResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(response.success)
            case .failure(let error):
                errorLog(error)
                completion(false)
            }
        }
    }

    func fetchActiveCallState(completion: @escaping (ActiveCallResponse?) -> Void
    ) {
        guard let url = URL(string: APIEndpoint.activeCall.fullURLString) else {
            completion(nil)
            return
        }

        APIClient.shared.request(url, method: .get) { (result: Result<ActiveCallResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(response)
            case .failure(let error):
                errorLog(error)
                completion(nil)
            }
        }
    }

    /// Bulk‐delete multiple calls in one go (optional, if your backend supports it)
    func deleteCalls(ids: [UInt], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: APIEndpoint.calls.fullURLString) else {
            completion(false)
            return
        }
        let body = ["callIds": ids]
        let httpBody = try? JSONSerialization.data(withJSONObject: body)
        APIClient.shared.request(url, method: .delete, body: httpBody) { (result: Result<Data, APIError>) in
            switch result {
            case .success:
                completion(true)
            case .failure(let error):
                errorLog(error)
                completion(false)
            }
        }
    }

    /// Bulk‐delete multiple calls in one go (optional, if your backend supports it)
    func deleteCallHistories(ids: [UInt64], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: APIEndpoint.callHistories.fullURLString) else {
            completion(false)
            return
        }
        let body = ["callIds": ids]
        let httpBody = try? JSONSerialization.data(withJSONObject: body)
        APIClient.shared.request(url, method: .delete, body: httpBody) { (result: Result<DeleteCallHistoriesResponse, APIError>) in
            switch result {
            case .success(let response):
                successLog("deleted \(response.deleted.count) calls")
                completion(true)
            case .failure(let error):
                errorLog(error)
                completion(false)
            }
        }
    }
}

/// Response model for POST /group-calls/:id/invite
struct InviteResponse: Decodable {
    let invitedUsers: [UInt64]
    private enum CodingKeys: String, CodingKey {
        case invitedUsers = "invited_users"
    }
}

/// Response model for DELETE /app/api/calls/histories
struct DeleteCallHistoriesResponse: Decodable {
    let deleted: [UInt]
}

struct ParticipantsResponse: Decodable {
    let participants: [Participant]?
    let currentUser: UserInfo
}

struct ActiveCallResponse: Decodable {
    let active: Bool
    let callId: UInt?
    let state: String?
    let participants: [Participant]?
}

struct EndCallResponse: Decodable {
    let success: Bool
}
