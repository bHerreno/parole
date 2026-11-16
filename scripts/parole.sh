#!/usr/bin/env bash
#

echo "🔊 PAROLE: Automatic Speech Prosody Extraction from Video/Audio"
echo "Copyright (C) 2025 Brian Herreño Jiménez & Cristóbal Pagán Cánovas"
echo "License: GNU GPL v3 - see LICENSE file or https://www.gnu.org/licenses/gpl-3.0.html"
echo ""
echo "This program is free software: you can redistribute it and/or modify"
echo "it under the terms of the GNU General Public License as published by"
echo "the Free Software Foundation, either version 3 of the License, or"
echo "(at your option) any later version."
echo ""

# Usage: ./parole.sh INPUT.mp4|INPUT.wav OUTPUT_DIR [--parquet]
#
# This script performs the following steps:
#   1) Preparation (directories and filenames)
#   2) Prepare audio (source rate for Praat, 16 kHz for Silero)
#   3) Silero VAD, 4) Praat, 5) ffprobe timestamps (video only), in parallel
# Usage:
#   ./parole.sh INPUT.mp4|INPUT.wav OUTPUT_DIR [--parquet]
#
# Description:
#   Automatic prosody extraction pipeline for video or audio.
#
# Supported inputs:
#   - INPUT.mp4 : video with an audio track
#   - INPUT.wav : mono or stereo audio file
#
# Processing steps:
#   1) Prepare paths, filenames and output directory
#   2) Normalize / extract audio
#        - Source-rate WAV for Praat
#        - 16 kHz WAV for Silero VAD
#   3) Silero VAD (voice activity detection)
#   4) Praat (pitch, intensity, formants, harmonicity, point process)
#   5) Timestamps
#        - video: per-frame timestamps from ffprobe
#        - audio: acoustic time grid without video frames
#   6) Final integration in R
#        - mode = "video"
#        - mode = "audio"
#   7) Clean up intermediate files
#
# Output:
#   CSV by default, or Parquet, with:
#     - time
#     - pitch
#     - intensity
#     - harmonicity
#     - formants
#     - VAD
#
# Note:
#   The mode is detected automatically from the extension
#   of the input file (.mp4 -> video, .wav -> audio)

set -e  # Exit on error

# --------------------------------------------------------------------
# --- 0. Validate arguments ---
# --------------------------------------------------------------------
if [ $# -lt 2 ]; then
  echo "Usage: $0 INPUT.mp4|INPUT.wav OUTPUT_DIR [--parquet]"
  exit 1
fi

INPUT="$1"
OUTDIR="$2"
OUTPUT_FORMAT="csv"
if [ "$3" == "--parquet" ]; then
  OUTPUT_FORMAT="parquet"
fi

EXT="${INPUT##*.}"
EXT="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"

if [ "$EXT" != "mp4" ] && [ "$EXT" != "wav" ]; then
  echo "❌ Unsupported format: .$EXT"
  echo "   Use an .mp4 or .wav file"
  exit 1
fi

# --------------------------------------------------------------------
# --- Determine absolute paths and the project root ---
# --------------------------------------------------------------------
# BASEDIR: one level above the 'scripts/' directory containing this script
BASEDIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd -P)"

# Ensure INPUT and OUTDIR are absolute paths
INPUT="$(realpath "$INPUT")"
OUTDIR="$(realpath "$OUTDIR")"

# If local Praat exists in env/praat, add it to PATH
if [ -x "${BASEDIR}/env/praat/praat" ]; then
  export PATH="${BASEDIR}/env/praat:$PATH"
fi

# --------------------------------------------------------------------
# --- 1. Prepare filenames ---
# --------------------------------------------------------------------
BASENAME="$(basename "$INPUT")"
BASENAME="${BASENAME%.*}"

FINALDIR="${OUTDIR}/${BASENAME}"
mkdir -p "$FINALDIR"

rate=$(ffprobe -i "$INPUT" -select_streams a:0 -show_entries stream=sample_rate -v quiet -of csv="p=0") || true
if [ -z "$rate" ]; then
  echo "⚠️  Could not detect the sample rate with ffprobe. Using 44100 Hz by default."
  rate=44100
fi
echo "Detected sample rate (or fallback): ${rate} Hz"

AUDIOWAV="${FINALDIR}/${BASENAME}_${rate}Hz.wav"
AUDIO16K="${FINALDIR}/${BASENAME}_16kHz.wav"
FRAMESCSV="${FINALDIR}/${BASENAME}_frame_timestamps.csv"

if [ "$OUTPUT_FORMAT" == "parquet" ]; then
  OUTFILE_NAME="${BASENAME}_prosody.parquet"
else
  OUTFILE_NAME="${BASENAME}_prosody.csv"
fi

# Normalize absolute paths
FINALDIR="$(realpath "$FINALDIR")"
AUDIOWAV="$(realpath --canonicalize-missing "$AUDIOWAV")"
AUDIO16K="$(realpath --canonicalize-missing "$AUDIO16K")"
FRAMESCSV="$(realpath --canonicalize-missing "$FRAMESCSV")"

# Helper scripts
PRAAT_SCRIPT="${BASEDIR}/scripts/extract_prosody.praat"
RSCRIPT="${BASEDIR}/scripts/process_prosody.R"
SILERO_PY="${BASEDIR}/scripts/silero_vad_runner.py"

