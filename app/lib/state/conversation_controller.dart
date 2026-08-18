import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/services/audio_capture_service.dart';
import 'package:app/state/conversation_state.dart';

typedef SpeakFn = Future<void> Function(Uint8List? audio, String fallbackText);

class ConversationController extends StateNotifier<ConversationState> {
  final BackendClient backend;
  final SpeakFn speak;
  final String userId;
  final AudioCapture? capture;

  bool _conversing = false;

  ConversationController({
    required this.backend,
    required this.speak,
    required this.userId,
    required String personaId,
    this.capture,
  }) : super(ConversationState.initial(personaId));

  bool get conversing => _conversing;

  void setPersona(String id) =>
      state = state.copyWith(activePersonaId: id, messages: const [], conversationId: null);

  // ---- Continuous, hands-free conversation loop (ChatGPT-voice style) ----

  /// Turn the conversation on: record a turn → transcribe+reply+speak →
  /// record again, until [stopConversation].
  Future<void> startConversation() async {
    if (_conversing) return;
    final c = capture;
    if (c == null) return;
    if (!await c.ensurePermission()) {
      state = state.copyWith(
        phase: TalkPhase.error,
        errorMessage: "Microphone permission is needed — enable it and tap to start again.",
      );
      return;
    }
    _conversing = true;
    await _captureNext();
  }

  /// Turn the conversation off.
  Future<void> stopConversation() async {
    _conversing = false;
    await capture?.stop();
    state = state.copyWith(phase: TalkPhase.idle, partialTranscript: '');
  }

  Future<void> _captureNext() async {
    if (!_conversing) return;
    final c = capture;
    if (c == null) {
      _conversing = false;
      return;
    }
    state = state.copyWith(phase: TalkPhase.listening, partialTranscript: '');
    Uint8List? audio;
    try {
      audio = await c.captureTurn();
    } catch (_) {
      audio = null;
    }
    if (!_conversing) return;
    if (audio == null) {
      // Heard nothing — pause briefly (guard against a hot loop if capture
      // returns instantly) then listen again.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (_conversing) await _captureNext();
      return;
    }
    final ok = await _turn(audio);
    if (!_conversing) return;
    if (ok) {
      await _captureNext();
    } else {
      _conversing = false; // backend error — stop and show the error
    }
  }

  /// One turn from recorded audio: thinking → backend (transcribe + reply) →
  /// speaking → speak. Leaves phase `speaking` on success, `error` on failure.
  Future<bool> _turn(Uint8List audio) async {
    state = state.copyWith(phase: TalkPhase.thinking, partialTranscript: '');
    try {
      final res = await backend.chat(
        userId: userId,
        personaId: state.activePersonaId,
        audioBytes: audio,
        conversationId: state.conversationId,
      );
      final heard = res.userText.trim();
      final msgs = [...state.messages];
      if (heard.isNotEmpty) msgs.add(ChatMessage('user', heard));
      msgs.add(ChatMessage('assistant', res.replyText));
      state = state.copyWith(
        phase: TalkPhase.speaking,
        conversationId: res.conversationId,
        messages: msgs,
      );
      await speak(res.audioBytes, res.replyText);
      return true;
    } catch (e) {
      state = state.copyWith(
        phase: TalkPhase.error,
        errorMessage: "Couldn't reach your companion. Tap to try again.",
      );
      return false;
    }
  }

  // ---- Text turn (used by tests / a manual typed send) ----

  Future<void> submitUserText(String text) async {
    if (text.trim().isEmpty) {
      state = state.copyWith(phase: TalkPhase.idle);
      return;
    }
    state = state.copyWith(
      phase: TalkPhase.thinking,
      partialTranscript: '',
      messages: [...state.messages, ChatMessage('user', text)],
    );
    try {
      final res = await backend.chat(
        userId: userId,
        personaId: state.activePersonaId,
        text: text,
        conversationId: state.conversationId,
      );
      state = state.copyWith(
        phase: TalkPhase.speaking,
        conversationId: res.conversationId,
        messages: [...state.messages, ChatMessage('assistant', res.replyText)],
      );
      await speak(res.audioBytes, res.replyText);
      state = state.copyWith(phase: TalkPhase.idle);
    } catch (e) {
      state = state.copyWith(
        phase: TalkPhase.error,
        errorMessage: "Couldn't reach your companion. Tap to try again.",
      );
    }
  }
}
