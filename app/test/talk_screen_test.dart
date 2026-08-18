// app/test/talk_screen_test.dart
import 'dart:typed_data';
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
  Future<ChatResult> chat({required String userId, required String personaId, String text = '', Uint8List? audioBytes, String? conversationId}) async =>
      ChatResult(replyText: 'hi', audioBytes: null, conversationId: 'c1');
}

void main() {
  testWidgets('shows persona and start-conversation button when idle', (tester) async {
    final controller = ConversationController(
      backend: _NoopBackend(), speak: (_, _) async {}, userId: 'u', personaId: 'sage');
    await tester.pumpWidget(ProviderScope(
      overrides: [conversationControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: TalkScreen()),
    ));
    expect(find.textContaining('sage'), findsWidgets);
    expect(find.text('Start conversation'), findsOneWidget);
    expect(find.text('Tap to start talking'), findsOneWidget);
  });
}
