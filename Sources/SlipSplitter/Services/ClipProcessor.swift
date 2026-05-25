import Foundation

struct ProcessingResult {
    let clipCount: Int
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
        onEvent: @escaping @Sendable (String) -> Void
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

        onEvent("Detecting cuts in \(sourceURL.lastPathComponent).")
        let duration = try await videoDuration(sourceURL: sourceURL, ffprobe: ffprobe)
        let cutPoints = try await detectCutPoints(sourceURL: sourceURL, ffmpeg: ffmpeg, settings: settings)
        let ranges = makeRanges(cutPoints: cutPoints, duration: duration, minimumLength: settings.minimumClipSeconds)

        onEvent("Writing \(ranges.count) clip\(ranges.count == 1 ? "" : "s") for \(sourceURL.lastPathComponent).")

        for (index, range) in ranges.enumerated() {
            let number = String(format: "%03d", index + 1)
            let clipURL = clipsFolder.appendingPathComponent("\(baseName)_clip_\(number).mp4")
            let audioURL = audioFolder.appendingPathComponent("\(baseName)_clip_\(number)_audio.m4a")

            try await run(
                executable: ffmpeg,
                arguments: [
                    "-hide_banner", "-y",
                    "-ss", formatSeconds(range.start),
                    "-to", formatSeconds(range.end),
                    "-i", sourceURL.path(percentEncoded: false),
                    "-map", "0",
                    "-c", "copy",
                    "-avoid_negative_ts", "make_zero",
                    clipURL.path(percentEncoded: false)
                ]
            )

            try await run(
                executable: ffmpeg,
                arguments: [
                    "-hide_banner", "-y",
                    "-ss", formatSeconds(range.start),
                    "-to", formatSeconds(range.end),
                    "-i", sourceURL.path(percentEncoded: false),
                    "-vn",
                    "-c:a", "aac",
                    "-b:a", "192k",
                    audioURL.path(percentEncoded: false)
                ]
            )
        }

        return ProcessingResult(clipCount: ranges.count)
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

    private func detectCutPoints(sourceURL: URL, ffmpeg: String, settings: DetectionSettings) async throws -> [Double] {
        let filter = "select=gt(scene\\,\(settings.sceneThreshold)),showinfo"
        let result = try await runCapturing(
            executable: ffmpeg,
            arguments: [
                "-hide_banner",
                "-i", sourceURL.path(percentEncoded: false),
                "-vf", filter,
                "-an",
                "-f", "null",
                "-"
            ],
            allowNonZero: true
        )

        let text = result.output + "\n" + result.error
        let pattern = #"pts_time:([0-9]+(?:\.[0-9]+)?)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let values = regex.matches(in: text, range: range).compactMap { match -> Double? in
            guard let valueRange = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[valueRange])
        }

        return Array(Set(values)).sorted()
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

    private func formatSeconds(_ seconds: Double) -> String {
        String(format: "%.3f", seconds)
    }
}
