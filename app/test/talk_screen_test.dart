// app/test/talk_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/conversation_controller.dart';
import 'package:app/state/providers.dart';
import 'package:app/screens/talk_screen.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/models/persona.dart';
import 'package:app/models/chat_result.dart';

class _NoopBackend implements BackendClient {
  @override
  Future<List<Persona>> listPersonas() async => [];
  @override
  Future<ChatResult> chat({required String userId, required String personaId, required String text, String? conversationId}) async =>
      ChatResult(replyText: 'hi', audioBytes: null, conversationId: 'c1');
}

void main() {
  testWidgets('shows persona and idle hint', (tester) async {
    final controller = ConversationController(
      backend: _NoopBackend(), speak: (_, __) async {}, userId: 'u', personaId: 'sage');
    await tester.pumpWidget(ProviderScope(
      overrides: [conversationControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: TalkScreen()),
    ));
    expect(find.textContaining('sage'), findsWidgets);
    expect(find.text('Hold to talk'), findsOneWidget);
  });
}
