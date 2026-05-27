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
    var selectedJobID: VideoJob.ID?
    var selectedOutputID: OutputArtifact.ID?
    var progress: Double = 0
    var progressMessage = "Ready"

    private let processor = ClipProcessor()

    var canProcess: Bool {
        inputFolder != nil && outputFolder != nil && selectedJob != nil && status != .running
    }

    var selectedJob: VideoJob? {
        guard let selectedJobID else { return jobs.first }
        return jobs.first { $0.id == selectedJobID }
    }

    var selectedOutput: OutputArtifact? {
        let outputs = selectedJob?.clipOutputs ?? []
        guard let selectedOutputID else { return outputs.first }
        return outputs.first { $0.id == selectedOutputID }
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
            selectedJobID = jobs.first?.id
            selectedOutputID = nil
            addEvent("Found \(jobs.count) video file\(jobs.count == 1 ? "" : "s").")
        } catch {
            status = .failed(error.localizedDescription)
            addEvent("Could not read input folder: \(error.localizedDescription)", level: .error)
        }
    }

    @MainActor
    func process() async {
        guard let outputFolder, let selectedJob, let index = jobs.firstIndex(where: { $0.id == selectedJob.id }) else { return }

        status = .running
        progress = 0
        progressMessage = "Starting"
        jobs[index].status = "Detecting cuts"
        jobs[index].progress = 0
        jobs[index].outputs = []
        selectedOutputID = nil
        let sourceURL = jobs[index].sourceURL
        addEvent("Starting \(sourceURL.lastPathComponent).")

        let jobID = selectedJob.id
        do {
            let result = try await processor.process(
                sourceURL: sourceURL,
                outputRoot: outputFolder,
                settings: settings
            ) { update in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    progress = update.fraction
                    progressMessage = update.stage
                    if let jobIndex = jobs.firstIndex(where: { $0.id == jobID }) {
                        jobs[jobIndex].progress = update.fraction
                        jobs[jobIndex].status = update.stage
                    }
                }
            }
            jobs[index].clipCount = result.clipCount
            jobs[index].outputs = result.outputs
            jobs[index].status = "Done"
            jobs[index].progress = 1
            events.insert(contentsOf: result.diagnostics.reversed(), at: 0)
            selectedOutputID = result.outputs.first { $0.kind == .video }?.id
        } catch {
            jobs[index].status = "Failed"
            status = .failed(error.localizedDescription)
            progressMessage = "Failed"
            addEvent("\(sourceURL.lastPathComponent): \(error.localizedDescription)", level: .error)
            return
        }

        status = .finished
        progressMessage = "Finished"
        addEvent("Finished \(sourceURL.lastPathComponent).")
    }

    func selectJob(_ job: VideoJob) {
        selectedJobID = job.id
        selectedOutputID = job.clipOutputs.first?.id
    }

    func selectOutput(_ output: OutputArtifact) {
        selectedOutputID = output.id
    }

    func addEvent(_ message: String, level: LogLevel = .info) {
        events.insert(ProcessingEvent(level: level, message: message), at: 0)
    }
}
