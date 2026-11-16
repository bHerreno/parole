#!/usr/bin/env Rscript

# PAROLE: Speech prosody processing script
# Copyright (C) 2025-2026 Brian Herreño Jiménez & Cristóbal Pagán Cánovas
#
# Distributed under the GNU General Public License v3 or later.
# See the repository LICENSE file for details.

# -------------------------------------------------------------
# Ensure that 'arrow', the only external R dependency, is installed
# -------------------------------------------------------------
if (!requireNamespace("arrow", quietly = TRUE)) {
  stop("The 'arrow' package is required to write Parquet files. Install it with install.packages('arrow')")
}

# -------------------------------------------------------------
# Load 'parallel', included with R (no additional installation required)
# -------------------------------------------------------------
suppressWarnings(suppressMessages({
  library(parallel)
}))

#######################################################################
# process_prosody.R
#
# Usage:
#   Rscript process_prosody.R <input_dir> <out_file> <mode>
#
# Where:
#   - <input_dir>: directory containing:
#       - Praat .Pitch, .Formant and related files
#       - Timestamp CSV (_frame_timestamps.csv) [video mode only]
#       - (Optional) Silero CSV (_silero_segments.csv)
#   - <out_file>: Output filename (e.g. .csv or .parquet)
#   - <mode>: "video" or "audio"
#
#######################################################################

# --- 0. Parse arguments ---
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: Rscript process_prosody.R <input_dir> <out_file> <mode: video|audio>", call. = FALSE)
}
input_dir <- args[1]
out_file  <- args[2]
mode      <- tolower(args[3])

if (!mode %in% c("video", "audio")) {
  stop("The third argument must be 'video' or 'audio'.", call. = FALSE)
}

# Maximum number of formants
max_formants <- 5

#######################################################################
# 1. Parsing helpers: Pitch, Intensity, Formant and related objects
#######################################################################
parse_praat_pitch <- function(files) {
  if (length(files) == 0) return(NULL)

  parse_one_pitch <- function(file) {
    lines <- readLines(file)

    x1 <- as.numeric(sub("x1 = ", "", lines[grep("^x1 =", lines)]))
    dx <- as.numeric(sub("dx = ", "", lines[grep("^dx =", lines)]))

    data_list <- list()
    frame_lines <- grep("^    frames \\[", lines)

    for (i in seq_along(frame_lines)) {
      line_i <- frame_lines[i]
      time   <- x1 + (i - 1) * dx

      intensity_pitch <- as.numeric(gsub(".*= ", "", lines[line_i + 1]))
      n_candidates    <- as.numeric(gsub(".*= ", "", lines[line_i + 2]))

      if (n_candidates < 1) {
        data_list[[i]] <- data.frame(
          time = time,
          intensity_pitch = intensity_pitch,
          pitch = NA,
          strength_pitch = NA
        )
        next
      }

      frame_block <- lines[
        (line_i + 3):(ifelse(i < length(frame_lines), frame_lines[i + 1] - 1, length(lines)))
      ]

      cand1_idx <- grep("^\\s+candidates \\[1\\]:", frame_block)
      if (length(cand1_idx) == 0) {
        pitch_val <- NA
        strength_pitch <- NA
      } else {
        freq_line <- frame_block[cand1_idx + 1]
        strg_line <- frame_block[cand1_idx + 2]
        pitch_val <- as.numeric(gsub(".*= ", "", freq_line))
        strength_pitch <- as.numeric(gsub(".*= ", "", strg_line))
      }

      data_list[[i]] <- data.frame(
        time = time,
        intensity_pitch = intensity_pitch,
        pitch = pitch_val,
        strength_pitch = strength_pitch
      )
    }
    do.call(rbind, data_list)
  }

  df_list <- lapply(files, parse_one_pitch)
  do.call(rbind, df_list)
}

