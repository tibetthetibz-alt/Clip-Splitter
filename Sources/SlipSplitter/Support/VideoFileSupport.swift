import Foundation

enum VideoFileSupport {
    private static let extensions = Set(["mp4", "mov", "m4v", "mkv", "avi", "webm"])

    static func isSupported(_ url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}
