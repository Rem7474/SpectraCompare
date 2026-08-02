# 🔊 SpectraCompare

[![CI](https://github.com/Rem7474/SpectraCompare/actions/workflows/ci.yml/badge.svg)](https://github.com/Rem7474/SpectraCompare/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)

> Analyseur spectral mobile avec générateur de signaux de test intégré, pour enregistrer, analyser et comparer des enceintes.

## 🎯 Objectif du projet

SpectraCompare combine dans une seule app un **générateur de signaux de test** et un **analyseur FFT en temps réel**, pour permettre de mesurer, enregistrer et comparer la réponse en fréquence de plusieurs enceintes de façon reproductible. L'app est pensée pour les audiophiles, testeurs d'enceintes et makers (DIY speakers, projets IoT audio) qui veulent une mesure fiable sans dépendre d'un signal externe non maîtrisé.

## 🎛️ Générateur de signaux (priorité #1)

C'est la pierre angulaire de l'app : sans signal de test contrôlé et reproductible, aucune comparaison entre enceintes n'est valide. Ce module est joué en local par le téléphone, et synchronisé avec l'enregistrement.

- **Sine sweep** (balayage sinusoïdal) linéaire ou logarithmique, 20 Hz – 20 kHz, avec bornes personnalisables — standard pour mesurer la réponse en fréquence [roomeqwizard](https://www.roomeqwizard.com/features.html)
- **Bruit rose (pink noise)** — référence pour la calibration d'enceintes et l'analyse RTA (atténuation ~3 dB/octave) [apps.apple](https://apps.apple.com/us/app/audio-signal-generator/id543661843)
- **Bruit blanc (white noise)** — pour tests électroniques et large bande [sonavyx](https://sonavyx.com/en/tools/noise-generator)
- **Burst** — impulsions courtes pour tester la réactivité transitoire des enceintes [mwm](https://mwm.ai/apps/audio-tone-generator-plus/1619042820)
- **Ton pur ajustable** pour repérer résonances ou trous dans le spectre [play.google](https://play.google.com/store/apps/details?id=com.simonj.tonegenerator&hl=en)
- **Presets** enregistrement rapide : "Sweep standard", "Calibration pink noise", "Test rattle/burst"
- **Chirp de calibration** injecté automatiquement en tête de chaque mesure pour la synchronisation lecture ↔ enregistrement (voir plus bas)

⚠️ Le signal doit toujours être joué à un niveau de sortie contrôlé (ex: -20 dBFS par défaut) pour protéger les enceintes et permettre des comparaisons à niveau constant. [sonavyx](https://sonavyx.com/en/tools/noise-generator)

## ✨ Autres fonctionnalités

- **Analyse FFT temps réel** avec affichage du spectre de fréquences (20 Hz – 20 kHz) et spectrogramme
- **Mesure par déconvolution ESS** (méthode Farina) pour le sweep, méthode de Welch pour les bruits — extraction de la réponse en fréquence complète en un seul passage
- **Mesure SPL relative** (dBFS, avec offset de calibration optionnel)
- **Comparaison multi-enceintes** : superposition de courbes, calcul de delta en dB par bande de 1/3 d'octave vs. une mesure de référence
- **Export des données** (CSV, JSON) pour analyse externe
- **Bibliothèque de mesures** avec tags (modèle enceinte, position, distance, niveau de sortie, signal utilisé)
- **Mode calibration micro** avec import de fichier de correction (compatible format REW/miniDSP)

## ⏱️ Synchronisation et gestion de la latence

La mesure n'a de sens que si l'app connaît précisément le décalage temporel entre l'instant où le signal est réellement émis par le haut-parleur et l'instant où il est capté par le micro. Ce décalage (latence round-trip) varie selon l'appareil, l'OS et la sortie audio utilisée (interne, jack, Bluetooth), et aucune plateforme n'expose cette latence de façon fiable dans tous les cas — en particulier en Bluetooth, où les valeurs remontées par les API systèmes sont souvent nulles ou incorrectes. [musevv](https://www.musevv.com/blog/how-i-solved-bluetooth-audio-latency-on-ios.html)

SpectraCompare utilise donc une **auto-calibration par corrélation croisée**, comme méthode par défaut, quelle que soit la sortie audio :

1. Un fichier audio combiné est construit : `[silence][chirp de calibration][gap][signal de test][tail]`
2. L'enregistrement micro démarre, puis ce fichier est joué en une seule fois
3. Une corrélation croisée (FFT) entre le chirp connu et l'enregistrement capté détermine le décalage réel en échantillons
4. Ce décalage sert uniquement à découper le bon segment pour l'analyse — l'audio brut n'est jamais modifié

Cette approche ne dépend d'aucune API de timestamp natif (`AAudioStream_getTimestamp`, `mach_timebase_info`, etc.) : elle fonctionne à l'identique sur Android, iOS, sortie interne, jack ou Bluetooth.

## 🏗️ Stack technique

| Composant | Technologie |
|---|---|
| Frontend mobile | Flutter / Dart |
| État applicatif | `provider` (ChangeNotifier) |
| Lecture audio | `just_audio` |
| Capture micro | `record` |
| Session audio partagée (Android/iOS) | `audio_session` (catégorie `playAndRecord`, mode `measurement` sur iOS pour désactiver AGC/echo-cancellation) |
| DSP (FFT, déconvolution, corrélation) | `fftea` (pur Dart) + implémentation maison (ESS/Farina, Welch, bandes 1/3 octave) |
| Graphiques | `fl_chart` (spectre/comparaison), `CustomPainter` maison (spectrogramme) |
| Stockage local | `sqflite` |
| Export/Partage | `csv`, `share_plus` |
| Permissions | `permission_handler` |

> **Choix d'architecture** : la synchronisation lecture/enregistrement repose entièrement sur le chirp de calibration + corrélation croisée (ci-dessus), qui est déjà la méthode universelle recommandée par le cahier des charges initial. Cela permet de s'appuyer sur des plugins Flutter matures plutôt que sur du code natif Kotlin/Swift par plateforme, sans rien perdre en fiabilité de synchronisation.

## 🚀 Installation

### Prérequis
- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.44 (channel stable)
- Un appareil Android/iOS ou un émulateur, avec micro et haut-parleur fonctionnels
- Accès au microphone accordé à l'app (demandé au premier lancement)

### Étapes

```bash
git clone https://github.com/Rem7474/SpectraCompare.git
cd SpectraCompare
flutter pub get
flutter run
```

## 📱 Utilisation

1. Choisir un preset de signal de test (sweep, pink noise, burst...)
2. Placer le téléphone à distance fixe de l'enceinte (ex: 1m, hauteur oreille)
3. Lancer la mesure : un chirp de calibration est joué et capté automatiquement pour compenser la latence, puis le signal de test démarre en synchro
4. Sauvegarder la mesure avec un tag (nom enceinte, conditions, signal utilisé)
5. Répéter pour chaque enceinte à comparer, avec le même signal et la même distance
6. Ouvrir l'écran **Comparaison** pour superposer les courbes

## 📂 Structure du projet

```
lib/
  core/
    audio/      signal generator, WAV codec, session recorder/player, mesure orchestrée
    dsp/        FFT, déconvolution ESS, corrélation croisée, Welch, bandes 1/3 octave, SPL
    models/     SignalConfig, FrequencyResponse, CalibrationCurve, Measurement
    storage/    base sqflite (DAO mesures/calibrations), export CSV/JSON, parsing fichiers calibration
  features/
    generator/  presets de signaux
    measurement/  écran + contrôleur de mesure (lecture + enregistrement synchronisés)
    analyzer/   FFT temps réel + spectrogramme
    library/    bibliothèque des mesures enregistrées
    comparison/ superposition de courbes et delta dB
    calibration/  import/sélection de courbe de calibration micro
  widgets/      composants partagés (graphique réponse en fréquence)
test/           tests miroir de lib/ (dsp, audio, storage, widgets)
```

## ✅ Tests & CI/CD

Le projet est entièrement testable sans appareil physique (DSP en pur Dart, stockage via `sqflite_common_ffi`, orchestration audio via de fakes `Recorder`/`Player`, écrans en tests `widget` headless).

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .   # formatage
flutter analyze                                      # lint / erreurs statiques
flutter test --coverage                               # suite de tests complète
```

GitHub Actions exécute automatiquement cette même suite sur chaque push/PR vers `main` ([`ci.yml`](.github/workflows/ci.yml)), et construit des artefacts APK Android / build iOS sur `main` et les tags `v*` ([`build.yml`](.github/workflows/build.yml)). Les dépendances (`pub` et Actions) sont mises à jour automatiquement chaque semaine via Dependabot.

## ⚠️ Limites connues

- Les micros de smartphone ne sont pas calibrés par défaut : les mesures sont donc **relatives**, utiles pour comparer plusieurs enceintes entre elles dans les mêmes conditions, mais pas pour une mesure absolue sans micro externe calibré (un import de courbe de calibration REW/miniDSP est possible pour corriger ce biais).
- Le fait de contrôler nativement le signal de test et de compenser la latence par corrélation limite fortement les biais liés à des sources ou routages audio non maîtrisés, mais n'élimine pas le bruit ambiant : mesurer dans un environnement calme reste recommandé.
- La suite de tests couvre le DSP, le stockage et les écrans en environnement headless ; les scénarios de lecture/enregistrement réels (bruit ambiant, Bluetooth, matériel varié) nécessitent une validation manuelle sur appareil.

## 🗺️ Roadmap

- [x] Générateur de signaux (sweep, pink/white noise, burst, ton pur) — v1
- [x] Synchronisation lecture/enregistrement par chirp de calibration — v1
- [x] Analyse FFT temps réel + spectrogramme — v1
- [x] Déconvolution ESS (sweep) et méthode de Welch (bruit) — v1
- [x] Comparaison multi-enceintes par bandes 1/3 octave — v1
- [x] Export CSV/JSON, bibliothèque de mesures, calibration micro — v1
- [x] CI (lint, tests) + build artefacts automatisés — v1
- [ ] MLS pour mesures en environnement bruité
- [ ] Export rapport PDF comparatif
- [ ] Mode "double blind test" (A/B comparaison à l'aveugle)
- [ ] Synchronisation cloud multi-appareils

## 🤝 Contribuer

Les contributions sont bienvenues ! Ouvre une issue ou une pull request pour proposer des améliorations — un [template de PR](.github/pull_request_template.md) rappelle les vérifications attendues avant merge (`flutter analyze`, `flutter test`, `dart format`).

## 📄 Licence

Ce projet est sous licence MIT — voir le fichier [LICENSE](LICENSE) pour plus de détails.
