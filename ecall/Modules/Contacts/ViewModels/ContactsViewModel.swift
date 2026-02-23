import SwiftUI

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    init(service: ContactsService = ContactsService()) {
        loadContacts()
    }

    var favoriteContactsFiltered: [Contact] {
        contacts.filter {
            $0.isFavorite &&
                (searchText.isEmpty || $0.contactName.localizedCaseInsensitiveContains(searchText))
        }
    }

    var allContactsFiltered: [Contact] {
        contacts.filter {
            !$0.isFavorite &&
                (searchText.isEmpty || $0.contactName.localizedCaseInsensitiveContains(searchText))
        }
    }

    func loadContacts() {
        isLoading = true
        ContactsAPIService.shared.fetchContacts { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let contacts):
                    self?.contacts = contacts
                case .failure(let error):
                    debugLog("fetchContacts error: \(result)")
                    self?.errorMessage = error.content
                }
            }
        }
    }

    func toggleFavorite(contactID: UInt64) {
        ContactsAPIService.shared.toggleFavorite(contactID: contactID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = self?.contacts.firstIndex(where: { $0.id == contactID }) {
                        self?.contacts[index].isFavorite.toggle()
                    }
                case .failure(let error):
                    self?.errorMessage = error.content
                }
            }
        }
    }

    func deleteContact(contactID: UInt64) {
        ContactsAPIService.shared.deleteContact(contactID: contactID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.contacts.removeAll { $0.id == contactID }
                case .failure(let error):
                    self?.errorMessage = error.content
                }
            }
        }
    }
}
