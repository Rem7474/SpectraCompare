# Changelog

All notable changes to this project are documented in this file.

## [0.0.2] - 2026-08-02

### Corrigé
- Synchronisation par chirp de calibration : l'enregistrement pouvait s'arrêter avant la fin réelle de la lecture sur les sorties à latence élevée (typiquement Bluetooth), vidant le segment analysé et produisant un résultat vide ou aberrant sans aucun message d'erreur. L'app attend maintenant au minimum la durée nominale du fichier combiné + une marge de sécurité (1.5s), et affiche une erreur explicite si la confiance de corrélation reste trop basse.
- Contraste du tooltip sur le graphique de réponse en fréquence (texte illisible sur fond sombre) et arrondi de la valeur affichée.
- Build de release Android/iOS cassé par une incompatibilité de versions internes du plugin `record` (`record_linux` vs `record_platform_interface`).

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
