<p align="center">
  <img src="images/logo_parole.png" alt="PAROLE logo" width="50%">
</p>

<p align="center">
  <a href="https://doi.org/10.5281/zenodo.15522925">
    <img src="https://zenodo.org/badge/964120256.svg" alt="DOI">
  </a>
  <a href="https://github.com/bHerreno/parole/actions/workflows/parole-ci.yml">
    <img src="https://github.com/bHerreno/parole/actions/workflows/parole-ci.yml/badge.svg" alt="PAROLE CI (cubic interpolation and CPU VAD)">
  </a>
</p>

Extract prosodic measurements and voice activity from MP4 video or WAV audio using Praat, FFmpeg, R and optional Silero VAD.

[Español](docs/README.es.md) · [Changelog](CHANGELOG.md) · [DOI](https://doi.org/10.5281/zenodo.15522925)

## Install

The installer targets Linux (x86-64 or ARM64). Install Python 3 with venv/pip, R, FFmpeg/ffprobe, curl and tar first. R packages may also require system development libraries; the [CI workflow](.github/workflows/parole-ci.yml) provides a tested Ubuntu setup.

Run all commands from the repository root:

```bash
bash install_parole.sh
```

The installer uses local environments under `env/` and pins **Praat barren 6.4.60** from the [official historical release](https://github.com/praat/praat.github.io/releases/tag/v6.4.60). It verifies the local binary version and uses `env/praat/praat`, independently of system Praat.

For optional **Silero VAD on CPU**, install into the same Python environment:

```bash
env/pyenv/bin/python -m pip install -r requirements_silero_cpu.txt
env/pyenv/bin/python -m pip install -r requirements_silero_local.txt
```

CPU inference is working and covered by CI. Audio is decoded with SoundFile to avoid a TorchCodec dependency. The first run downloads the model from Torch Hub and requires internet access. The model currently follows `snakers4/silero-vad`'s `master` branch; it is not version-pinned. The synthetic validation report records its checksum.

## Process your files

```bash
mkdir -p resultados
bash scripts/parole.sh "path/to/video.mp4" resultados --parquet
bash scripts/parole.sh "path/to/audio.wav" resultados
bash scripts/parole_batch.sh "path/to/videos" resultados --parquet
```

CSV is the default output; `--parquet` selects Parquet. Batch processing recursively finds MP4 files. Outputs include pitch, intensity, harmonicity, formant frequencies/bandwidths and, when enabled, voice activity.

For video, ffprobe supplies the actual frame timestamps and PAROLE aligns acoustic measurements to those times, retaining one row per frame. WAV input uses an acoustic time grid rather than video frames. Outputs and environments stay local under `resultados/` and `env/`.

## Interpolation and research use

The production pipeline performs interpolation in **R** (`scripts/interpolate_cubic.R`). SciPy is used only in the regression tests as an independent numerical reference; it does not perform interpolation during normal processing.

The current implementation uses **piecewise cubic Hermite interpolation (PCHIP)**, with Fritsch–Butland interior slopes and one-sided endpoint slopes. This is a provisional methodological choice while the effects of FMM overshoot on measurements and downstream analyses remain to be evaluated.[^interpolation]

PCHIP is **C1**: the curve and its first derivative are continuous, but the second derivative may jump at knots. Within the measured range it preserves shape without introducing overshoot between adjacent observations. This guarantee does **not** apply to the cubic endpoint extrapolation used outside that range.

The pipeline still estimates values across gaps and at frame timestamps beyond the measured endpoints; these are estimates, not additional acoustic observations. Tracks with fewer than four valid observations produce `NA`. The existing rule converting pitch below 10 Hz to zero is retained. Interpret gaps, boundaries and derivative-based results with these limitations in mind.

[^interpolation]: Methodological clarification, **2026-11-16**. R's `splinefun(method = "fmm")` implements **Forsythe–Malcolm–Moler**, not Fritsch–Butland. FMM provides C2 continuity but can overshoot; the magnitude depends on the data. A C2 method is needed when a study specifically requires a continuous second derivative, but continuity alone does not establish scientific validity. PCHIP is retained provisionally until the consequences of overshoot are assessed. For pitch measured in Hz, the second time derivative has units Hz/s² and describes changes in the pitch slope, not physical vocal-fold acceleration. The manual incorporates this clarification in its methodological discussion and dated footnote.

Algorithm references: [Fritsch–Butland (1984)](https://doi.org/10.1137/0905021), [SciPy PCHIP](https://docs.scipy.org/doc/scipy/reference/generated/scipy.interpolate.PchipInterpolator.html), [R splinefun](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/splinefun.html).

## Reproduce the synthetic example

The included [English WAV](tests/fixtures/synthetic_en.wav) contains generated tones, a chirp and synthesized speech, with no human recording. Its [manifest](tests/fixtures/synthetic_en.json) records the checksum, timeline and generation parameters. You can process it directly with the WAV command above.

To reproduce the video validation used by CI, after installation:

```bash
env/pyenv/bin/python -m pip install -r requirements_test.txt
env/pyenv/bin/python -m pytest tests/test_cubic_interpolation.py
mkdir -p resultados
ffmpeg -v error -f lavfi -i color=c=black:s=320x240:r=30 \
  -i tests/fixtures/synthetic_en.wav -c:v mpeg4 -q:v 5 -pix_fmt yuv420p \
  -c:a aac -b:a 128k -shortest resultados/synthetic_en.mp4
bash scripts/parole.sh resultados/synthetic_en.mp4 resultados --parquet
env/pyenv/bin/python tests/validate_synthetic_output.py
```

Install the optional CPU VAD requirements above before this validation. CI checks cubic interpolation against SciPy, frame alignment, known tone/chirp values and synthetic speech detection. It uploads only the synthetic Parquet results and validation JSON, which includes checksums and tool versions. These checks establish reproducibility for this example, not accuracy on all recordings.

Optional regeneration requires eSpeak NG and FFmpeg:

```bash
python3 scripts/generate_synthetic_fixture.py --output resultados/regenerated.wav
```

**Evaluation data:** The distributed example and CI use synthetic media. You can evaluate PAROLE with your own recordings and contribute other evaluation datasets or results, provided you have the necessary rights and consent to share them. Check recordings and derived outputs for identifying information before publishing.

## Documentation, authorship and license

The [technical manual](_book/Parole--Ecosistema-Funcional.pdf) includes the methodological clarification dated 2026-11-16, alongside the theoretical background.

PAROLE was originally developed by Daedalus Lab as part of MULTIFLOW, funded by the Ministry of Science, Innovation, and Universities of Spain. This repository is **Brian Herreño Jiménez**'s research fork ([contact](mailto:brian.herreno@gmail.com)). The shared project is maintained at [daedalusLAB/parole](https://github.com/daedalusLAB/parole).

Distributed under [GPL-3](https://www.gnu.org/licenses/gpl-3.0.html).
