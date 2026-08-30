# Changelog

All notable changes to this project are documented in this file.

## [1.0.0] - 2026-08-30

### Corrigé
- **Pipeline Audio & Annulation d'écho (AEC Android)** : Bypass de l'AEC matériel via `AndroidAudioSource.unprocessed` (API 24+) avec mécanisme de repli automatique en cascade (`unprocessed` $\to$ `camcorder` $\to$ `mic`).
- **Session Audio Haute-Fidélité** : Configuration de la session audio en `AndroidAudioContentType.music` avec `AndroidAudioUsage.media`.
- **Analyseur RTA en direct** : Désactivation explicite des filtres matériels (AEC, réduction de bruit, AGC) et du routage Bluetooth SCO parasite.
- **Déconvolution Farina** : Remplacement de la fenêtre Tukey symétrique par un fenêtrage asymétrique (`_asymmetricWindow`) pour préserver l'impulsion acoustique directe sans atténuation parasite.

### Ajouté
- **Lissage fractionnaire d'octave** : Intégration du lissage gaussien par bandes d'octave (`1/3 oct`, `1/6 oct`, `1/12 oct`, `1/24 oct`, `Brut`) avec sélecteur direct sur les graphiques de réponse en fréquence.
- **Progression et étapes de mesure animées** : Barre de progression dynamique et suivi des phases (*Préchauffage* $\to$ *Émission & Capture* $\to$ *Analyse FFT* $\to$ *Terminé*).
- **Mode Comparaison Delta dB** : Affichage graphique des écarts $\Delta\text{dB}$ relatifs par rapport à une mesure de référence (ligne 0 dB).
- **Peak Hold & Freeze sur l'analyseur** : Tracé orange persistant des crêtes maximales et bouton pause/reprendre pour figer le spectre et le spectrogramme en direct.
- **Vu-mètre dynamique Test Micro** : Jauge LED colorée (-60 dBFS à 0 dBFS) avec diagnostic instantané du niveau sonore.
- **Recherche & gestion Bibliothèque** : Barre de recherche instantanée (par nom, modèle, tag), confirmation de suppression `AlertDialog` et formatage des dates.
- **Curseur musical** : Affichage de la note de musique la plus proche sur le curseur des courbes.

## [0.0.7] - 2026-08-02

### Corrigé
- Revert de `audioManagerMode: modeInCommunication` (ajouté en 0.0.5) : sur un Pixel, le test micro rapide a montré que le niveau restait quasi nul même en enregistrant via le haut-parleur du téléphone (donc sans Bluetooth) — ce mode "appel" déclenche le pipeline d'annulation d'écho le plus agressif de l'appareil, justement optimisé pour supprimer ce cas précis. Retour à `modeNormal` (défaut du plugin).

## [0.0.6] - 2026-08-02

### Ajouté
- Carte "Test micro rapide" sur l'onglet Calibration : joue un ton court et fort à travers exactement le même pipeline d'enregistrement/lecture qu'une mesure, et affiche immédiatement le niveau RMS capté (en dBFS, avec un code couleur). Permet de comparer rapidement l'effet de différents réglages audio (Bluetooth, position du téléphone...) sans attendre une mesure complète.

## [0.0.5] - 2026-08-02

### Corrigé
- Micro capturant un niveau quasi nul (-81dBFS) spécifiquement pendant une mesure (lecture + enregistrement simultanés), alors que l'onglet Analyseur (enregistrement seul) captait un niveau normal : `AndroidAudioSource.unprocessed` n'est pas garanti sur tous les appareils et pouvait échouer silencieusement — remplacé par `mic` (universellement supporté). Passage aussi en `audioManagerMode: modeInCommunication`, le réglage documenté par le plugin pour les problèmes d'AEC/routage en cas d'enregistrement et de lecture concurrents.

## [0.0.4] - 2026-08-02

### Modifié
- Simplification majeure de la synchronisation lecture/enregistrement : suppression du chirp de calibration et de la corrélation croisée, qui restaient peu fiables (notamment en Bluetooth) malgré plusieurs correctifs. Remplacés par une fenêtre d'analyse large centrée sur la position attendue du signal — la déconvolution ESS du sweep se localise déjà elle-même dans cette fenêtre, et les autres méthodes d'analyse (Welch, FFT) ne nécessitent pas d'alignement précis.
- Le message d'erreur en cas d'échec de mesure se base maintenant sur le niveau RMS réellement capté plutôt que sur une confiance de corrélation.

## [0.0.3] - 2026-08-02

### Corrigé
- Cause probable des mesures vides en sortie Bluetooth : le plugin d'enregistrement tentait par défaut d'ouvrir une connexion Bluetooth SCO pour le micro, routant la capture via le micro de l'appareil Bluetooth au lieu de celui du téléphone, et entrant en conflit avec la lecture A2DP. Le micro du téléphone est maintenant toujours utilisé, quelle que soit la sortie audio.
- Les APK de release sont maintenant signés avec une clé stable dédiée au lieu de la clé debug (qui changeait à chaque build CI) — les mises à jour s'installent désormais correctement par-dessus une version précédente. **Note** : si tu avais installé v0.0.1 ou v0.0.2, une désinstallation manuelle unique reste nécessaire pour passer à v0.0.3 ; les releases suivantes s'installeront normalement en mise à jour.

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
