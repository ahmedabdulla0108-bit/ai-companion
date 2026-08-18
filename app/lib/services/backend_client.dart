import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:app/models/persona.dart';
import 'package:app/models/chat_result.dart';

abstract class BackendClient {
  Future<List<Persona>> listPersonas();
  Future<ChatResult> chat({
    required String userId,
    required String personaId,
    String text = '',
    Uint8List? audioBytes,
    String? conversationId,
  });
}

class DioBackendClient implements BackendClient {
  final Dio _dio;
  final String baseUrl;
  final String token;
  DioBackendClient(this._dio, {required this.baseUrl, required this.token}) {
    // v1 runs the backend locally over http on the LAN, so http:// is allowed.
    // But over http the bearer token and chat contents travel unencrypted, so
    // warn (debug builds only) — anything beyond local/LAN testing should use
    // https://. See the security note in the spec/READMEs.
    assert(() {
      if (baseUrl.startsWith('http://')) {
        debugPrint(
          'BackendClient: insecure http:// backend URL — bearer token and chat '
          'contents are sent unencrypted. Use https:// beyond local/LAN testing.',
        );
      }
      return true;
    }());
  }

  Options get _opts => Options(headers: {'Authorization': 'Bearer $token'});

  @override
  Future<List<Persona>> listPersonas() async {
    final resp = await _dio.get('$baseUrl/personas', options: _opts);
    return (resp.data as List).map((e) => Persona.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ChatResult> chat({
    required String userId,
    required String personaId,
    String text = '',
    Uint8List? audioBytes,
    String? conversationId,
  }) async {
    final resp = await _dio.post('$baseUrl/chat', options: _opts, data: {
      'userId': userId,
      'personaId': personaId,
      if (text.isNotEmpty) 'text': text,
      if (audioBytes != null) 'audio': base64Encode(audioBytes),
      if (conversationId != null) 'conversationId': conversationId,
    });
    return ChatResult.fromJson(resp.data as Map<String, dynamic>);
  }
}
