import Foundation
import CoreFoundation

/// 列表里的一行：文件或文件夹
struct FileItem: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let modified: Date

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var fileExtension: String { url.pathExtension.lowercased() }

    var sizeText: String {
        if isDirectory { return "文件夹" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var dateText: String {
        FileItem.dateFormatter.string(from: modified)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()
}

/// 编辑器支持的文本编码
enum TextEncoding: String, CaseIterable, Identifiable, Hashable {
    case utf8
    case gb18030
    case utf16

    var id: String { rawValue }

    var label: String {
        switch self {
        case .utf8: return "UTF-8"
        case .gb18030: return "GB18030"
        case .utf16: return "UTF-16"
        }
    }

    var encoding: String.Encoding {
        switch self {
        case .utf8:
            return .utf8
        case .utf16:
            return .utf16
        case .gb18030:
            // kCFStringEncodingGB_18030_2000 == 0x0632
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0632))
            return String.Encoding(rawValue: nsEncoding)
        }
    }
}

extension URL {
    var isDirectoryOnDisk: Bool {
        let values = try? resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory ?? false
    }
}
