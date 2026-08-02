# 🔊 SpectraCompare

> Analyseur spectral mobile avec générateur de signaux de test intégré, pour enregistrer, analyser et comparer des enceintes.


## 🎯 Objectif du projet

SpectraCompare combine dans une seule app un **générateur de signaux de test natif** et un **analyseur FFT en temps réel**, pour permettre de mesurer, enregistrer et comparer la réponse en fréquence de plusieurs enceintes de façon reproductible. L'app est pensée pour les audiophiles, testeurs d'enceintes et makers (DIY speakers, projets IoT audio) qui veulent une mesure fiable sans dépendre d'un signal externe non maîtrisé.

## 🎛️ Générateur de signaux (module natif, priorité #1)

C'est la pierre angulaire de l'app : sans signal de test contrôlé et reproductible, aucune comparaison entre enceintes n'est valide. Ce module est disponible dès la v1, joué en local par le téléphone, et synchronisé avec l'enregistrement.

- **Sine sweep** (balayage sinusoïdal) linéaire ou logarithmique, 20 Hz – 20 kHz, avec bornes personnalisables — standard pour mesurer la réponse en fréquence [roomeqwizard](https://www.roomeqwizard.com/features.html)
- **Bruit rose (pink noise)** — référence pour la calibration d'enceintes et l'analyse RTA (atténuation ~3 dB/octave) [apps.apple](https://apps.apple.com/us/app/audio-signal-generator/id543661843)
- **Bruit blanc (white noise)** — pour tests électroniques et large bande [sonavyx](https://sonavyx.com/en/tools/noise-generator)
- **Chirp / burst** — impulsions courtes pour tester la réactivité transitoire des enceintes, et servent aussi de signal de calibration de latence (voir plus bas) [mwm](https://mwm.ai/apps/audio-tone-generator-plus/1619042820)
- **MLS (Maximum Length Sequence)** — alternative au sweep pour les mesures en environnement bruité (optionnel v2) [sonavyx](https://sonavyx.com/en/tools/noise-generator)
- **Ton pur ajustable** (1 Hz – 22 kHz) pour repérer résonances ou trous dans le spectre [play.google](https://play.google.com/store/apps/details?id=com.simonj.tonegenerator&hl=en)
- **Presets** enregistrement rapide : "Sweep standard", "Calibration pink noise", "Test rattle/burst"
- **Synchronisation lecture ↔ enregistrement** : le signal généré et l'enregistrement micro démarrent/s'arrêtent ensemble pour garantir la reproductibilité entre mesures

⚠️ Le signal doit toujours être joué à un niveau de sortie contrôlé (ex: -20 dBFS par défaut) pour protéger les enceintes et permettre des comparaisons à niveau constant. [sonavyx](https://sonavyx.com/en/tools/noise-generator)

## ✨ Autres fonctionnalités

- **Analyse FFT temps réel** avec affichage du spectre de fréquences (20 Hz – 20 kHz)
- **Spectrogramme** pour visualiser l'évolution temporelle du signal
- **Mesure SPL** (niveau de pression sonore) en dB
- **Comparaison multi-enceintes** : superposition de courbes, calcul de delta en dB par bande de fréquence
- **Export des données** (CSV, JSON) pour analyse externe
- **Bibliothèque de mesures** avec tags (modèle enceinte, position, distance, volume testé, signal utilisé)
- **Mode calibration micro** avec fichier de correction (compatible REW/miniDSP)

## ⏱️ Synchronisation et gestion de la latence

La mesure n'a de sens que si l'app connaît précisément le décalage temporel entre l'instant où le signal est réellement émis par le haut-parleur et l'instant où il est capté par le micro. Ce décalage (latence round-trip) varie selon l'appareil, l'OS et la sortie audio utilisée (interne, jack, Bluetooth).

### Android

- Utiliser l'API **AAudio** en mode `AAUDIO_PERFORMANCE_MODE_LOW_LATENCY` avec callback pour minimiser la latence native [developer.android](https://developer.android.com/ndk/guides/audio/aaudio/aaudio)
- Récupérer le timestamp exact de lecture/enregistrement via `AAudioStream_getTimestamp()`, qui donne la correspondance frame ↔ temps réel pour aligner lecture et capture [developer.android](https://developer.android.com/ndk/reference/group/audio)
- Précision garantie par la CDD Android : ±1 à ±2 ms selon la classe de l'appareil (`Pro Audio` ou standard) [android.googlesource](https://android.googlesource.com/platform/compatibility/cdd/+/refs/heads/master/5_multimedia/5_6_audio-latency.md)
- En fallback (API plus anciennes), utiliser `AudioTrack.getTimestamp()` plutôt que `getPlaybackHeadPosition()` seul, ce dernier n'étant qu'une approximation [stackoverflow](https://stackoverflow.com/questions/49581054/how-to-use-audiotrack-gettimestamp-on-android-to-calculate-latency)

### iOS

- Utiliser `AVAudioEngine` avec `AVAudioPlayerNode` et `AVAudioSession`, en s'appuyant sur les host times (`mach_timebase_info`) pour aligner les timestamps des nodes d'entrée et de sortie [stackoverflow](https://stackoverflow.com/questions/65600996/avaudioengine-reconcile-sync-input-output-timestamps-on-macos-ios)
- `AVAudioSession.outputLatency` et `.inputLatency` donnent la latence matérielle de base, mais ces valeurs sont **peu fiables en Bluetooth** (souvent nulles ou incorrectes) [musevv](https://www.musevv.com/blog/how-i-solved-bluetooth-audio-latency-on-ios.html)

### Cas particulier : sortie Bluetooth

Comme aucune plateforme n'expose de manière fiable la latence réelle d'un routage Bluetooth, la méthode la plus robuste est l'**auto-calibration par corrélation** :

1. Jouer un signal connu (chirp / burst court) au tout début de chaque mesure
2. Enregistrer ce signal via le micro pendant qu'il est joué
3. Calculer la corrélation croisée entre signal émis et signal capté pour déterminer le décalage temporel réel
4. Appliquer ce décalage comme offset avant l'analyse FFT, sans jamais modifier l'audio brut, seulement le point de départ de l'analyse [musevv](https://www.musevv.com/blog/how-i-solved-bluetooth-audio-latency-on-ios.html)

Cette approche ("chirp de calibration") est utilisée comme méthode par défaut, quelle que soit la sortie audio (interne, jack, Bluetooth), car aucun OS ne garantit une latence fiable en toutes circonstances. [blog.csdn](https://blog.csdn.net/weixin_34146805/article/details/92717614)

## 🏗️ Stack technique

| Composant | Technologie |
|---|---|
| Frontend mobile | Flutter / Kotlin (Android) / Swift (iOS) |
| Génération de signal | Moteur audio natif (AAudio Android / AVAudioEngine iOS) |
| Timestamping / sync | `AAudioStream_getTimestamp()` (Android) / host time `mach_timebase_info` (iOS) |
| Traitement du signal (analyse) | FFT (`fftw`/`kissfft` ou équivalent natif) |
| Stockage local | SQLite / Firebase (sync cloud optionnel) |
| Export/Partage | CSV, JSON, PDF report |
| Calibration | Chirp de calibration intégré + fichiers `.txt`/`.cal` compatibles REW/miniDSP |

## 🚀 Installation

### Prérequis
- Flutter SDK ≥ 3.x (ou Android Studio / Xcode selon la cible)
- Haut-parleur du téléphone ou sortie audio pour jouer le signal de test
- Microphone du téléphone (idéalement calibré pour mesures précises)

### Étapes

```bash
git clone https://github.com/<ton-user>/spectra-compare.git
cd spectra-compare
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

## ⚠️ Limites connues

Les micros de smartphone ne sont pas calibrés par défaut : les mesures sont donc **relatives**, utiles pour comparer plusieurs enceintes entre elles dans les mêmes conditions, mais pas pour une mesure absolue sans micro externe calibré. Le fait de contrôler nativement le signal de test et de compenser la latence par corrélation limite cependant fortement les biais liés à des sources ou routages audio non maîtrisés.

## 🗺️ Roadmap

- [x] Générateur de signaux natif (sweep, pink/white noise, burst) — v1
- [x] Synchronisation lecture/enregistrement par chirp de calibration — v1
- [ ] MLS pour mesures en environnement bruité
- [ ] Export rapport PDF comparatif
- [ ] Mode "double blind test" (A/B comparaison à l'aveugle)
- [ ] Synchronisation cloud multi-appareils

## 🤝 Contribuer

Les contributions sont bienvenues ! Ouvre une issue ou une pull request pour proposer des améliorations.

## 📄 Licence

Ce projet est sous licence MIT — voir le fichier [LICENSE](LICENSE) pour plus de détails.
