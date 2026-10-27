import SwiftUI

@main
struct TextPadApp: App {
    @StateObject private var store = FileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onOpenURL { url in
                    store.openExternalFile(url)
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: FileStore
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            FileListView(directory: store.documentsURL, isRoot: true)
                .navigationDestination(for: URL.self) { url in
                    if url.isDirectoryOnDisk {
                        FileListView(directory: url, isRoot: false)
                    } else {
                        EditorView(fileURL: url)
                    }
                }
        }
        .overlay(alignment: .bottom) { toastView }
        .onAppear(perform: openPendingFile)
        .onChange(of: store.openRequest) { _ in
            openPendingFile()
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let message = store.toast {
            Text(message)
                .font(.footnote)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                .padding(.bottom, 40)
                .transition(.opacity)
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation {
                        store.toast = nil
                    }
                }
        }
    }

    private func openPendingFile() {
        guard let url = store.openRequest else { return }
        store.openRequest = nil
        path.append(url)
    }
}
