import 'package:audio_session/audio_session.dart';

/// Configures the shared native audio session once at app startup, and
/// re-asserted before each measurement. `record` and `just_audio` each touch
/// the native session independently; without this they can fight over
/// category/mode (recording silently failing, or playback getting ducked).
class AudioSessionSetup {
  const AudioSessionSetup._();

  static Future<void> configure() async {
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        // `allowBluetooth` (Hands-Free Profile) would let iOS route mic
        // capture through a connected Bluetooth device's own mic instead of
        // the phone's — the same SCO-vs-A2DP conflict as on Android (see
        // `RecorderService`). `allowBluetoothA2DP` keeps high-quality
        // Bluetooth *output* (speakers) available without opting into that.
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetoothA2dp |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        // `measurement` disables iOS's AGC/echo-cancellation/noise-suppression,
        // which would otherwise corrupt frequency-response measurements.
        avAudioSessionMode: AVAudioSessionMode.measurement,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.unknown,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ),
    );
    await session.setActive(true);
  }
}
