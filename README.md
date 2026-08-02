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

Aucune plateforme n'expose de façon fiable la latence réelle entre l'instant où un signal est émis et l'instant où il est capté par le micro — c'est particulièrement vrai en sortie Bluetooth, où les valeurs remontées par les API système sont souvent nulles ou incorrectes. [musevv](https://www.musevv.com/blog/how-i-solved-bluetooth-audio-latency-on-ios.html)

Une première version tentait de mesurer ce décalage précisément via un chirp de calibration injecté en tête de chaque mesure, retrouvé dans l'enregistrement par corrélation croisée. En pratique, cette étape s'est révélée être le point le plus fragile de toute la chaîne — particulièrement en Bluetooth, expérience à l'appui. L'app s'appuie maintenant sur une approche plus simple et plus robuste, qui n'a en réalité jamais eu besoin d'un décalage précis :

1. Le signal de test est joué avec une marge de silence avant et après (`[preroll][signal][tail]`), pendant que le micro enregistre
2. L'analyse porte sur une fenêtre large, centrée sur la position *attendue* du signal et généreusement élargie (quelques secondes) pour absorber une latence de sortie inconnue — sans jamais tenter de la détecter précisément
3. Pour le sweep, la déconvolution ESS/Farina agit elle-même comme un filtre adapté : le pic de la réponse impulsionnelle obtenue indique où se trouve le signal dans la fenêtre, quel que soit le décalage réel
4. Pour le bruit rose/blanc et les tons/burst, l'analyse (méthode de Welch, FFT simple) ne nécessite pas d'alignement précis — une fenêtre qui contient largement le signal suffit

Un contrôle de niveau (RMS) sur le segment analysé permet quand même de détecter le cas où rien n'a été capté du tout (permission micro, micro obstrué, volume de sortie nul) et de le signaler clairement plutôt que d'afficher un résultat vide ou aberrant.

## 🏗️ Stack technique

| Composant | Technologie |
|---|---|
| Frontend mobile | Flutter / Dart |
| État applicatif | `provider` (ChangeNotifier) |
| Lecture audio | `just_audio` |
| Capture micro | `record` |
| Session audio partagée (Android/iOS) | `audio_session` (catégorie `playAndRecord`, mode `measurement` sur iOS pour désactiver AGC/echo-cancellation) |
| DSP (FFT, déconvolution) | `fftea` (pur Dart) + implémentation maison (ESS/Farina, Welch, bandes 1/3 octave) |
| Graphiques | `fl_chart` (spectre/comparaison), `CustomPainter` maison (spectrogramme) |
| Stockage local | `sqflite` |
| Export/Partage | `csv`, `share_plus` |
| Permissions | `permission_handler` |

> **Choix d'architecture** : pas de code natif Kotlin/Swift pour l'audio — des plugins Flutter matures (`just_audio`/`record`/`audio_session`) suffisent, combinés à l'approche de fenêtre large décrite ci-dessus qui ne dépend d'aucune API de timestamp natif ni d'une détection précise du décalage lecture/enregistrement.

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
3. Lancer la mesure : le signal de test est joué et enregistré automatiquement, avec les marges nécessaires pour absorber la latence de la sortie audio utilisée
4. Sauvegarder la mesure avec un tag (nom enceinte, conditions, signal utilisé)
5. Répéter pour chaque enceinte à comparer, avec le même signal et la même distance
6. Ouvrir l'écran **Comparaison** pour superposer les courbes

## 📂 Structure du projet

```
lib/
  core/
    audio/      signal generator, WAV codec, session recorder/player, mesure orchestrée
    dsp/        FFT, déconvolution ESS, Welch, bandes 1/3 octave, SPL
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
- Le contrôle du signal de test et les marges généreuses autour de sa position attendue limitent les biais liés aux routages audio non maîtrisés, mais n'éliminent pas le bruit ambiant : mesurer dans un environnement calme reste recommandé.
- La suite de tests couvre le DSP, le stockage et les écrans en environnement headless ; les scénarios de lecture/enregistrement réels (bruit ambiant, Bluetooth, matériel varié) nécessitent une validation manuelle sur appareil.

## 🗺️ Roadmap

- [x] Générateur de signaux (sweep, pink/white noise, burst, ton pur) — v1
- [x] Synchronisation lecture/enregistrement robuste sans détection de latence (fenêtre large + déconvolution auto-localisante) — v1
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
