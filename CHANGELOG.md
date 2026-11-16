# Changelog / Historial de cambios

## 2026-11-16

### English

- Pin and verify local Praat barren **6.4.60** from the official historical release for Linux Intel64/ARM64.
- Replace R's FMM spline with explicit **PCHIP** cubic interpolation, using Fritsch–Butland interior slopes. This changes the numerical method: PCHIP is C1, whereas FMM is C2. Retain gap estimates, cubic endpoint extrapolation and the existing minimum-observation and low-pitch rules.
- Document the provisional preference for PCHIP and the need for C2 when studying a continuous second derivative. The manual includes the corrected attribution and a dated discussion footnote.
- Add nine cubic interpolation regression tests with SciPy as an independent reference, including cases that distinguish cubic interpolation from linear interpolation.
- Support local WAV input alongside MP4. Restore optional CPU Silero VAD using SoundFile and document its runtime requirements. Preserve CSV headers when no speech is detected.
- Add a traceable synthetic English audio fixture and full video CI validation for timestamps, known acoustic values and VAD. Publish synthetic results and provenance reports as CI artifacts.
- Replace the previous PDF with the revised manual and include its Quarto sources. Keep the methods table on one page and wrap the timestamp command within its code block.
- Run push CI on main only, retain pull-request checks and automatically cancel superseded runs for the same branch or pull request.
- Reorganize the README into an English guide and a linked Spanish version, retaining the original cover and badges.

### Español

- Fija y verifica **Praat barren 6.4.60** local desde la release histórica oficial para Linux Intel64/ARM64.
- Sustituye FMM de R por interpolación cúbica **PCHIP**, con pendientes interiores de Fritsch–Butland. Es un cambio numérico: PCHIP es C1 y FMM es C2. Conserva estimaciones en huecos, extrapolación cúbica y las reglas de observaciones mínimas y pitch bajo.
- Explica la preferencia provisional por PCHIP y la necesidad de C2 en estudios que requieren continuidad de la segunda derivada. El manual incorpora la atribución corregida y la discusión en una nota al pie fechada.
- Añade nueve pruebas de regresión cúbica con SciPy como referencia independiente, incluyendo casos que distinguen cúbica de lineal.
- Admite WAV local además de MP4. Recupera Silero VAD opcional en CPU mediante SoundFile y documenta requisitos. Conserva cabeceras CSV si no se detecta voz.
- Añade audio sintético en inglés trazable y validación CI de vídeo, tiempos, medidas conocidas y VAD. Los artefactos de CI contienen resultados sintéticos e informes de procedencia.
- Sustituye el PDF anterior por el manual revisado e incorpora sus fuentes Quarto. Mantiene la tabla de métodos en una página y ajusta el comando de tiempos dentro de su bloque.
- Ejecuta CI por push solo en main, conserva las comprobaciones de pull requests y cancela automáticamente ejecuciones anteriores de la misma rama o pull request.
- Reorganiza el README en inglés con versión española enlazada, conservando la portada y los distintivos originales.

## 2026-01-10

Recorded retrospectively from the January changes / Recogido retrospectivamente de los cambios de enero.

- **EN:** Move torch/torchaudio out of general dependencies to avoid CUDA installations exhausting CI storage; add CPU requirements pinned to 2.9.1. Consolidate CI in `parole-ci.yml` and document optional Silero installation. Update authorship, funding and contact information.
- **ES:** Separa torch/torchaudio de las dependencias generales para evitar agotar el disco de CI con CUDA; añade requisitos CPU fijados a 2.9.1. Unifica CI en `parole-ci.yml` y documenta Silero opcional. Actualiza autoría, financiación y contacto.

## 1.1.1 · 2025-06-20

### 2025-06-27

- **EN:** Preserve frame 0 by removing the forced deletion of the first timestamp row; the workaround was no longer needed with FFmpeg 7.1+.
- **ES:** Conserva el fotograma 0 al eliminar el borrado forzado de la primera fila de tiempos, innecesario con FFmpeg 7.1+.

### 2025-06-23

- **EN:** Switch ffprobe timestamp extraction from `pkt_pts_time` to `pts_time` for FFmpeg 7.1+ compatibility.
- **ES:** Cambia la extracción de tiempos de ffprobe de `pkt_pts_time` a `pts_time` para compatibilidad con FFmpeg 7.1+.

### 2025-06-20

- **EN:** Clean up timestamp extraction to avoid empty or malformed rows. Restore creation of the Python environment and dependency installation, and optional reinitialization of the R library directory.
- **ES:** Corrige la extracción de tiempos para evitar filas vacías o mal formadas. Recupera la creación del entorno Python, instalación de dependencias y reinicialización opcional de la biblioteca de R.