parse_praat_intensity <- function(files) {
  if (length(files) == 0) return(NULL)

  parse_one_intensity <- function(file) {
    lines <- readLines(file)
    x1 <- as.numeric(sub("x1 = ", "", lines[grep("^x1 =", lines)]))
    dx <- as.numeric(sub("dx = ", "", lines[grep("^dx =", lines)]))

    z_start <- grep("z \\[\\]\\ \\[\\]:", lines)
    z_lines <- lines[(z_start + 2):length(lines)]
    z_vals  <- as.numeric(gsub(".*= ", "", z_lines))

    times <- seq(from = x1, by = dx, length.out = length(z_vals))
    data.frame(time = times, intensity = z_vals)
  }

  df_list <- lapply(files, parse_one_intensity)
  do.call(rbind, df_list)
}

parse_praat_harmonicity <- function(files) {
  if (length(files) == 0) return(NULL)

  parse_one_harmo <- function(file) {
    lines <- readLines(file)
    x1 <- as.numeric(sub("x1 = ", "", lines[grep("^x1 =", lines)]))
    dx <- as.numeric(sub("dx = ", "", lines[grep("^dx =", lines)]))

    z_start <- grep("z \\[\\]\\ \\[\\]:", lines)
    z_lines <- lines[(z_start + 2):length(lines)]
    z_vals  <- as.numeric(gsub(".*= ", "", z_lines))

    times <- seq(from = x1, by = dx, length.out = length(z_vals))
    data.frame(time = times, harmonicity = z_vals)
  }

  df_list <- lapply(files, parse_one_harmo)
  do.call(rbind, df_list)
}

parse_praat_formant <- function(files, max_formants = 5) {
  if (length(files) == 0) return(NULL)

  parse_one_formant <- function(file) {
    lines <- readLines(file)
    x1 <- as.numeric(sub("x1 = ", "", lines[grep("^x1 =", lines)]))
    dx <- as.numeric(sub("dx = ", "", lines[grep("^dx =", lines)]))

    frame_lines <- grep("^\\s+frames \\[", lines)
    data_list <- vector("list", length(frame_lines))

    for (i in seq_along(frame_lines)) {
      time <- x1 + (i - 1) * dx
      start <- frame_lines[i]
      end   <- if (i < length(frame_lines)) frame_lines[i + 1] - 1 else length(lines)
      frame_block <- lines[start:end]

      intensity_line <- grep("^\\s+intensity = ", frame_block, value = TRUE)
      intensity_val  <- if (length(intensity_line) > 0) as.numeric(gsub(".*= ", "", intensity_line)) else NA

      row <- list(time = time, intensity = intensity_val)

      for (f in seq_len(max_formants)) {
        f_block <- grep(sprintf("^\\s+formant \\[%d\\]:", f), frame_block)
        if (length(f_block) == 0) {
          row[[paste0("formant.", f, "_frequency")]] <- NA
          row[[paste0("formant.", f, "_bandwidth")]] <- NA
        } else {
          freq_line <- frame_block[f_block + 1]
          bw_line   <- frame_block[f_block + 2]
          row[[paste0("formant.", f, "_frequency")]] <- as.numeric(gsub(".*= ", "", freq_line))
          row[[paste0("formant.", f, "_bandwidth")]] <- as.numeric(gsub(".*= ", "", bw_line))
        }
      }
      data_list[[i]] <- as.data.frame(row)
    }
    do.call(rbind, data_list)
  }

  df_list <- lapply(files, parse_one_formant)
  do.call(rbind, df_list)
}

parse_praat_pointprocess <- function(files) {
  if (length(files) == 0) return(NULL)

  parse_one_pp <- function(file) {
    lines <- readLines(file)
    t_start <- grep("^t \\[\\]:", lines)
    t_lines <- lines[(t_start + 1):length(lines)]

    t_vals <- as.numeric(gsub(".*= ", "", t_lines))
    data.frame(time = t_vals)
  }

  df_list <- lapply(files, parse_one_pp)
  do.call(rbind, df_list)
}

