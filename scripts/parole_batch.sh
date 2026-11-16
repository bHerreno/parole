#!/usr/bin/env bash
#
# Usage:
#   ./scripts/parole_batch.sh data/videos resultados [--parquet]
#
# This script runs `parole.sh` on every .mp4 video in the specified directory,
# and saves results in subdirectories of the output directory.

# --------------------------------------------------------------------
# --- 0. Validate arguments ---
# --------------------------------------------------------------------
if [ $# -lt 2 ]; then
  echo "Usage: $0 <video_directory> <output_directory> [--parquet]"
  exit 1
fi

VIDEODIR="$1"
OUTDIR="$2"
FORMAT_FLAG=""

if [ "$3" == "--parquet" ]; then
  FORMAT_FLAG="--parquet"
fi

# Absolute path to this script's directory (to locate parole.sh)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create the output directory if needed
mkdir -p "$OUTDIR"

# Find .mp4 files
mapfile -t VIDEO_FILES < <(find "$VIDEODIR" -type f -name "*.mp4" | sort)

TOTAL=${#VIDEO_FILES[@]}
COUNT=0
FAILS=0

# --------------------------------------------------------------------
# --- 1. Process each file ---
# --------------------------------------------------------------------
echo "🧪 Processing $TOTAL videos from '$VIDEODIR'..."
echo ""

for VIDEO in "${VIDEO_FILES[@]}"; do
  ((COUNT++))
  BASENAME=$(basename "$VIDEO")
  echo "[$COUNT/$TOTAL] ▶ Processing: $BASENAME"

  "$SCRIPT_DIR/parole.sh" "$VIDEO" "$OUTDIR" $FORMAT_FLAG

  if [ $? -ne 0 ]; then
    echo "   ❌ Error processing $BASENAME"
    ((FAILS++))
  else
    echo "   ✅ Complete"
  fi

  echo ""
done

# --------------------------------------------------------------------
# --- 2. Final summary ---
# --------------------------------------------------------------------
SUCCESS=$((TOTAL - FAILS))
echo "🎉 Processing finished: $SUCCESS / $TOTAL completed successfully."
if [ "$FAILS" -gt 0 ]; then
  echo "⚠️  $FAILS files failed. Check the logs above."
fi
