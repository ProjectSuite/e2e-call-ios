import Foundation

class ContactsAPIService {
    static let shared = ContactsAPIService()
    private init() {}

    func fetchContacts(completion: @escaping (Result<[Contact], APIError>) -> Void) {
        guard let components = URLComponents(string: APIEndpoint.contacts.fullURLString) else {
            completion(.failure(.invalidURL))
            return
        }
        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }
        APIClient.shared.request(url, method: .get) { (result: Result<ContactsResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response.contacts))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchContactById(contactId: String, completion: @escaping (Contact?) -> Void) {
        guard var components = URLComponents(string: APIEndpoint.contacts.fullURLString) else {
            completion(nil)
            return
        }
        components.queryItems = [URLQueryItem(name: "contactId", value: contactId)]
        guard let url = components.url else {
            completion(nil)
            return
        }
        APIClient.shared.request(url, method: .get) { (result: Result<Contact, APIError>) in
            switch result {
            case .success(let response):
                completion(response)
            case .failure:
                completion(nil)
            }
        }
    }

    func toggleFavorite(contactID: UInt64, completion: @escaping (Result<Void, APIError>) -> Void) {
        guard let url = URL(string: "\(APIEndpoint.contact.fullURLString)/\(contactID)/toggle") else {
            completion(.failure(.invalidURL))
            return
        }
        APIClient.shared.request(url, method: .patch, headers: ["Content-Type": "application/json"]) { (result: Result<ToggleFavoriteResponse, APIError>) in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func deleteContact(contactID: UInt64, completion: @escaping (Result<Void, APIError>) -> Void) {
        guard let url = URL(string: "\(APIEndpoint.contact.fullURLString)/\(contactID)") else {
            completion(.failure(.invalidURL))
            return
        }
        APIClient.shared.request(url, method: .delete, headers: ["Content-Type": "application/json"]) { (result: Result<DeleteContactResponse, APIError>) in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Send a friend request to another user
    func sendFriendRequest(to userID: UInt64, completion: @escaping (Result<Void, APIError>) -> Void) {
        guard let url = URL(string: APIEndpoint.friendRequest.fullURLString) else {
            return completion(.failure(.invalidURL))
        }
        let body = ["targetUserId": userID]
        let httpBody: Data
        do {
            httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(.serverError))
            return
        }
        APIClient.shared.request(
            url,
            method: .post,
            body: httpBody,
            headers: ["Content-Type": "application/json"]
        ) { (result: Result<SendFriendRequestResponse, APIError>) in
            switch result {
            case .success:
                completion(.success(()))
            case let .failure(err):
                completion(.failure(err))
            }
        }
    }

    /// Accept a friend request
    func acceptFriendRequest(to userID: UInt64, completion: @escaping (Result<Void, APIError>) -> Void) {
        guard let url = URL(string: APIEndpoint.friendRequestAccept.fullURLString) else {
            return completion(.failure(.invalidURL))
        }

        let body = ["targetUserId": userID]
        let httpBody: Data
        do {
            httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(.serverError))
            return
        }

        APIClient.shared.request(
            url,
            method: .post,
            body: httpBody,
            headers: ["Content-Type": "application/json"]
        ) { (result: Result<EmptyResponse, APIError>) in
            switch result {
            case .success:
                completion(.success(()))
            case let .failure(err):
                completion(.failure(err))
            }
        }
    }

    /// Decline a friend request
    func declineFriendRequest(to userID: UInt64, completion: @escaping (Result<Void, APIError>) -> Void) {
        guard let url = URL(string: APIEndpoint.friendRequestDecline.fullURLString) else {
            return completion(.failure(.invalidURL))
        }

        let body = ["targetUserId": userID]
        let httpBody: Data
        do {
            httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(.serverError))
            return
        }

        APIClient.shared.request(
            url,
            method: .patch,
            body: httpBody,
            headers: ["Content-Type": "application/json"]
        ) { (result: Result<EmptyResponse, APIError>) in
            switch result {
            case .success:
                completion(.success(()))
            case let .failure(err):
                completion(.failure(err))
            }
        }
    }

    /// Send a friend request to another user
    func cancelFriendRequest(to userID: UInt64, completion: @escaping (Result<Void, APIError>) -> Void) {
        guard let url = URL(string: APIEndpoint.friendRequestCancel.fullURLString) else {
            return completion(.failure(.invalidURL))
        }
        let body = ["targetUserId": userID]
        let httpBody: Data
        do {
            httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(.serverError))
            return
        }
        APIClient.shared.request(
            url,
            method: .patch,
            body: httpBody,
            headers: ["Content-Type": "application/json"]
        ) { (result: Result<EmptyResponse, APIError>) in
            switch result {
            case .success:
                completion(.success(()))
            case let .failure(err):
                completion(.failure(err))
            }
        }
    }

    /// Fetch all outgoing friend-requests (users who have requested you)
    func fetchFriendRequestSent(completion: @escaping (Result<[FriendRequest], APIError>) -> Void) {
        guard let url = URL(string: APIEndpoint.friendRequestSent.fullURLString) else {
            return completion(.failure(.invalidURL))
        }
        APIClient.shared.request(
            url,
            method: .get
        ) { (result: Result<GetFriendRequestResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success((response.friendRequests)))
            case let .failure(err):
                completion(.failure(err))
            }
        }
    }

    /// Fetch all incoming friend-requests (users who have requested you)
    func fetchFriendRequestReceive(completion: @escaping (Result<[FriendRequest], APIError>) -> Void) {
        guard let url = URL(string: APIEndpoint.friendRequestReceived.fullURLString) else {
            return completion(.failure(.invalidURL))
        }
        APIClient.shared.request(
            url,
            method: .get
        ) { (result: Result<GetFriendRequestResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success((response.friendRequests)))
            case let .failure(err):
                completion(.failure(err))
            }
        }
    }
}
