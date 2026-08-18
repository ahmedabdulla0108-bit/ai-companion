import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/chat_result.dart';
import 'package:app/models/persona.dart';

void main() {
  test('ChatResult decodes base64 audio', () {
    final audio = base64Encode([1, 2, 3]);
    final r = ChatResult.fromJson({
      'replyText': 'hi', 'audio': audio, 'conversationId': 'c1',
    });
    expect(r.replyText, 'hi');
    expect(r.conversationId, 'c1');
    expect(r.audioBytes, isNotNull);
    expect(r.audioBytes!.toList(), [1, 2, 3]);
  });

  test('ChatResult tolerates null audio', () {
    final r = ChatResult.fromJson({
      'replyText': 'hi', 'audio': null, 'conversationId': 'c1',
    });
    expect(r.audioBytes, isNull);
  });

  test('Persona parses', () {
    final p = Persona.fromJson({'id': 'sage', 'name': 'Sage', 'description': 'd', 'greeting': 'g'});
    expect(p.name, 'Sage');
  });
}
