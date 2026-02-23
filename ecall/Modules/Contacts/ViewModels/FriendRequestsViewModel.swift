import Foundation

class FriendRequestsViewModel: ObservableObject {
    @Published var received: [FriendRequest] = []
    @Published var sent: [FriendRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    init() {
        loadRequests()
    }

    /// Fetch both incoming and outgoing friend requests
    func loadRequests() {
        isLoading = true
        errorMessage = ""
        let group = DispatchGroup()

        group.enter()
        ContactsAPIService.shared.fetchFriendRequestReceive { [weak self] res in
            DispatchQueue.main.async {
                switch res {
                case .success(let list): self?.received = list
                case .failure(let err):  self?.errorMessage = err.content
                }
                group.leave()
            }
        }

        group.enter()
        ContactsAPIService.shared.fetchFriendRequestSent { [weak self] res in
            DispatchQueue.main.async {
                switch res {
                case .success(let list): self?.sent = list
                case .failure(let err):  self?.errorMessage = err.content
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.isLoading = false
        }
    }

    /// Accept and reload
    func accept(_ req: FriendRequest) {
        isLoading = true
        ContactsAPIService.shared.acceptFriendRequest(to: req.senderId) { [weak self] _ in
            DispatchQueue.main.async { self?.loadRequests() }
        }
    }

    /// Decline and reload
    func decline(_ req: FriendRequest) {
        isLoading = true
        ContactsAPIService.shared.declineFriendRequest(to: req.senderId) { [weak self] _ in
            DispatchQueue.main.async { self?.loadRequests() }
        }
    }

    /// Cancel outgoing and reload
    func cancel(_ req: FriendRequest) {
        isLoading = true
        ContactsAPIService.shared.cancelFriendRequest(to: req.receiverId) { [weak self] _ in
            DispatchQueue.main.async { self?.loadRequests() }
        }
    }
}
