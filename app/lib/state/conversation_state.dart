import 'package:flutter/foundation.dart';

enum TalkPhase { idle, listening, thinking, speaking, error }

@immutable
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  const ChatMessage(this.role, this.text);
}

@immutable
class ConversationState {
  final TalkPhase phase;
  final String partialTranscript;
  final List<ChatMessage> messages;
  final String activePersonaId;
  final String? conversationId;
  final String? errorMessage;

  const ConversationState({
    required this.phase,
    required this.partialTranscript,
    required this.messages,
    required this.activePersonaId,
    required this.conversationId,
    required this.errorMessage,
  });

  // Sentinel so `copyWith(conversationId: null)` can EXPLICITLY clear the id
  // (needed when switching personas), while omitting it preserves the current
  // value. A plain `conversationId ?? this.conversationId` cannot tell "clear"
  // apart from "unchanged".
  static const Object _keep = Object();

  ConversationState copyWith({
    TalkPhase? phase,
    String? partialTranscript,
    List<ChatMessage>? messages,
    String? activePersonaId,
    Object? conversationId = _keep,
    String? errorMessage,
  }) =>
      ConversationState(
        phase: phase ?? this.phase,
        partialTranscript: partialTranscript ?? this.partialTranscript,
        messages: messages ?? this.messages,
        activePersonaId: activePersonaId ?? this.activePersonaId,
        conversationId: identical(conversationId, _keep)
            ? this.conversationId
            : conversationId as String?,
        errorMessage: errorMessage,
      );

  static ConversationState initial(String personaId) => ConversationState(
        phase: TalkPhase.idle,
        partialTranscript: '',
        messages: const [],
        activePersonaId: personaId,
        conversationId: null,
        errorMessage: null,
      );
}
