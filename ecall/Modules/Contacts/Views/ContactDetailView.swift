import SwiftUI

struct CallEvent: Identifiable {
    let id = UUID()
    let date: Date
    let isVideo: Bool
}

struct ContactDetailView: View {
    let contact: Contact
    @Environment(\.dismiss) var dismiss
    @State private var callHistory: [CallEvent] = []

    var body: some View {
        List(callHistory) { event in
            HStack {
                Image(systemName: event.isVideo ? "video.fill" : "phone.fill")
                    .foregroundColor(.blue)
                Text(event.date, style: .time)
                    .font(.subheadline)
            }
            .padding(.vertical, 4)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(contact.contactName)
        .onAppear {
            // if you persist call logs in contact:
            // callHistory = contact.callHistory
            // or fetch from API if needed
        }
        .logViewName()
    }
}
