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
                    SourcePanel(store: store)

                    Divider()

                    HStack {
                        Text("Clips")
                            .font(.headline)
                        Spacer()
                        if let job = store.selectedJob, !job.clipOutputs.isEmpty {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting(job.clipOutputs.map(\.url))
                            } label: {
                                Image(systemName: "arrow.right.circle")
                            }
                            .help("Show clips in Finder")
                        }
                    }

                    if let job = store.selectedJob, !job.clipOutputs.isEmpty {
                        List(job.clipOutputs, selection: $store.selectedOutputID) { output in
                            OutputRow(output: output)
                                .tag(output.id)
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
                        ClipPlayerView(url: output.url)
                            .aspectRatio(16 / 9, contentMode: .fit)
                    } else if let job = store.selectedJob {
                        ClipPlayerView(url: job.sourceURL)
                            .aspectRatio(16 / 9, contentMode: .fit)
                    } else {
                        ContentUnavailableView("Pick an Input", systemImage: "play.rectangle", description: Text("Choose a video file from the sidebar."))
                    }
                }
                .padding()
                .frame(minWidth: 360)
            }
        }
    }
}

private struct SourcePanel: View {
    @Bindable var store: ProcessingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Input")
                    .font(.headline)
                Spacer()
                Button {
                    store.chooseInputFolder()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Choose input folder")
            }

            if let job = store.selectedJob {
                HStack(spacing: 10) {
                    Image(systemName: "film")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.fileName)
                            .lineLimit(1)
                        Text(job.sourceURL.deletingLastPathComponent().path(percentEncoded: false))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([job.sourceURL])
                    } label: {
                        Image(systemName: "arrow.right.circle")
                    }
                    .help("Show input in Finder")
                }
            } else {
                Text("Choose an input folder, then select a video.")
                    .foregroundStyle(.secondary)
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

private struct ClipPlayerView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.player = AVPlayer(url: url)
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if context.coordinator.currentURL != url {
            view.player?.pause()
            view.player = AVPlayer(url: url)
            context.coordinator.currentURL = url
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(currentURL: url)
    }

    final class Coordinator {
        var currentURL: URL

        init(currentURL: URL) {
            self.currentURL = currentURL
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
