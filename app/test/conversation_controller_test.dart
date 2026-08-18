// app/test/conversation_controller_test.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/chat_result.dart';
import 'package:app/models/persona.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/services/audio_capture_service.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/conversation_controller.dart';

/// Returns one chunk of "audio" per turn (until the script runs out, then null
/// so the loop parks in listening instead of spinning).
class _ScriptedCapture implements AudioCapture {
  final int turns;
  int _i = 0;
  final Completer<Uint8List?> _parked = Completer<Uint8List?>();
  _ScriptedCapture(this.turns);
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> stop() async {
    if (!_parked.isCompleted) _parked.complete(null);
  }
  @override
  Future<Uint8List?> captureTurn() async {
    if (_i++ < turns) return Uint8List.fromList([1, 2, 3]);
    return _parked.future; // park like a mic waiting for speech, until stop()
  }
}

class _FakeBackend implements BackendClient {
  bool fail = false;
  @override
  Future<List<Persona>> listPersonas() async => [];
  @override
  Future<ChatResult> chat({
    required String userId,
    required String personaId,
    String text = '',
    Uint8List? audioBytes,
    String? conversationId,
  }) async {
    if (fail) throw Exception('boom');
    if (audioBytes != null) {
      // Simulate server-side transcription of the audio.
      return ChatResult(
        replyText: 'reply to what you said',
        audioBytes: null,
        conversationId: conversationId ?? 'c1',
        userText: 'what you said',
      );
    }
    return ChatResult(replyText: 'reply to $text', audioBytes: null, conversationId: conversationId ?? 'c1');
  }
}

void main() {
  test('text turn moves idle->...->idle and records messages', () async {
    final backend = _FakeBackend();
    final c = ConversationController(backend: backend, speak: (_, _) async {}, userId: 'u1', personaId: 'sage');
    await c.submitUserText('hi');
    expect(c.state.phase, TalkPhase.idle);
    expect(c.state.messages.map((m) => m.text), ['hi', 'reply to hi']);
    expect(c.state.conversationId, 'c1');
  });

  test('backend failure sets error phase', () async {
    final backend = _FakeBackend()..fail = true;
    final c = ConversationController(backend: backend, speak: (_, _) async {}, userId: 'u1', personaId: 'sage');
    await c.submitUserText('hi');
    expect(c.state.phase, TalkPhase.error);
    expect(c.state.errorMessage, isNotNull);
  });

  test('switching personas after a turn clears conversation id and history', () async {
    final backend = _FakeBackend();
    final c = ConversationController(backend: backend, speak: (_, _) async {}, userId: 'u1', personaId: 'sage');
    await c.submitUserText('hi');
    expect(c.state.conversationId, 'c1');
    c.setPersona('nova');
    expect(c.state.activePersonaId, 'nova');
    expect(c.state.conversationId, isNull); // must reset — not leak into the new persona
    expect(c.state.messages, isEmpty);
  });

  test('voice loop records a turn, shows the transcript + reply, keeps listening', () async {
    final backend = _FakeBackend();
    final capture = _ScriptedCapture(1);
    final c = ConversationController(
        backend: backend, speak: (_, _) async {}, userId: 'u1', personaId: 'sage', capture: capture);
    unawaited(c.startConversation()); // the loop runs until stopped — don't await it
    await Future.delayed(const Duration(milliseconds: 100)); // let the turn settle
    expect(c.state.messages.map((m) => m.text), ['what you said', 'reply to what you said']);
    expect(c.state.phase, TalkPhase.listening); // parked, waiting for the next turn
    expect(c.conversing, true);
    await c.stopConversation();
    expect(c.conversing, false);
    expect(c.state.phase, TalkPhase.idle);
  });
}
