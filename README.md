# Clip Splitter

A simple macOS app for splitting uploaded videos at jump cuts. It writes:

- `clips/`: video-only clips with their audio stripped
- `audio/`: one full-length `.m4a` audio export for the source video

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


## Cut Detection

Clip Splitter uses FFmpeg's `scdet` filter as the primary detector. It reads scene-change scores and threshold timestamps, then adds adaptive cut candidates when a frame's scene score spikes above its local rolling neighborhood. This catches obvious jump cuts that a single fixed threshold can miss while still filtering tiny repeated hits by the minimum clip length.

Clip export re-encodes the selected video ranges for frame-accurate cuts. This avoids the end-of-clip spillover that can happen with `-c copy`, which can only cut cleanly near keyframes. Generated clips are video-only, and the `audio/` folder contains one full-length audio export for the source video.

Open Settings for detector tuning and diagnostics from the toolbar.
