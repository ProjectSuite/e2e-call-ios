enum FriendAddMode: String, CaseIterable, Identifiable {
    case scan = "scan_qr"
    case autoImport = "auto_import"

    var id: Self { self }
}
