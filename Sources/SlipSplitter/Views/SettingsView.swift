import SwiftUI

struct SettingsView: View {
    @Bindable var store: ProcessingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image("logo", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading) {
                    Text("Slip Splitter Settings")
                        .font(.title3.weight(.semibold))
                    Text("Detector tuning and processing diagnostics")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            Divider()

            Form {
                Section("Cut Detection") {
                    Slider(value: $store.settings.sceneThreshold, in: 4...20) {
                        Text("Scene threshold")
                    } minimumValueLabel: {
                        Text("More")
                    } maximumValueLabel: {
                        Text("Less")
                    }
                    LabeledContent("Scene threshold") {
                        Text(store.settings.sceneThreshold, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                    }

                    Stepper(value: $store.settings.adaptiveMultiplier, in: 1.4...5, step: 0.1) {
                        LabeledContent("Adaptive ratio") {
                            Text(store.settings.adaptiveMultiplier, format: .number.precision(.fractionLength(1)))
                                .monospacedDigit()
                        }
                    }

                    Stepper(value: $store.settings.minimumSceneScore, in: 2...20, step: 0.5) {
                        LabeledContent("Minimum scene score") {
                            Text(store.settings.minimumSceneScore, format: .number.precision(.fractionLength(1)))
                                .monospacedDigit()
                        }
                    }

                    Stepper(value: $store.settings.minimumClipSeconds, in: 0.2...10, step: 0.1) {
                        LabeledContent("Minimum clip length") {
                            Text("\(store.settings.minimumClipSeconds, specifier: "%.1f")s")
                                .monospacedDigit()
                        }
                    }
                }

                Section("Diagnostics") {
                    if store.events.isEmpty {
                        Text("No diagnostics yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.events) { event in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: event.level.systemImage)
                                    .foregroundStyle(event.level == .error ? .red : event.level == .warning ? .yellow : .secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.message)
                                    Text("\(event.level.rawValue) at \(event.date.formatted(date: .omitted, time: .standard))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
