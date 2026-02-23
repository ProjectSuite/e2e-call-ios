import SwiftUI

struct CallHistoryView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var vm = CallViewModel()
    @State private var showDeleteConfirmation: Bool = false
    @State var mode: EditMode = .inactive
    @State private var searchText: String = ""
    @State private var hasPerformedInitialLoad: Bool = false

    @FocusState private var isSearchFocused: Bool
    @State private var searchWork: DispatchWorkItem?

    var body: some View {
        NavigationStack(path: $vm.navigationPath) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(
                        KeyLocalized.search_placeholder,
                        text: $searchText
                    )
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onChange(of: searchText) { newValue in
                        // Debounce + background search
                        searchWork?.cancel()
                        let work = DispatchWorkItem {
                            Task { @MainActor in
                                vm.updateSearch(query: newValue)
                            }
                        }
                        searchWork = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6)))
                .padding(.horizontal)

                CallHistoryContentView(viewModel: vm, selection: $vm.selectedCalls)
                    .padding(.top, 6)
            }
            .navigationTitle(KeyLocalized.recent_title)
            .simultaneousGesture(
                TapGesture().onEnded {
                    isSearchFocused = false
                }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation {
                            mode = mode == .active ? .inactive : .active
                        }
                    }, label: {
                        Text(mode == .active ? KeyLocalized.done : KeyLocalized.edit)
                    })
                }
                ToolbarItem(placement: .principal) {
                    if mode == .active {
                        if !vm.selectedCalls.isEmpty {
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        Picker("", selection: $vm.selectedSegment) {
                            Text(KeyLocalized.all).tag(0)
                            Text(KeyLocalized.missed).tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 150)
                        .onChange(of: vm.selectedSegment) { _ in
                            // Reload data when switching tabs
                            Task {
                                await vm.forceReload()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingButtons
                }
            }
            .environment(\.editMode, $mode)
            .alert(KeyLocalized.confirm, isPresented: $showDeleteConfirmation) {
                Button(KeyLocalized.delete, role: .destructive) {
                    vm.deleteCalls(withIDs: vm.selectedCalls)
                    vm.selectedCalls.removeAll()
                    mode = .inactive
                }
                Button(KeyLocalized.cancel, role: .cancel) { }
            } message: {
                Text(KeyLocalized.delete_selected_calls_message)
            }
            .onReceive(NotificationCenter.default.publisher(for: .callDidEnd)) { _ in
                Task {
                    await vm.forceReload()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .reloadCallHistory)) { _ in
                Task { await vm.forceReload() }
            }
            .onAppear {
                guard !hasPerformedInitialLoad else { return }
                hasPerformedInitialLoad = true
                Task { await vm.loadInitialIfNeeded() }
            }
            .logViewName()
        }
    }

    @ViewBuilder
    private var trailingButtons: some View {
        if mode == .active {
            HStack(spacing: 16) {
                Button {
                    if vm.selectedCalls.count < vm.items.count {
                        vm.selectedCalls = Set(vm.items.map(\.id!))
                    } else {
                        vm.selectedCalls.removeAll()
                    }
                } label: {
                    Text(vm.selectedCalls.count < vm.items.count ? KeyLocalized.select_all : KeyLocalized.deselect_all)
                }
            }
        } else {
            EmptyView()
        }
    }
}

struct CallHistory_Previews: PreviewProvider {
    static var previews: some View {
        CallHistoryView()
            .environmentObject(LanguageManager())
    }
}
