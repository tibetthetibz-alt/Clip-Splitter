# Clip Splitter

A simple macOS app for splitting uploaded videos at jump cuts. It writes:

- `clips/`: video-only clips with their audio stripped
- `audio/`: one full-length `.m4a` audio export for the source video

## Download

No Homebrew, Xcode, or FFmpeg install required.

[![Download latest release](https://img.shields.io/github/v/release/tibetthetibz-alt/clip-splitter?label=Download%20for%20macOS&style=for-the-badge)](https://github.com/tibetthetibz-alt/clip-splitter/releases/latest)

1. Open **[Releases](https://github.com/tibetthetibz-alt/clip-splitter/releases/latest)** and download **`Clip-Splitter-macOS-Universal.zip`**.
2. Unzip, then drag **`Clip Splitter.app`** into **Applications**.
3. In Finder, select the app → **File → Get Info**. **Kind** should show **Application (Universal)** (Intel and Apple silicon).
4. On first launch, if macOS blocks the app: **right-click → Open**, then confirm.

The release build includes FFmpeg inside the app bundle.

## Requirements

- macOS 14 or later

## Develop

Install FFmpeg only if you run a local debug build without packaging:

```bash
brew install ffmpeg
./script/build_and_run.sh
```

### Create a release zip locally

```bash
chmod +x script/package_release.sh
./script/package_release.sh
```

Output: `dist/Clip Splitter.app` and `dist/Clip-Splitter-macOS-Universal.zip`.

### Publish to GitHub Releases

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions builds the universal app, bundles FFmpeg, and attaches the zip to the release.

## Cut Detection

Clip Splitter uses FFmpeg's `scdet` filter as the primary detector. It reads scene-change scores and threshold timestamps, then adds adaptive cut candidates when a frame's scene score spikes above its local rolling neighborhood. This catches obvious jump cuts that a single fixed threshold can miss while still filtering tiny repeated hits by the minimum clip length.

Clip export re-encodes the selected video ranges for frame-accurate cuts. This avoids the end-of-clip spillover that can happen with `-c copy`, which can only cut cleanly near keyframes. Generated clips are video-only, and the `audio/` folder contains one full-length audio export for the source video.

Open Settings for detector tuning and diagnostics from the toolbar.
