import SwiftUI

struct DetailView: View {
    @Bindable var store: ProcessingStore

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(store: store)

            Divider()

            Form {
                Section("Cut Detection") {
                    Slider(value: $store.settings.sceneThreshold, in: 0.12...0.7) {
                        Text("Sensitivity")
                    } minimumValueLabel: {
                        Text("More")
                    } maximumValueLabel: {
                        Text("Less")
                    }

                    LabeledContent("Threshold") {
                        Text(store.settings.sceneThreshold, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }

                    Stepper(value: $store.settings.minimumClipSeconds, in: 0.2...10, step: 0.1) {
                        LabeledContent("Minimum clip length") {
                            Text("\(store.settings.minimumClipSeconds, specifier: "%.1f")s")
                                .monospacedDigit()
                        }
                    }
                }

                Section("Activity") {
                    if store.events.isEmpty {
                        Text("Waiting for a folder.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.events) { event in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.message)
                                Text(event.date, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct HeaderView: View {
    @Bindable var store: ProcessingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
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
