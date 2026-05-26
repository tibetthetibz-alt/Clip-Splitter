import AVKit
import SwiftUI

struct DetailView: View {
    @Bindable var store: ProcessingStore

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(store: store)

            Divider()

            HSplitView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Output")
                        .font(.headline)

                    if let job = store.selectedJob, !job.outputs.isEmpty {
                        List(job.outputs, selection: $store.selectedOutputID) { output in
                            OutputRow(output: output)
                                .tag(output.id)
                                .contextMenu {
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([output.url])
                                    }
                                }
                        }
                    } else {
                        ContentUnavailableView("No Clips Yet", systemImage: "film.stack", description: Text("Process the selected video to create clips and audio files."))
                    }
                }
                .padding()
                .frame(minWidth: 260, idealWidth: 320)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.headline)

                    if let output = store.selectedOutput, output.kind == .video {
                        VideoPlayer(player: AVPlayer(url: output.url))
                            .aspectRatio(16 / 9, contentMode: .fit)
                    } else {
                        ContentUnavailableView("Pick a Clip", systemImage: "play.rectangle", description: Text("Video clips appear here after processing."))
                    }
                }
                .padding()
                .frame(minWidth: 360)
            }
        }
    }
}

private struct HeaderView: View {
    @Bindable var store: ProcessingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Image("logo", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.status.title)
                        .font(.title2.weight(.semibold))

                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    Task { await store.process() }
                } label: {
                    Label("Process", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!store.canProcess)
            }

            HStack(spacing: 14) {
                StatView(value: "\(store.jobs.count)", title: "videos")
                StatView(value: "\(store.jobs.reduce(0) { $0 + $1.clipCount })", title: "clips")
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.progressMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressView(value: store.progress)
                        .frame(width: 220)
                }
            }
        }
        .padding(24)
    }

    private var subtitle: String {
        switch store.status {
        case .failed(let message):
            message
        case .running:
            "Detecting cuts, writing clips, and exporting audio."
        case .finished:
            "Clips and audio were written to the output folder."
        case .idle:
            "Choose input and output folders, then process your videos."
        }
    }
}

private struct OutputRow: View {
    let output: OutputArtifact

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: output.kind.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(output.fileName)
                    .lineLimit(1)
                Text("\(output.kind.rawValue) \(output.clipIndex)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatView: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 96, alignment: .leading)
    }
}
