import Foundation

enum ProcessingStatus: Equatable {
    case idle
    case running
    case finished
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            "Ready"
        case .running:
            "Processing"
        case .finished:
            "Finished"
        case .failed:
            "Needs attention"
        }
    }
}

struct ProcessingEvent: Identifiable, Hashable {
    let id = UUID()
    let date = Date()
    let message: String
}

struct VideoJob: Identifiable, Hashable {
    let id = UUID()
    let sourceURL: URL
    var status: String
    var clipCount: Int = 0

    var fileName: String {
        sourceURL.lastPathComponent
    }
}

struct DetectionSettings: Equatable {
    var sceneThreshold = 0.32
    var minimumClipSeconds = 0.7
}
