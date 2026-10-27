import SwiftUI
import UIKit
import Combine

struct EditorView: View {
    let fileURL: URL

    @EnvironmentObject private var store: FileStore

    @State private var text = ""
    @State private var savedText = ""
    @State private var loaded = false
    @State private var encoding: TextEncoding = .utf8
    @State private var fontSize: Double = 15
    @State private var showSettings = false
    @State private var showFind = false
    @State private var findText = ""
    @State private var errorMessage: String?

    private var isDirty: Bool { text != savedText }

    private var lineCount: Int {
        text.isEmpty ? 0 : text.components(separatedBy: .newlines).count
    }

    var body: some View {
        VStack(spacing: 0) {
            if showFind { findBar }
            TextEditor(text: $text)
                .font(.system(size: fontSize, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
            statusBar
        }
        .navigationTitle(fileURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear(perform: load)
        .onDisappear {
            if isDirty { save(showToast: false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            if isDirty { save(showToast: false) }
        }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .alert("提示",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 子视图

    private var findBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("在正文里查找", text: $findText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !findText.isEmpty {
                Text("\(occurrences(of: findText)) 处")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                showFind = false
                findText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text("\(lineCount) 行")
            Text("\(text.count) 字")
            Spacer()
            Button {
                showSettings = true
            } label: {
                Text(encoding.label)
                    .font(.caption.weight(.semibold))
            }
            if isDirty {
                Text("未保存")
                    .foregroundStyle(Color.orange)
            } else {
                Text("已保存")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("字号") {
                    Slider(value: $fontSize, in: 10...30, step: 1)
                    Text("当前 \(Int(fontSize)) pt")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("文件编码") {
                    Picker("编码", selection: $encoding) {
                        ForEach(TextEncoding.allCases) { enc in
                            Text(enc.label).tag(enc)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("保存时会按这个编码写回。中文乱码就换成 GB18030 再看一遍。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("文件信息") {
                    HStack {
                        Text("名称")
                        Spacer()
                        Text(fileURL.lastPathComponent)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    HStack {
                        Text("字符数")
                        Spacer()
                        Text("\(text.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("编辑器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showSettings = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                showFind.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            Button {
                save(showToast: true)
            } label: {
                Image(systemName: isDirty ? "square.and.arrow.down.fill" : "checkmark.circle")
            }
            .disabled(!isDirty)
            Menu {
                Button {
                    showSettings = true
                } label: {
                    Label("编辑器设置", systemImage: "textformat.size")
                }
                ShareLink(item: fileURL) {
                    Label("分享 / 导出文件", systemImage: "square.and.arrow.up")
                }
                Button {
                    fontSize = min(fontSize + 1, 30)
                } label: {
                    Label("放大字号", systemImage: "plus.magnifyingglass")
                }
                Button {
                    fontSize = max(fontSize - 1, 10)
                } label: {
                    Label("缩小字号", systemImage: "minus.magnifyingglass")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("收起键盘") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil,
                                                from: nil,
                                                for: nil)
            }
        }
    }

    // MARK: - 读写

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL) else {
            errorMessage = "读取文件失败"
            return
        }
        if data.isEmpty {
            text = ""
            savedText = ""
            return
        }
        for candidate in [TextEncoding.utf8, .utf16, .gb18030] {
            if let decoded = String(data: data, encoding: candidate.encoding) {
                encoding = candidate
                text = decoded
                savedText = decoded
                return
            }
        }
        let decoded = String(decoding: data, as: UTF8.self)
        encoding = .utf8
        text = decoded
        savedText = decoded
    }

    private func save(showToast: Bool) {
        guard let data = text.data(using: encoding.encoding) ?? text.data(using: .utf8) else {
            errorMessage = "无法按 \(encoding.label) 编码保存"
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
            savedText = text
            if showToast {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.toast = "已保存 \(fileURL.lastPathComponent)"
            }
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func occurrences(of keyword: String) -> Int {
        guard !keyword.isEmpty else { return 0 }
        let parts = text.components(separatedBy: keyword)
        return max(parts.count - 1, 0)
    }
}
