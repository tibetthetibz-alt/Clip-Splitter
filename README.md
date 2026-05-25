# Slip Splitter

A simple macOS app for splitting uploaded video slips at jump cuts. It writes:

- `clips/`: video clips that keep their original audio
- `audio/`: separate `.m4a` audio exports for each clip

## Requirements

Install `ffmpeg` before processing videos:

```bash
brew install ffmpeg
```

The app checks common Homebrew paths and `PATH`; if `ffmpeg` or `ffprobe` is missing, it shows an error in the activity log.

## Run

```bash
./script/build_and_run.sh
```

In Codex, use the Run action. Pick an input folder, pick an output folder, then press Process.
