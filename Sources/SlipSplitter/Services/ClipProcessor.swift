import Foundation

struct ProcessingResult {
    let clipCount: Int
    let outputs: [OutputArtifact]
    let diagnostics: [ProcessingEvent]
}

enum ClipProcessorError: LocalizedError {
    case ffmpegMissing
    case commandFailed(String)
    case durationMissing
    case noWritableOutput

    var errorDescription: String? {
        switch self {
        case .ffmpegMissing:
            "ffmpeg was not found. Install it with Homebrew: brew install ffmpeg"
        case .commandFailed(let details):
            details
        case .durationMissing:
            "Could not read the video duration."
        case .noWritableOutput:
            "Could not create the output folders."
        }
    }
}

final class ClipProcessor {
    private let fileManager = FileManager.default

    func process(
        sourceURL: URL,
        outputRoot: URL,
        settings: DetectionSettings,
        onProgress: @escaping @Sendable (ProcessingProgress) -> Void
    ) async throws -> ProcessingResult {
        let ffmpeg = try await findExecutable("ffmpeg")
        let ffprobe = try await findExecutable("ffprobe")
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let jobFolder = outputRoot.appendingPathComponent(baseName, isDirectory: true)
        let clipsFolder = jobFolder.appendingPathComponent("clips", isDirectory: true)
        let audioFolder = jobFolder.appendingPathComponent("audio", isDirectory: true)

        do {
            try fileManager.createDirectory(at: clipsFolder, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: audioFolder, withIntermediateDirectories: true)
        } catch {
            throw ClipProcessorError.noWritableOutput
        }

        var diagnostics: [ProcessingEvent] = []
        diagnostics.append(ProcessingEvent(level: .info, message: "Using FFmpeg scene detector for \(sourceURL.lastPathComponent)."))
        onProgress(ProcessingProgress(stage: "Reading duration", fraction: 0.03))
        let duration = try await videoDuration(sourceURL: sourceURL, ffprobe: ffprobe)
        onProgress(ProcessingProgress(stage: "Detecting cuts", fraction: 0.08))
        let detection = try await detectCutPoints(
            sourceURL: sourceURL,
            ffmpeg: ffmpeg,
            duration: duration,
            settings: settings
        ) { progress in
            onProgress(ProcessingProgress(stage: "Detecting cuts", fraction: 0.08 + progress * 0.52))
        }
        let cutPoints = detection.cutPoints
        let ranges = makeRanges(cutPoints: cutPoints, duration: duration, minimumLength: settings.minimumClipSeconds)

        diagnostics.append(ProcessingEvent(level: .info, message: "Detected \(cutPoints.count) cut point\(cutPoints.count == 1 ? "" : "s") and will write \(ranges.count) clip\(ranges.count == 1 ? "" : "s")."))
        diagnostics += detection.diagnostics
        var outputs: [OutputArtifact] = []
        let audioURL = audioFolder.appendingPathComponent("\(baseName)_audio.m4a")

        onProgress(ProcessingProgress(stage: "Extracting full audio", fraction: 0.60))
        try await run(
            executable: ffmpeg,
            arguments: [
                "-hide_banner", "-y",
                "-i", sourceURL.path(percentEncoded: false),
                "-vn",
                "-c:a", "aac",
                "-b:a", "192k",
                audioURL.path(percentEncoded: false)
            ]
        )
        outputs.append(OutputArtifact(url: audioURL, kind: .audio, clipIndex: 0))

        for (index, range) in ranges.enumerated() {
            let number = String(format: "%03d", index + 1)
            let clipURL = clipsFolder.appendingPathComponent("\(baseName)_clip_\(number).mp4")
            let baseProgress = Double(index) / Double(max(ranges.count, 1))
            onProgress(ProcessingProgress(stage: "Writing clip \(index + 1) of \(ranges.count)", fraction: 0.68 + baseProgress * 0.30))

            try await run(
                executable: ffmpeg,
                arguments: [
                    "-hide_banner", "-y",
                    "-i", sourceURL.path(percentEncoded: false),
                    "-ss", formatSeconds(range.start),
                    "-to", formatSeconds(range.end),
                    "-map", "0:v:0",
                    "-c:v", "libx264",
                    "-preset", "veryfast",
                    "-crf", "18",
                    "-an",
                    "-movflags", "+faststart",
                    clipURL.path(percentEncoded: false)
                ]
            )

            outputs.append(OutputArtifact(url: clipURL, kind: .video, clipIndex: index + 1))
        }

        onProgress(ProcessingProgress(stage: "Finished", fraction: 1))
        return ProcessingResult(clipCount: ranges.count, outputs: outputs, diagnostics: diagnostics)
    }

