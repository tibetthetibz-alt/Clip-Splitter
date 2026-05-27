# Clip Splitter

**Split videos at jump cuts.**

Clip Splitter is a macOS app that scans a folder of videos, detects scene changes and jump cuts, and exports ready-to-use clips plus a full-length audio track for each file.

<p align="center">
  <a href="https://github.com/tibetthetibz-alt/clip-splitter/releases/latest/download/Clip-Splitter-macOS-Universal.zip">
    <img src="https://img.shields.io/badge/Download-Clip%20Splitter%20for%20macOS-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="Download Clip Splitter for macOS">
  </a>
</p>

<p align="center">
  <a href="https://github.com/tibetthetibz-alt/clip-splitter/releases/latest/download/Clip-Splitter-macOS-Universal.zip"><strong>Download Clip-Splitter-macOS-Universal.zip</strong></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/tibetthetibz-alt/clip-splitter/releases/latest">All releases</a>
</p>

---

## Quick start

1. **Download** [`Clip-Splitter-macOS-Universal.zip`](https://github.com/tibetthetibz-alt/clip-splitter/releases/latest/download/Clip-Splitter-macOS-Universal.zip) (works on Apple silicon and Intel).
2. **Unzip** and drag **`Clip Splitter.app`** to **Applications**.
3. **Open** the app. If macOS blocks it the first time: **right-click → Open**, then confirm.
4. Choose an **input folder** (your videos) and an **output folder**.
5. Select a video in the sidebar and click **Run** (or press **⌘R**).

No Homebrew, Xcode, or FFmpeg setup—the release app includes everything it needs.

---

## About

Clip Splitter is built for creators who record long takes and need clean splits at hard cuts without editing by hand in a timeline first.

For each source video it creates a folder like:

```text
Output/
  MyVideo/
    clips/     → MyVideo_clip_001.mp4, MyVideo_clip_002.mp4, …  (video only)
    audio/     → MyVideo_audio.m4a                               (full-length audio)
```

**What it does well**

- **Jump-cut detection** — FFmpeg `scdet` plus adaptive scoring so obvious cuts are caught without chopping on tiny flickers.
- **Frame-accurate exports** — clips are re-encoded (H.264) so cuts land on the right frame; copy-mode keyframe limits are avoided.
- **One audio export per source** — a single `.m4a` for the whole file, separate from the silent clip files.
- **In-app preview** — play the source or any exported clip before opening Finder.
- **Tunable detection** — scene threshold, adaptive ratio, minimum score, and minimum clip length in **Settings**.
- **Activity log** — diagnostics for each run (cut count, warnings, errors).

**Supported input formats:** `.mp4`, `.mov`, `.m4v`, `.mkv`, `.avi`, `.webm` (flat folder; files in the top level of the input folder).

**Requirements:** macOS 14 or later.

---

## How to use

| Step | Action |
|------|--------|
| 1 | **Input** — pick the folder that contains your videos. |
| 2 | **Output** — pick where finished `clips/` and `audio/` folders should be written. |
| 3 | **Select** a video in the sidebar. |
| 4 | **Run** — process that file (⌘R). |
| 5 | **Preview** clips in the right panel; use **Show Clips in Finder** when done. |

Open **Settings** (toolbar) for detector sliders and the processing log. The **About** section in Settings shows the app version and a download link for updates.

---

## Output details

- **Clips** — video only (audio stripped), named `{basename}_clip_001.mp4`, etc.
- **Audio** — AAC in `.m4a`, one file per source at `{basename}_audio.m4a`.
- **Quality** — H.264, `veryfast` preset, CRF 18, `+faststart` for playback.

Detection uses a primary **scene threshold** and adds **adaptive** candidates when a frame’s scene score spikes above its local neighborhood—useful when a single fixed threshold misses clear jump cuts. **Minimum clip length** filters out very short segments.

---

## Build from source

For development only (FFmpeg from Homebrew is used when not running the packaged app):

```bash
brew install ffmpeg
./script/build_and_run.sh
```

**Package a universal release locally** (bundles FFmpeg, builds `dist/Clip Splitter.app` and `dist/Clip-Splitter-macOS-Universal.zip`):

```bash
chmod +x script/package_release.sh
./script/package_release.sh
```

---

## License

See repository license file. FFmpeg components in release builds follow their respective licenses (LGPL/GPL depending on the bundled build).
