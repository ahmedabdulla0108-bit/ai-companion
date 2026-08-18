// app/test/persona_picker_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/persona.dart';
import 'package:app/models/chat_result.dart';
import 'package:app/services/backend_client.dart';
import 'package:app/state/providers.dart';
import 'package:app/screens/persona_picker_screen.dart';

class _TwoPersonaBackend implements BackendClient {
  @override
  Future<List<Persona>> listPersonas() async => const [
        Persona(id: 'sage', name: 'Sage', description: 'calm', greeting: 'g'),
        Persona(id: 'nova', name: 'Nova', description: 'bright', greeting: 'g'),
      ];
  @override
  Future<ChatResult> chat({required String userId, required String personaId, String text = '', Uint8List? audioBytes, String? conversationId}) async =>
      ChatResult(replyText: '', audioBytes: null, conversationId: 'c1');
}

void main() {
  testWidgets('lists personas from backend', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [backendClientProvider.overrideWithValue(_TwoPersonaBackend())],
      child: const MaterialApp(home: PersonaPickerScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sage'), findsOneWidget);
    expect(find.text('Nova'), findsOneWidget);
  });
}
