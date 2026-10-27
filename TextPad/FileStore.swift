import Foundation
import SwiftUI

/// 文件系统的门面：读目录、建文件、改名、删除、导入
final class FileStore: ObservableObject {
    @Published var toast: String?
    @Published var openRequest: URL?

    private let fileManager = FileManager.default

    var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() {
        prepareWelcomeFile()
    }

    // MARK: - 读

    func contents(of directory: URL) -> [FileItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls = (try? fileManager.contentsOfDirectory(at: directory,
                                                         includingPropertiesForKeys: keys,
                                                         options: [.skipsHiddenFiles])) ?? []
        var items: [FileItem] = []
        for url in urls {
            let values = try? url.resourceValues(forKeys: Set(keys))
            items.append(FileItem(url: url,
                                  isDirectory: values?.isDirectory ?? false,
                                  size: Int64(values?.fileSize ?? 0),
                                  modified: values?.contentModificationDate ?? Date.distantPast))
        }
        items.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        return items
    }

    /// 生成一个不重名的文件名
    func uniqueURL(in directory: URL, preferredName: String, fallbackExtension: String) -> URL {
        var base = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "未命名" }
        base = base.replacingOccurrences(of: "/", with: "-")
        base = base.replacingOccurrences(of: ":", with: "-")
        if (base as NSString).pathExtension.isEmpty && !fallbackExtension.isEmpty {
            base += "." + fallbackExtension
        }
        var candidate = directory.appendingPathComponent(base)
        var index = 2
        while fileManager.fileExists(atPath: candidate.path) && index < 1000 {
            let stem = (base as NSString).deletingPathExtension
            let ext = (base as NSString).pathExtension
            let name = ext.isEmpty ? "\(stem) \(index)" : "\(stem) \(index).\(ext)"
            candidate = directory.appendingPathComponent(name)
            index += 1
        }
        return candidate
    }

    // MARK: - 写

    @discardableResult
    func createFile(in directory: URL, name: String, fileExtension: String, template: String?) -> URL? {
        let url = uniqueURL(in: directory, preferredName: name, fallbackExtension: fileExtension)
        let data = (template ?? "").data(using: .utf8) ?? Data()
        do {
            try data.write(to: url, options: .atomic)
            toast = "已创建 \(url.lastPathComponent)"
            return url
        } catch {
            toast = "创建失败：\(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult
    func createFolder(in directory: URL, name: String) -> URL? {
        let url = uniqueURL(in: directory, preferredName: name, fallbackExtension: "")
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: false)
            return url
        } catch {
            toast = "新建文件夹失败：\(error.localizedDescription)"
            return nil
        }
    }

    func rename(_ item: FileItem, to newName: String) -> URL? {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parent = item.url.deletingLastPathComponent()
        let fallback = item.isDirectory ? "" : item.fileExtension
        let target = uniqueURL(in: parent, preferredName: trimmed, fallbackExtension: fallback)
        do {
            try fileManager.moveItem(at: item.url, to: target)
            toast = "已重命名为 \(target.lastPathComponent)"
            return target
        } catch {
            toast = "重命名失败：\(error.localizedDescription)"
            return nil
        }
    }

    func delete(_ item: FileItem) {
        do {
            try fileManager.removeItem(at: item.url)
            toast = "已删除 \(item.name)"
        } catch {
            toast = "删除失败：\(error.localizedDescription)"
        }
    }

    func duplicate(_ item: FileItem) {
        guard !item.isDirectory else { return }
        let stem = item.url.deletingPathExtension().lastPathComponent + " 副本"
        let target = uniqueURL(in: item.url.deletingLastPathComponent(),
                               preferredName: stem,
                               fallbackExtension: item.fileExtension)
        do {
            try fileManager.copyItem(at: item.url, to: target)
            toast = "已复制 \(target.lastPathComponent)"
        } catch {
            toast = "复制失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 和别的 App 交换文件

    func importFile(from source: URL, into directory: URL) {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let target = uniqueURL(in: directory,
                               preferredName: source.lastPathComponent,
                               fallbackExtension: "")
        do {
            try fileManager.copyItem(at: source, to: target)
            toast = "已导入 \(target.lastPathComponent)"
        } catch {
            toast = "导入失败：\(error.localizedDescription)"
        }
    }

    /// 从「文件」App 或分享菜单用本 App 打开时调用
    func openExternalFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let target = uniqueURL(in: documentsURL,
                               preferredName: url.lastPathComponent,
                               fallbackExtension: "txt")
        do {
            try fileManager.copyItem(at: url, to: target)
            openRequest = target
            toast = "已打开 \(target.lastPathComponent)"
        } catch {
            toast = "打开失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 首次启动

    private func prepareWelcomeFile() {
        let readme = documentsURL.appendingPathComponent("使用说明.txt")
        guard !fileManager.fileExists(atPath: readme.path) else { return }
        let body = """
        欢迎使用「文本记事本」

        1. 点右上角 + 可以新建 txt / ini / md / json 等文本文件。
        2. 左滑文件可以重命名、复制、删除。
        3. 中文乱码时：进入文件 → 右上角菜单 → 编辑器设置 → 编码改成 GB18030。
        4. 想用电脑传文件：数据线连电脑，用 iTunes 或爱思助手的「文件共享」；
           也可以直接打开 iPhone 的「文件」App →「我的 iPhone」→「文本记事本」。
        5. 本文件可以直接删掉。
        """
        try? body.data(using: .utf8)?.write(to: readme, options: .atomic)
    }
}
