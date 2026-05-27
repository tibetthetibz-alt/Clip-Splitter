import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return version == build ? version : "\(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image("logo", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Clip Splitter")
                        .font(.title2.weight(.semibold))
                    Text("Version \(appVersion)")
                        .foregroundStyle(.secondary)
                }
            }

            Text("Clip Splitter finds jump cuts in your videos and exports frame-accurate clips plus a full-length audio file. FFmpeg is bundled—no Homebrew install needed.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Label("Universal app for Apple silicon and Intel Macs", systemImage: "laptopcomputer.and.arrow.down")
                Label("Detects cuts with FFmpeg scene detection + adaptive scoring", systemImage: "scissors")
                Label("Writes video-only clips and one `.m4a` per source", systemImage: "folder")
                Label("Preview clips and sources in the app", systemImage: "play.rectangle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Link(destination: URL(string: "https://github.com/tibetthetibz-alt/clip-splitter/releases/latest/download/Clip-Splitter-macOS-Universal.zip")!) {
                Label("Download latest release (.zip)", systemImage: "arrow.down.circle")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
