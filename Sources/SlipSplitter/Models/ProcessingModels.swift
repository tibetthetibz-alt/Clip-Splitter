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
    let level: LogLevel
    let message: String
}

enum LogLevel: String, CaseIterable, Hashable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"

    var systemImage: String {
        switch self {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }
}

struct OutputArtifact: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let kind: ArtifactKind
    let clipIndex: Int

    var fileName: String {
        url.lastPathComponent
    }
}

enum ArtifactKind: String, Hashable {
    case video = "Clip"
    case audio = "Full Audio"

    var systemImage: String {
        switch self {
        case .video: "film"
        case .audio: "waveform"
        }
    }
}

struct VideoJob: Identifiable, Hashable {
    let id = UUID()
    let sourceURL: URL
    var status: String
    var clipCount: Int = 0
    var progress: Double = 0
    var outputs: [OutputArtifact] = []

    var fileName: String {
        sourceURL.lastPathComponent
    }

    var clipOutputs: [OutputArtifact] {
        outputs.filter { $0.kind == .video }
    }

    var audioOutput: OutputArtifact? {
        outputs.first { $0.kind == .audio }
    }
}

struct DetectionSettings: Equatable {
    var sceneThreshold = 10.0
    var minimumClipSeconds = 0.7
    var adaptiveMultiplier = 2.6
    var minimumSceneScore = 6.0
}

struct ProcessingProgress: Sendable {
    let stage: String
    let fraction: Double
}
