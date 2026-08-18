// app/test/conversation_controller_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/chat_result.dart';
import 'package:app/models/persona.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/conversation_controller.dart';

class _FakeBackend implements BackendClient {
  bool fail = false;
  @override
  Future<List<Persona>> listPersonas() async => [];
  @override
  Future<ChatResult> chat({required String userId, required String personaId, required String text, String? conversationId}) async {
    if (fail) throw Exception('boom');
    return ChatResult(replyText: 'reply to $text', audioBytes: null, conversationId: conversationId ?? 'c1');
  }
}

void main() {
  test('happy path moves idle->...->idle and records messages', () async {
    final backend = _FakeBackend();
    final c = ConversationController(backend: backend, speak: (_, __) async {}, userId: 'u1', personaId: 'sage');
    await c.submitUserText('hi');
    expect(c.state.phase, TalkPhase.idle);
    expect(c.state.messages.map((m) => m.text), ['hi', 'reply to hi']);
    expect(c.state.conversationId, 'c1');
  });

  test('backend failure sets error phase', () async {
    final backend = _FakeBackend()..fail = true;
    final c = ConversationController(backend: backend, speak: (_, __) async {}, userId: 'u1', personaId: 'sage');
    await c.submitUserText('hi');
    expect(c.state.phase, TalkPhase.error);
    expect(c.state.errorMessage, isNotNull);
  });
}