# --------------------------------------------------------------------
# --- 2. Prepare audio (from video or WAV) ---
# --------------------------------------------------------------------
if [ "$EXT" = "wav" ]; then
  echo "[Step 2] Normalizing input WAV at rate=$rate Hz → $AUDIOWAV"
  ffmpeg -i "$INPUT" -acodec pcm_s16le -ac 1 -ar "$rate" -y "$AUDIOWAV"

  echo "[Step 2b] Generating a 16 kHz WAV for Silero → $AUDIO16K"
  ffmpeg -i "$INPUT" -acodec pcm_s16le -ac 1 -ar 16000 -y "$AUDIO16K"
else
  echo "[Step 2] Extracting audio at rate=$rate Hz from video → $AUDIOWAV"
  ffmpeg -i "$INPUT" -acodec pcm_s16le -ac 1 -ar "$rate" -y "$AUDIOWAV"

  echo "[Step 2b] Extracting 16 kHz audio for Silero → $AUDIO16K"
  ffmpeg -i "$INPUT" -acodec pcm_s16le -ac 1 -ar 16000 -y "$AUDIO16K"
fi

# Verify that the files were created successfully
if [ ! -s "$AUDIOWAV" ]; then
  echo "❌ File $AUDIOWAV was not generated successfully."
  exit 1
fi
if [ ! -s "$AUDIO16K" ]; then
  echo "❌ File $AUDIO16K was not generated successfully."
  exit 1
fi

# --------------------------------------------------------------------
# --- 3. Silero, 4. Praat, 5. ffprobe timestamps (parallel) ---
# --------------------------------------------------------------------
(
  # STEP 3: SILERO VAD
  echo "[Step 3] Running Silero (optional)..."
  if [ -f "$SILERO_PY" ]; then
    echo "Activating Python environment..."
    source "${BASEDIR}/env/pyenv/bin/activate" 2>/dev/null || echo "⚠️  Could not activate the Python environment. Check your installation."

    echo "🎙️  Running Silero on $AUDIO16K"
    CSVOUT="${AUDIO16K%.wav}_silero_segments.csv"
    python3 "$SILERO_PY" "$AUDIO16K" "$FINALDIR"

    deactivate || true

    if [ -f "$CSVOUT" ]; then
      echo "✅ Silero OK. Segments generated: $CSVOUT"
    else
      echo "⚠️  Silero did not generate the expected CSV. Check the logs."
    fi
  else
    echo "⚠️  $SILERO_PY not found. Skipping VAD."
  fi
) &

(
  # STEP 4: PRAAT
  echo "[Step 4] Running Praat → $AUDIOWAV"
  if ! command -v praat &>/dev/null; then
    echo "❌ 'praat' is not in PATH. Install it or update PATH."
    exit 1
  fi

  if [ ! -f "$PRAAT_SCRIPT" ]; then
    echo "❌ Could not find $PRAAT_SCRIPT."
    exit 1
  fi

  if [ ! -s "$AUDIOWAV" ]; then
    echo "❌ Praat input WAV is missing or empty: $AUDIOWAV"
    exit 1
  fi

  praat --run "$PRAAT_SCRIPT" "$AUDIOWAV" "$FINALDIR"
) &

(
  # STEP 5: TIMESTAMPS (video only)
  if [ "$EXT" = "mp4" ]; then
    echo "[Step 5] Extracting timestamps with ffprobe → $FRAMESCSV"
    ffprobe -v error -select_streams v:0 -show_entries frame=pts_time \
      -of csv=p=0 "$INPUT" |
    awk 'BEGIN{print "frame_id,frame_timestamp"} {printf "%d,%.6f\n", NR-1, $1}' > "$FRAMESCSV"

    if [ ! -s "$FRAMESCSV" ]; then
      echo "❌ Error: $FRAMESCSV was not generated"
      exit 1
    fi
  else
    echo "[Step 5] Audio-only input; skipping video frame timestamps."
  fi
) &

# Wait for STEPS 3, 4 and 5 to finish
wait

# --------------------------------------------------------------------
# --- 6. Run Rscript (process_prosody.R) ---
# --------------------------------------------------------------------
echo "[Step 6] Running Rscript to generate the final file: $OUTFILE_NAME"

if [ ! -f "$RSCRIPT" ]; then
  echo "❌ Could not find $RSCRIPT."
  exit 1
fi
if ! command -v Rscript &>/dev/null; then
  echo "❌ 'Rscript' is not in PATH. Install it or update PATH."
  exit 1
fi

if [ "$EXT" = "mp4" ]; then
  MODE="video"
else
  MODE="audio"
fi

R_LIBS_USER="${BASEDIR}/env/Rlibs" Rscript "$RSCRIPT" "$FINALDIR" "$OUTFILE_NAME" "$MODE"
echo "✅ Rscript completed. Final file generated: $OUTFILE_NAME"

# --------------------------------------------------------------------
# --- 7. Clean up intermediate files ---
# --------------------------------------------------------------------
echo "[Step 7] Cleaning up intermediate files in $FINALDIR..."
rm -f "${FINALDIR}"/*.Pitch \
      "${FINALDIR}"/*.Intensity \
      "${FINALDIR}"/*.Formant \
      "${FINALDIR}"/*.Harmonicity \
      "${FINALDIR}"/*.PointProcess \
      "${FINALDIR}"/*.wav \
      "${FINALDIR}"/*_frame_timestamps.csv \
      "${FINALDIR}"/*_silero_segments.csv 2>/dev/null || true

echo "✅ Processing COMPLETE. Final file: ${FINALDIR}/${OUTFILE_NAME}"
