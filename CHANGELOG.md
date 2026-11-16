## Sin publicar / Unreleased

### Fixed / Corregido · 2026-11-16

| EN | ES |
| --- | --- |
| **Align cubic interpolation with the documented method.** Replace `fmm` (Forsythe–Malcolm–Moler) with explicit Fritsch–Butland PCHIP interior slopes and one-sided endpoint conditions. Preserve per-frame cubic estimates, gap coverage, endpoint polynomial extrapolation and the minimum-track policy. Clarify the historical PDF attribution and C1 continuity in README. No Daedalus linear interpolation is imported. | **Alinear la interpolación cúbica con el método documentado.** Se sustituye `fmm` (Forsythe–Malcolm–Moler) por PCHIP con pendientes interiores de Fritsch–Butland y condiciones unilaterales en extremos. Se conservan las estimaciones por fotograma, la cobertura de huecos, la extrapolación cúbica de bordes y el mínimo de observaciones. README corrige la atribución del PDF y aclara la continuidad C1. No se incorpora la interpolación lineal de Daedalus. |
| **Pin Praat barren 6.4.60.** Download from the official historical GitHub release for Linux Intel64/ARM64 and verify the local binary version instead of discovering the latest release. | **Fijar Praat barren 6.4.60.** Descarga histórica oficial para Linux Intel64/ARM64 y verificación de la versión local, sin búsqueda de la última release. |
| **Restore optional local CPU VAD.** Document CPU and runtime requirements; decode normalized WAV through SoundFile to avoid the TorchCodec requirement. Keep CSV headers when no speech is detected. | **Recuperar VAD local opcional en CPU.** Documenta requisitos CPU y de ejecución; lee WAV normalizado con SoundFile para evitar TorchCodec. Conserva cabeceras CSV cuando no se detecta voz. |

### Added / Añadido · 2026-11-16

| EN | ES |
| --- | --- |
| **Specific cubic CI tests.** Compare against SciPy PCHIP on irregular grids, plateaus and extrema; check exact knots, frame/gap/edge coverage, no interior overshoot, missing values and a cubic-vs-linear discriminating fixture. Install CPU VAD into PAROLE's actual environment and require populated VAD in the video smoke test. | **Pruebas CI específicas de cúbica.** Comparación con SciPy PCHIP en rejillas irregulares, mesetas y extremos; nodos exactos, cobertura de fotogramas/huecos/bordes, ausencia de sobreoscilación interior y datos ausentes. Un caso distingue cúbica de lineal. CI instala VAD CPU en el entorno real de PAROLE y exige resultados VAD en el vídeo. |
| **Local audio support.** Include the existing local WAV-input changes alongside MP4 processing. | **Soporte local de audio.** Incorpora los cambios locales existentes para entrada WAV además de MP4. |

## 1.1.1  ·  2025-06-20

### Fixed / Corregido · 2025-06-27

| EN                                                                                                                                                                                                    | ES                                                                                                                                                                                                             |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Frame 0 preserved in prosody pipeline** – Removed hard-coded deletion of the first row from `*_frame_timestamps.csv` in `process_prosody.R`. With FFmpeg 7.1+, this workaround is no longer needed. | **Preservación del frame 0 en la tubería prosódica** – Se eliminó el borrado forzado de la primera fila de `*_frame_timestamps.csv` en `process_prosody.R`. Con FFmpeg 7.1+, esta solución ya no es necesaria. |

### Fixed / Corregido · 2025-06-23

| EN                                                                                                                                                                                                                                        | ES                                                                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Timestamp field migrated to `pts_time`** – The `ffprobe` call in `parole.sh` now uses `pts_time` instead of `pkt_pts_time` to restore stability under FFmpeg 7.1+, ensuring compatibility across formats and preventing silent failure. | **Campo de marca de tiempo migrado a `pts_time`** – La llamada a `ffprobe` en `parole.sh` ahora utiliza `pts_time` en lugar de `pkt_pts_time` para recuperar estabilidad en FFmpeg 7.1+, garantizando compatibilidad entre formatos y evitando fallos silenciosos. |

### Fixed / Corregido · 2025-06-20

| EN                                                                                                                                                                                                                                                   | ES                                                                                                                                                                                                                                                                          |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Robust timestamp extraction** – The `ffprobe` call in `parole.sh` has been rewritten to emit a clean list of `pkt_pts_time` values, eliminating empty or malformed lines in `*_frame_timestamps.csv`.                                              | **Extracción robusta de marcas de tiempo** – Se ha reescrito la llamada a `ffprobe` en `parole.sh` para que genere una lista limpia de `pkt_pts_time`, evitando líneas vacías o mal formateadas en `*_frame_timestamps.csv`.                                                |
| **Installer steps restored** – `install_parole.sh` now reliably (re)creates the Python virtual-env `env/pyenv` and installs dependencies from `requirements_python.txt`; the R library folder `env/Rlibs` is likewise re-initialised when requested. | **Pasos del instalador restaurados** – `install_parole.sh` vuelve a (re)crear correctamente el entorno virtual Python `env/pyenv` e instala dependencias desde `requirements_python.txt`; la carpeta de librerías R `env/Rlibs` también se reinicializa cuando se solicita. |

---

Previous versions are tracked in the project’s Git history.
Las versiones anteriores se encuentran en el historial Git del proyecto.