    private func findExecutable(_ name: String) async throws -> String {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]

        if let match = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return match
        }

        let result = try await runCapturing(executable: "/usr/bin/env", arguments: ["which", name])
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty {
            return path
        }

        throw ClipProcessorError.ffmpegMissing
    }

    private func videoDuration(sourceURL: URL, ffprobe: String) async throws -> Double {
        let result = try await runCapturing(
            executable: ffprobe,
            arguments: [
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                sourceURL.path(percentEncoded: false)
            ]
        )

        guard let duration = Double(result.output.trimmingCharacters(in: .whitespacesAndNewlines)), duration > 0 else {
            throw ClipProcessorError.durationMissing
        }

        return duration
    }

    private func detectCutPoints(
        sourceURL: URL,
        ffmpeg: String,
        duration: Double,
        settings: DetectionSettings,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> (cutPoints: [Double], diagnostics: [ProcessingEvent]) {
        let filter = "scdet=threshold=\(settings.sceneThreshold),metadata=mode=print"
        let result = try await runStreaming(
            executable: ffmpeg,
            arguments: [
                "-hide_banner",
                "-i", sourceURL.path(percentEncoded: false),
                "-vf", filter,
                "-an",
                "-progress", "pipe:1",
                "-nostats",
                "-f", "null",
                "-"
            ],
            duration: duration,
            onProgress: onProgress
        )

        let text = result.output + "\n" + result.error
        let scoreSamples = parseSceneScores(text)
        let thresholdCuts = parseNumbers(text, pattern: #"lavfi\.scd\.time=([0-9]+(?:\.[0-9]+)?)"#)
        let adaptiveCuts = adaptiveCutPoints(from: scoreSamples, settings: settings)
        let merged = mergeCutPoints(thresholdCuts + adaptiveCuts, minimumGap: settings.minimumClipSeconds)
        let diagnostics = [
            ProcessingEvent(level: .info, message: "Detector: scdet threshold \(settings.sceneThreshold), adaptive ratio \(settings.adaptiveMultiplier)."),
            ProcessingEvent(level: .info, message: "Read \(scoreSamples.count) scene score sample\(scoreSamples.count == 1 ? "" : "s")."),
            ProcessingEvent(level: .info, message: "Threshold cuts: \(thresholdCuts.count), adaptive additions: \(adaptiveCuts.count).")
        ]

        if !merged.isEmpty || !scoreSamples.isEmpty {
            return (merged, diagnostics)
        }

        let fallback = try await detectCutPointsWithSelect(sourceURL: sourceURL, ffmpeg: ffmpeg, settings: settings)
        return (fallback, diagnostics + [ProcessingEvent(level: .warning, message: "scdet returned no metadata, used select(scene) fallback.")])
    }

    private func makeRanges(cutPoints: [Double], duration: Double, minimumLength: Double) -> [(start: Double, end: Double)] {
        var points = [0] + cutPoints.filter { $0 > minimumLength && $0 < duration - minimumLength } + [duration]
        points = Array(Set(points)).sorted()

        var ranges: [(start: Double, end: Double)] = []
        var start = points[0]

        for point in points.dropFirst() {
            if point - start >= minimumLength {
                ranges.append((start, point))
                start = point
            }
        }

        if ranges.isEmpty {
            return [(0, duration)]
        }

        if let last = ranges.last, duration - last.end >= minimumLength {
            ranges.append((last.end, duration))
        }

        return ranges
    }

    private func run(executable: String, arguments: [String]) async throws {
        let result = try await runCapturing(executable: executable, arguments: arguments)
        guard result.status == 0 else {
            throw ClipProcessorError.commandFailed(result.error.isEmpty ? result.output : result.error)
        }
    }

    private func runCapturing(
        executable: String,
        arguments: [String],
        allowNonZero: Bool = false
    ) async throws -> (status: Int32, output: String, error: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if process.terminationStatus == 0 || allowNonZero {
                    continuation.resume(returning: (process.terminationStatus, output, error))
                } else {
                    continuation.resume(throwing: ClipProcessorError.commandFailed(error.isEmpty ? output : error))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func runStreaming(
        executable: String,
        arguments: [String],
        duration: Double,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> (status: Int32, output: String, error: String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            let outputData = LockedData()
            let errorData = LockedData()
            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading

            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                outputData.append(data)
                if let chunk = String(data: data, encoding: .utf8) {
                    for line in chunk.split(separator: "\n") where line.hasPrefix("out_time_ms=") {
                        let raw = line.replacingOccurrences(of: "out_time_ms=", with: "")
                        if let microseconds = Double(raw) {
                            onProgress(min(max((microseconds / 1_000_000) / duration, 0), 1))
                        }
                    }
                }
            }

            errorHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                errorData.append(data)
            }

            process.terminationHandler = { process in
                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil
                let output = String(data: outputData.data, encoding: .utf8) ?? ""
                let error = String(data: errorData.data, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume(returning: (process.terminationStatus, output, error))
                } else {
                    continuation.resume(throwing: ClipProcessorError.commandFailed(error.isEmpty ? output : error))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func detectCutPointsWithSelect(sourceURL: URL, ffmpeg: String, settings: DetectionSettings) async throws -> [Double] {
        let selectThreshold = max(settings.minimumSceneScore / 100, 0.08)
        let filter = "select=gt(scene\\,\(selectThreshold)),showinfo"
        let result = try await runCapturing(
            executable: ffmpeg,
            arguments: ["-hide_banner", "-i", sourceURL.path(percentEncoded: false), "-vf", filter, "-an", "-f", "null", "-"],
            allowNonZero: true
        )
        return mergeCutPoints(parseNumbers(result.output + "\n" + result.error, pattern: #"pts_time:([0-9]+(?:\.[0-9]+)?)"#), minimumGap: settings.minimumClipSeconds)
    }

    private func parseSceneScores(_ text: String) -> [(time: Double, score: Double)] {
        let times = parseNumbers(text, pattern: #"pts_time:([0-9]+(?:\.[0-9]+)?)"#)
        let scores = parseNumbers(text, pattern: #"lavfi\.scd\.score=([0-9]+(?:\.[0-9]+)?)"#)
        return zip(times, scores).map { ($0, $1) }
    }

    private func adaptiveCutPoints(from samples: [(time: Double, score: Double)], settings: DetectionSettings) -> [Double] {
        guard samples.count > 4 else { return [] }
        let window = 2
        return samples.indices.compactMap { index in
            let score = samples[index].score
            guard score >= settings.minimumSceneScore else { return nil }
            let lower = max(0, index - window)
            let upper = min(samples.count - 1, index + window)
            let neighbors = (lower...upper).filter { $0 != index }.map { samples[$0].score }
            let average = max(neighbors.reduce(0, +) / Double(max(neighbors.count, 1)), 0.1)
            return score / average >= settings.adaptiveMultiplier ? samples[index].time : nil
        }
    }

    private func parseNumbers(_ text: String, pattern: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match -> Double? in
            guard let valueRange = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[valueRange])
        }
    }

    private func mergeCutPoints(_ points: [Double], minimumGap: Double) -> [Double] {
        Array(Set(points)).sorted().reduce(into: [Double]()) { result, point in
            if let last = result.last, point - last < minimumGap {
                return
            }
            result.append(point)
        }
    }

    private func formatSeconds(_ seconds: Double) -> String {
        String(format: "%.3f", seconds)
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }
}
