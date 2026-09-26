import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// Production-ready Service for playing loud order alert sounds and haptics
/// for delivery riders, with automatic stream routing to ALARM/RINGTONE stream.
class SoundService {
  SoundService._internal() {
    _initPlayer();
  }

  static final SoundService instance = SoundService._internal();

  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isMuted = false;
  Timer? _loopTimer;
  int _alertRepeats = 0;
  bool _isConfigured = false;

  bool get isAlerting => _isPlaying;
  bool get isMuted => _isMuted;

  void setMuted(bool muted) {
    _isMuted = muted;
    if (muted && _isPlaying) {
      stopAlert();
    }
  }

  Future<void> _initPlayer() async {
    try {
      _player ??= AudioPlayer();
      _player?.setReleaseMode(ReleaseMode.stop);

      if (!_isConfigured) {
        _isConfigured = true;
        // Configure global audio context so sound plays on ALARM stream (loud & bypasses silent media)
        await AudioPlayer.global.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: const {
                AVAudioSessionOptions.duckOthers,
                AVAudioSessionOptions.defaultToSpeaker,
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error initializing AudioPlayer / AudioContext: $e');
    }
  }

  /// Triggers the order alert sound with haptics and repeats up to 5 times until acknowledged
  Future<void> playNewOrderAlert() async {
    if (_isMuted) {
      debugPrint('🔕 [SoundService] Alert skipped because audio is muted.');
      return;
    }

    // Stop any existing loop cleanly
    _loopTimer?.cancel();
    _loopTimer = null;
    _isPlaying = true;
    _alertRepeats = 0;

    debugPrint('🔔 [SoundService] Triggering new order alert chime...');

    // Physical vibration
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    await _playAudio();

    // Loop chime every 4 seconds up to 5 times if not acknowledged
    _loopTimer = Timer.periodic(const Duration(milliseconds: 4000), (timer) async {
      _alertRepeats++;
      if (_alertRepeats >= 5 || !_isPlaying) {
        stopAlert();
        return;
      }
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
      await _playAudio();
    });
  }

  Future<void> _playAudio() async {
    await _initPlayer();

    // 1. Try playing MP3 announcement / chime
    bool played = false;
    try {
      await _player?.play(AssetSource('sounds/order_alert.mp3'), volume: 1.0);
      played = true;
      debugPrint('✅ [SoundService] order_alert.mp3 played successfully');
    } catch (e) {
      debugPrint('⚠️ [SoundService] MP3 playback failed: $e, trying WAV asset...');
    }

    // 2. If MP3 fails, try WAV asset
    if (!played) {
      try {
        await _player?.play(AssetSource('sounds/order_alert.wav'), volume: 1.0);
        played = true;
        debugPrint('✅ [SoundService] order_alert.wav played successfully');
      } catch (e) {
        debugPrint('⚠️ [SoundService] WAV playback failed: $e');
      }
    }

    // 3. Fallback to SystemSound alert beep
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  /// Plays a single test chime (e.g. from drawer / settings)
  Future<void> playTestChime() async {
    debugPrint('🔔 [SoundService] Playing test chime...');
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    await _playAudio();
  }

  /// Stops ongoing order alert sound loop immediately
  void stopAlert() {
    if (!_isPlaying) return; // Do not send redundant stop calls to native player
    _isPlaying = false;
    _loopTimer?.cancel();
    _loopTimer = null;
    try {
      _player?.stop();
      debugPrint('⏹️ [SoundService] Alert stopped.');
    } catch (e) {
      debugPrint('⚠️ [SoundService] Error stopping audio: $e');
    }
  }

  void dispose() {
    stopAlert();
    _player?.dispose();
    _player = null;
  }
}
