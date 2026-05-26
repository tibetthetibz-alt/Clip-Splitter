import SwiftUI

struct SidebarView: View {
    @Bindable var store: ProcessingStore

    var body: some View {
        List {
            Section("Folders") {
                FolderRow(
                    title: "Choose Input Folder",
                    subtitle: store.inputFolder?.path(percentEncoded: false) ?? "Choose folder",
                    systemImage: "tray.and.arrow.down"
                )
                .contentShape(Rectangle())
                .onTapGesture { store.chooseInputFolder() }

                FolderRow(
                    title: "Choose Output Folder",
                    subtitle: store.outputFolder?.path(percentEncoded: false) ?? "Choose folder",
                    systemImage: "folder.badge.gearshape"
                )
                .contentShape(Rectangle())
                .onTapGesture { store.chooseOutputFolder() }
            }

            Section("Input Videos") {
                if store.jobs.isEmpty {
                    Text("No supported videos")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.jobs) { job in
                        VideoJobRow(job: job)
                            .tag(job.id)
                            .listRowBackground(store.selectedJobID == job.id ? Color.accentColor.opacity(0.16) : nil)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectJob(job) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Clip Splitter")
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
            Image(systemName: "play.rectangle")
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
