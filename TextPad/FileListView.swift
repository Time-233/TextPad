import SwiftUI
import UniformTypeIdentifiers

struct FileListView: View {
    let directory: URL
    let isRoot: Bool

    @EnvironmentObject private var store: FileStore
    @State private var items: [FileItem] = []
    @State private var query = ""
    @State private var activeSheet: Sheet?
    @State private var deleteTarget: FileItem?
    @State private var showImporter = false
    @State private var errorMessage: String?

    private enum Sheet: Identifiable {
        case newFile
        case newFolder
        case rename(FileItem)

        var id: String {
            switch self {
            case .newFile: return "newFile"
            case .newFolder: return "newFolder"
            case .rename(let item): return "rename-" + item.url.path
            }
        }
    }

    private var filtered: [FileItem] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                emptyRow
            } else {
                ForEach(filtered) { item in
                    row(for: item)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(isRoot ? "文本记事本" : directory.lastPathComponent)
        .navigationBarTitleDisplayMode(isRoot ? .large : .inline)
        .searchable(text: $query, prompt: "搜索文件名")
        .toolbar { toolbarContent }
        .refreshable { reload() }
        .onAppear { reload() }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .confirmationDialog("确定删除？",
                            isPresented: Binding(get: { deleteTarget != nil },
                                                 set: { if !$0 { deleteTarget = nil } }),
                            titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let item = deleteTarget {
                    store.delete(item)
                    deleteTarget = nil
                    reload()
                }
            }
            Button("取消", role: .cancel) {
                deleteTarget = nil
            }
        } message: {
            Text(deleteTarget?.name ?? "")
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.plainText, .text, .data],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    store.importFile(from: url, into: directory)
                }
                reload()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("提示",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 子视图

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(query.isEmpty ? "这里还是空的" : "没有匹配的文件")
                .font(.headline)
            Text(query.isEmpty
                 ? "点右上角 + 新建 txt / ini，或者点「文件」App 里的分享把文件导入进来。"
                 : "换个关键词再搜一次。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func row(for item: FileItem) -> some View {
        NavigationLink(value: item.url) {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: item))
                    .font(.system(size: 21))
                    .foregroundStyle(item.isDirectory ? Color.accentColor : Color.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.body)
                        .lineLimit(1)
                    Text(subtitle(for: item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteTarget = item
            } label: {
                Label("删除", systemImage: "trash")
            }
            Button {
                activeSheet = .rename(item)
            } label: {
                Label("重命名", systemImage: "pencil")
            }
            .tint(.orange)
            if !item.isDirectory {
                Button {
                    store.duplicate(item)
                    reload()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .tint(.blue)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    activeSheet = .newFile
                } label: {
                    Label("新建文本文件", systemImage: "doc.badge.plus")
                }
                Button {
                    activeSheet = .newFolder
                } label: {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("从别处导入文件", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: Sheet) -> some View {
        switch sheet {
        case .newFile:
            NewFileSheet(directory: directory) { newURL in
                reload()
                guard let url = newURL else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    store.openRequest = url
                }
            }
        case .newFolder:
            NameInputSheet(title: "新建文件夹",
                           placeholder: "文件夹名",
                           initialText: "新建文件夹") { name in
                _ = store.createFolder(in: directory, name: name)
                reload()
            }
        case .rename(let item):
            NameInputSheet(title: "重命名",
                           placeholder: "新名称",
                           initialText: item.name) { name in
                _ = store.rename(item, to: name)
                reload()
            }
        }
    }

    // MARK: - 逻辑

    private func reload() {
        items = store.contents(of: directory)
    }

    private func iconName(for item: FileItem) -> String {
        if item.isDirectory { return "folder.fill" }
        switch item.fileExtension {
        case "ini", "conf", "cfg", "toml", "properties": return "gearshape.fill"
        case "json", "yaml", "yml", "xml": return "curlybraces"
        case "md", "markdown": return "text.alignleft"
        case "csv": return "tablecells"
        case "log": return "doc.text.magnifyingglass"
        case "html", "htm", "css", "js", "ts": return "chevron.left.forwardslash.chevron.right"
        case "sh", "py", "swift", "c", "cpp", "h", "java", "go", "rs": return "terminal"
        default: return "doc.text"
        }
    }

    private func subtitle(for item: FileItem) -> String {
        if item.isDirectory { return "文件夹" }
        return item.sizeText + " · " + item.dateText
    }
}
