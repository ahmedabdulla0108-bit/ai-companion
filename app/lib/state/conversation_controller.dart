import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/state/conversation_state.dart';

typedef SpeakFn = Future<void> Function(Uint8List? audio, String fallbackText);

class ConversationController extends StateNotifier<ConversationState> {
  final BackendClient backend;
  final SpeakFn speak;
  final String userId;

  ConversationController({
    required this.backend,
    required this.speak,
    required this.userId,
    required String personaId,
  }) : super(ConversationState.initial(personaId));

  void setPersona(String id) =>
      state = state.copyWith(activePersonaId: id, messages: const [], conversationId: null);

  void setPartial(String partial) => state = state.copyWith(partialTranscript: partial);
  void setListening() => state = state.copyWith(phase: TalkPhase.listening, partialTranscript: '');

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
