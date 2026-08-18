import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/services/audio_service.dart';
import 'package:app/services/audio_capture_service.dart';
import 'package:app/state/conversation_controller.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/settings_provider.dart';

final audioServiceProvider = Provider<AudioService>((ref) => AudioService());
final audioCaptureProvider = Provider<AudioCapture>((ref) => AudioCaptureService());

final backendClientProvider = Provider<BackendClient>((ref) {
  final s = ref.watch(settingsProvider);
  return DioBackendClient(Dio(), baseUrl: s.backendUrl, token: s.bearerToken);
});

final conversationControllerProvider =
    StateNotifierProvider<ConversationController, ConversationState>((ref) {
  final s = ref.watch(settingsProvider);
  final backend = ref.watch(backendClientProvider);
  final audio = ref.watch(audioServiceProvider);
  final capture = ref.watch(audioCaptureProvider);
  return ConversationController(
    backend: backend,
    speak: (bytes, fallback) => audio.speak(mp3Bytes: bytes, fallbackText: fallback),
    userId: s.userId,
    personaId: 'sage',
    capture: capture,
  );
});
