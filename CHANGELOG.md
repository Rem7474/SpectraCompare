# Changelog

All notable changes to this project are documented in this file.

## [0.0.1] - 2026-08-02

Première release publique — implémentation complète du scope v1 du README.

### Ajouté
- Générateur de signaux : sweep sinusoïdal (linéaire/log), bruit rose, bruit blanc, burst, ton pur, presets rapides
- Synchronisation lecture/enregistrement par chirp de calibration + corrélation croisée (sans API de timestamp natif)
- Analyse FFT temps réel avec spectrogramme
- Extraction de la réponse en fréquence par déconvolution ESS (sweep) et méthode de Welch (bruit)
- Comparaison multi-enceintes par bandes de 1/3 d'octave, avec delta dB vs. une mesure de référence
- Export CSV/JSON, bibliothèque de mesures, import de calibration micro (format REW/miniDSP)
- Suite de tests (DSP, stockage, orchestration audio, écrans) exécutable sans appareil physique
- CI GitHub Actions (lint, format, tests) et builds artefacts (APK Android, iOS sans signature)
