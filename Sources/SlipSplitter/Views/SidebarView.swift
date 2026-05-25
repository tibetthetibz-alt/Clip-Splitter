import SwiftUI

struct SidebarView: View {
    @Bindable var store: ProcessingStore

    var body: some View {
        List {
            Section("Folders") {
                FolderRow(
                    title: "Input",
                    subtitle: store.inputFolder?.path(percentEncoded: false) ?? "Choose folder",
                    systemImage: "tray.and.arrow.down"
                )
                .contentShape(Rectangle())
                .onTapGesture { store.chooseInputFolder() }

                FolderRow(
                    title: "Output",
                    subtitle: store.outputFolder?.path(percentEncoded: false) ?? "Choose folder",
                    systemImage: "folder.badge.gearshape"
                )
                .contentShape(Rectangle())
                .onTapGesture { store.chooseOutputFolder() }
            }

            Section("Videos") {
                if store.jobs.isEmpty {
                    Text("No supported videos")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.jobs) { job in
                        VideoJobRow(job: job)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Slip Splitter")
    }
}

private struct FolderRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

private struct VideoJobRow: View {
    let job: VideoJob

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "film")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.fileName)
                    .lineLimit(1)
                Text(job.clipCount > 0 ? "\(job.status), \(job.clipCount) clips" : job.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
