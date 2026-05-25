import AppKit
import Foundation
import Observation

@Observable
final class ProcessingStore {
    var inputFolder: URL?
    var outputFolder: URL?
    var jobs: [VideoJob] = []
    var events: [ProcessingEvent] = []
    var status: ProcessingStatus = .idle
    var settings = DetectionSettings()

    private let processor = ClipProcessor()

    var canProcess: Bool {
        inputFolder != nil && outputFolder != nil && status != .running
    }

    func chooseInputFolder() {
        if let url = FolderPanel.pick(title: "Choose Input Folder") {
            inputFolder = url
            loadJobs()
        }
    }

    func chooseOutputFolder() {
        if let url = FolderPanel.pick(title: "Choose Output Folder") {
            outputFolder = url
        }
    }

    func loadJobs() {
        guard let inputFolder else {
            jobs = []
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: inputFolder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            jobs = files
                .filter { VideoFileSupport.isSupported($0) }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { VideoJob(sourceURL: $0, status: "Waiting") }
            addEvent("Found \(jobs.count) video file\(jobs.count == 1 ? "" : "s").")
        } catch {
            status = .failed(error.localizedDescription)
            addEvent("Could not read input folder: \(error.localizedDescription)")
        }
    }

    @MainActor
    func process() async {
        guard let outputFolder, !jobs.isEmpty else { return }

        status = .running
        addEvent("Starting split.")

        for index in jobs.indices {
            jobs[index].status = "Detecting cuts"
            let sourceURL = jobs[index].sourceURL

            do {
                let result = try await processor.process(
                    sourceURL: sourceURL,
                    outputRoot: outputFolder,
                    settings: settings
                ) { [weak self] message in
                    Task { @MainActor in self?.addEvent(message) }
                }
                jobs[index].clipCount = result.clipCount
                jobs[index].status = "Done"
            } catch {
                jobs[index].status = "Failed"
                status = .failed(error.localizedDescription)
                addEvent("\(sourceURL.lastPathComponent): \(error.localizedDescription)")
                return
            }
        }

        status = .finished
        addEvent("All done.")
    }

    func addEvent(_ message: String) {
        events.insert(ProcessingEvent(message: message), at: 0)
    }
}