#######################################################################
# 2. Parse all tracks in parallel
#######################################################################
parse_all_tasks_in_parallel <- function(dir, max_formants = 5) {
  pitch_files        <- list.files(dir, pattern = "\\.Pitch$",        full.names = TRUE)
  intensity_files    <- list.files(dir, pattern = "\\.Intensity$",    full.names = TRUE)
  harmonicity_files  <- list.files(dir, pattern = "\\.Harmonicity$",  full.names = TRUE)
  formant_files      <- list.files(dir, pattern = "\\.Formant(s)?$",  full.names = TRUE)
  pointprocess_files <- list.files(dir, pattern = "\\.PointProcess$", full.names = TRUE)

  tasks <- list(
    pitch = function() parse_praat_pitch(pitch_files),
    intensity = function() parse_praat_intensity(intensity_files),
    harmonicity = function() parse_praat_harmonicity(harmonicity_files),
    formant = function() parse_praat_formant(formant_files, max_formants),
    pointprocess = function() parse_praat_pointprocess(pointprocess_files)
  )

  results <- mclapply(tasks, function(f) f(), mc.cores = length(tasks))
  names(results) <- names(tasks)
  results
}

#######################################################################
# 3. Utilities
#######################################################################
# Load the explicitly named Fritsch–Butland implementation (not stats::fmm).
script_arg <- grep("^--file=", commandArgs(), value = TRUE)[1]
script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg)))
source(file.path(script_dir, "interpolate_cubic.R"))

build_audio_time_grid <- function(prosody_data) {
  candidate_times <- c()

  if (!is.null(prosody_data$pitch) && "time" %in% names(prosody_data$pitch)) {
    candidate_times <- c(candidate_times, prosody_data$pitch$time)
  }
  if (!is.null(prosody_data$intensity) && "time" %in% names(prosody_data$intensity)) {
    candidate_times <- c(candidate_times, prosody_data$intensity$time)
  }
  if (!is.null(prosody_data$harmonicity) && "time" %in% names(prosody_data$harmonicity)) {
    candidate_times <- c(candidate_times, prosody_data$harmonicity$time)
  }
  if (!is.null(prosody_data$formant) && "time" %in% names(prosody_data$formant)) {
    candidate_times <- c(candidate_times, prosody_data$formant$time)
  }
  if (!is.null(prosody_data$pointprocess) && "time" %in% names(prosody_data$pointprocess)) {
    candidate_times <- c(candidate_times, prosody_data$pointprocess$time)
  }

  candidate_times <- sort(unique(candidate_times[!is.na(candidate_times)]))

  if (length(candidate_times) == 0) {
    stop("❌ Could not infer prosodic timestamps for audio mode.")
  }

  data.frame(time = candidate_times)
}

#######################################################################
# 4. Load auxiliary data
#######################################################################

# Parse prosody first
prosody_data <- parse_all_tasks_in_parallel(input_dir, max_formants)

# Timestamps are used only in video mode
df_timestamps <- NULL
if (mode == "video") {
  timestamps_csv <- list.files(input_dir, pattern = "_frame_timestamps\\.csv$", full.names = TRUE)
  if (length(timestamps_csv) == 0) {
    stop("❌ No '_frame_timestamps.csv' found in ", input_dir)
  } else if (length(timestamps_csv) > 1) {
    warning("⚠️ Multiple timestamp CSV files found. Using the first:\n", timestamps_csv[1])
  }
  timestamps_csv <- timestamps_csv[1]

  df_timestamps <- read.csv(timestamps_csv)
  row.names(df_timestamps) <- NULL
}

# Silero CSV
silero_csv_path <- list.files(input_dir, pattern = "_silero_segments\\.csv$", full.names = TRUE)
df_silero <- if (length(silero_csv_path) == 1) {
  read.csv(silero_csv_path, stringsAsFactors = FALSE)
} else {
  if (length(silero_csv_path) > 1) {
    warning("⚠️ Multiple '_silero_segments.csv' files found. Using the first.")
  } else {
    warning("❌ Silero VAD not found. Skipping it.")
  }
  NULL
}

