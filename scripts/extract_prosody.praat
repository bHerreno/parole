form Extract full prosody (high resolution, rPraat-friendly)
  sentence audiofile ""   ; WAV file to process
  sentence outdir ""      ; Output directory
endform

# Read and duplicate the audio
Read from file: "'audiofile$'"
printline: "🛠️ Received audiofile$: ", audiofile$

Rename: "original"
selectObject: "Sound original"
Copy: "sound_main"

# ---------------------
# 1. Pitch → .Pitch (text format)
selectObject: "Sound sound_main"
To Pitch: 0.001, 60, 600
selectObject: selected("Pitch")
Write to text file: "'outdir$'/pitch.Pitch"

# ---------------------
# 2. Intensity → .Intensity (text format)
selectObject: "Sound sound_main"
To Intensity: 75, 0.001, "yes"
selectObject: selected("Intensity")
Write to text file: "'outdir$'/intensity.Intensity"

# ---------------------
# 3. Formants → .Formant (text format)
selectObject: "Sound sound_main"
To Formant (burg): 0.001, 5, 5500, 0.025, 50
selectObject: selected("Formant")
Write to text file: "'outdir$'/formants.Formant"

# ---------------------
# 4. Harmonicity → .Harmonicity (text format)
selectObject: "Sound sound_main"
To Harmonicity (cc): 0.01, 75, 0.1, 1.0
selectObject: selected("Harmonicity")
Write to text file: "'outdir$'/harmonicity.Harmonicity"

# ---------------------
# 5. PointProcess → .PointProcess (text format)
selectObject: "Sound sound_main"
To PointProcess (periodic, cc): 75, 500
selectObject: selected("PointProcess")
Write to text file: "'outdir$'/pointprocess.PointProcess"

