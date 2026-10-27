import SwiftUI

struct NewFileSheet: View {
    let directory: URL
    let onFinish: (URL?) -> Void

    @EnvironmentObject private var store: FileStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var fileExtension = "txt"
    @State private var useTemplate = false

    private let extensions = ["txt", "ini", "md", "json", "csv", "log", "conf",
                              "cfg", "xml", "yaml", "html", "sh", "py", "js", "swift"]

    var body: some View {
        NavigationStack {
            Form {
                Section("文件名") {
                    TextField("例如 notes", text: $name)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section("类型") {
                    Picker("扩展名", selection: $fileExtension) {
                        ForEach(extensions, id: \.self) { ext in
                            Text("." + ext).tag(ext)
                        }
                    }
                    Toggle("顺便写入示例内容", isOn: $useTemplate)
                }
                Section {
                    Text("文件会建在当前文件夹里，之后可以用数据线、爱思助手或者「文件」App 拷出来。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新建文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onFinish(nil)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { create() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var template: String? {
        guard useTemplate else { return nil }
        switch fileExtension {
        case "ini", "conf", "cfg":
            return "; 由 文本记事本 创建\n[Section]\nkey = value\n"
        case "json":
            return "{\n  \"key\": \"value\"\n}\n"
        case "md":
            return "# 标题\n\n- 第一条\n"
        case "csv":
            return "name,value\n"
        case "html":
            return "<!DOCTYPE html>\n<html>\n<head><meta charset=\"utf-8\"><title>New</title></head>\n<body>\n\n</body>\n</html>\n"
        case "yaml":
            return "key: value\n"
        default:
            return "新建文件\n"
        }
    }

    private func create() {
        let url = store.createFile(in: directory,
                                   name: name,
                                   fileExtension: fileExtension,
                                   template: template)
        onFinish(url)
        dismiss()
    }
}

struct NameInputSheet: View {
    let title: String
    let placeholder: String
    let initialText: String
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField(placeholder, text: $text)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onConfirm(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if text.isEmpty { text = initialText }
            }
        }
        .presentationDetents([.medium])
    }
}