#######################################################################
# 5. Build df_final for the selected mode
#######################################################################
if (mode == "video") {
  df_final <- df_timestamps
  df_final$time <- df_final$frame_timestamp
} else {
  df_final <- build_audio_time_grid(prosody_data)
}

target_times <- df_final$time

#######################################################################
# 6. Interpolate prosodic variables
#######################################################################

# 6a. Pitch
if (!is.null(prosody_data$pitch)) {
  df_final$pitch <- interpolate_spline(
    prosody_data$pitch$time,
    prosody_data$pitch$pitch,
    target_times
  )
  df_final$pitch[df_final$pitch < 10] <- 0

  df_final$intensity_pitch <- interpolate_spline(
    prosody_data$pitch$time,
    prosody_data$pitch$intensity_pitch,
    target_times
  )

  df_final$strength_pitch <- interpolate_spline(
    prosody_data$pitch$time,
    prosody_data$pitch$strength_pitch,
    target_times
  )
} else {
  df_final$pitch <- NA
  df_final$intensity_pitch <- NA
  df_final$strength_pitch <- NA
}

# 6b. Intensity
if (!is.null(prosody_data$intensity)) {
  df_final$intensity <- interpolate_spline(
    prosody_data$intensity$time,
    prosody_data$intensity$intensity,
    target_times
  )
} else {
  df_final$intensity <- NA
}

# 6c. Harmonicity
if (!is.null(prosody_data$harmonicity)) {
  df_final$harmonicity <- interpolate_spline(
    prosody_data$harmonicity$time,
    prosody_data$harmonicity$harmonicity,
    target_times
  )
} else {
  df_final$harmonicity <- NA
}

# 6d. Formants F1..F5
if (!is.null(prosody_data$formant)) {
  for (i in seq_len(max_formants)) {
    freq_col <- paste0("formant.", i, "_frequency")
    bw_col   <- paste0("formant.", i, "_bandwidth")

    if (freq_col %in% names(prosody_data$formant)) {
      df_final[[freq_col]] <- interpolate_spline(
        prosody_data$formant$time,
        prosody_data$formant[[freq_col]],
        target_times
      )
    } else {
      df_final[[freq_col]] <- NA
    }

    if (bw_col %in% names(prosody_data$formant)) {
      df_final[[bw_col]] <- interpolate_spline(
        prosody_data$formant$time,
        prosody_data$formant[[bw_col]],
        target_times
      )
    } else {
      df_final[[bw_col]] <- NA
    }
  }
} else {
  for (i in seq_len(max_formants)) {
    df_final[[paste0("formant.", i, "_frequency")]] <- NA
    df_final[[paste0("formant.", i, "_bandwidth")]] <- NA
  }
}

# 6e. VAD
if (!is.null(df_silero) && all(c("start", "end") %in% names(df_silero))) {
  df_final$vad <- sapply(df_final$time, function(t) {
    any(t >= df_silero$start & t <= df_silero$end)
  })
} else {
  df_final$vad <- NA
}

#######################################################################
# 7. Save as CSV or Parquet
#######################################################################
out_path <- file.path(input_dir, out_file)

if (grepl("\\.parquet$", tolower(out_file))) {
  arrow::write_parquet(df_final, out_path)
  message("✅ Processing complete. Parquet file saved to: ", out_path)
} else if (grepl("\\.csv$", tolower(out_file))) {
  write.csv(df_final, out_path, row.names = FALSE)
  message("✅ Processing complete. Final CSV saved to: ", out_path)
} else {
  warning("⚠️ Unrecognized file extension. Saving as CSV by default.")
  write.csv(df_final, out_path, row.names = FALSE)
  message("✅ Processing complete. File saved as CSV to: ", out_path)
}
