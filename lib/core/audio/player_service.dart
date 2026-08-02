import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';

import 'measurement_session.dart' show Player;

/// Thin adapter over `just_audio`. `just_audio` needs a file/URI source, so
/// this writes [wavBytes] to a temp file before playing it, and awaits the
/// player's `ProcessingState.completed` event to know playback finished.
class PlayerService implements Player {
  final ja.AudioPlayer _player;

  PlayerService({ja.AudioPlayer? player})
    : _player = player ?? ja.AudioPlayer();

  @override
  Future<void> play(Uint8List wavBytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/spectracompare_play_${DateTime.now().microsecondsSinceEpoch}.wav';
    await File(path).writeAsBytes(wavBytes, flush: true);

    await _player.setFilePath(path);
    final completion = _player.processingStateStream.firstWhere(
      (state) => state == ja.ProcessingState.completed,
    );
    await _player.play();
    await completion;
  }

  Future<void> dispose() => _player.dispose();
}
