# Changelog

## 2026-11-16

- Add the English-only `projects/english` branch: translated runtime messages, source comments, documentation, Quarto manual and banner; processing behavior and output schemas are unchanged. Enable push CI and its live badge for this branch.

- Pin and verify local Praat barren **6.4.60** from the official historical release for Linux Intel64/ARM64.
- Replace R's FMM spline with explicit **PCHIP** cubic interpolation, using Fritsch–Butland interior slopes. This changes the numerical method: PCHIP is C1, whereas FMM is C2. Retain gap estimates, cubic endpoint extrapolation and the existing minimum-observation and low-pitch rules.
- Document the provisional preference for PCHIP and the need for C2 when studying a continuous second derivative. The manual includes the corrected attribution and a dated discussion footnote.
- Add nine cubic interpolation regression tests with SciPy as an independent reference, including cases that distinguish cubic interpolation from linear interpolation.
- Support local WAV input alongside MP4. Restore optional CPU Silero VAD using SoundFile and document its runtime requirements. Preserve CSV headers when no speech is detected.
- Add a traceable synthetic English audio fixture and full video CI validation for timestamps, known acoustic values and VAD. Publish synthetic results and provenance reports as CI artifacts.
- Replace the previous PDF with the revised manual and include its Quarto sources. Keep the methods table on one page and wrap the timestamp command within its code block.
- Run push CI on main only, retain pull-request checks and automatically cancel superseded runs for the same branch or pull request.
- Reorganize the README into an English guide and a linked Spanish version, retaining the original cover and badges.

## 2026-01-10

Recorded retrospectively from the January changes.

- Move torch/torchaudio out of general dependencies to avoid CUDA installations exhausting CI storage; add CPU requirements pinned to 2.9.1. Consolidate CI in `parole-ci.yml` and document optional Silero installation. Update authorship, funding and contact information.

## 1.1.1 · 2025-06-20

### 2025-06-27

- Preserve frame 0 by removing the forced deletion of the first timestamp row; the workaround was no longer needed with FFmpeg 7.1+.

### 2025-06-23

- Switch ffprobe timestamp extraction from `pkt_pts_time` to `pts_time` for FFmpeg 7.1+ compatibility.

### 2025-06-20

- Clean up timestamp extraction to avoid empty or malformed rows. Restore creation of the Python environment and dependency installation, and optional reinitialization of the R library directory.
