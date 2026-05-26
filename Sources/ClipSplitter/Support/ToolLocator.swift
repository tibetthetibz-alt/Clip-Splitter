import Foundation

enum ToolLocator {
    static func path(for tool: String, fileManager: FileManager = .default) -> String? {
        if let bundled = Bundle.main.resourceURL?
            .appendingPathComponent("bin/\(tool)", isDirectory: false)
            .path,
            fileManager.isExecutableFile(atPath: bundled) {
            return bundled
        }

        let candidates = [
            "/opt/homebrew/bin/\(tool)",
            "/usr/local/bin/\(tool)",
            "/usr/bin/\(tool)",
        ]

        return candidates.first { fileManager.isExecutableFile(atPath: $0) }
    }
}
