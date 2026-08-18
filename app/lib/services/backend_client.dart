import 'package:dio/dio.dart';
import 'package:app/models/persona.dart';
import 'package:app/models/chat_result.dart';

abstract class BackendClient {
  Future<List<Persona>> listPersonas();
  Future<ChatResult> chat({
    required String userId,
    required String personaId,
    required String text,
    String? conversationId,
  });
}

class DioBackendClient implements BackendClient {
  final Dio _dio;
  final String baseUrl;
  final String token;
  DioBackendClient(this._dio, {required this.baseUrl, required this.token});

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
    required String text,
    String? conversationId,
  }) async {
    final resp = await _dio.post('$baseUrl/chat', options: _opts, data: {
      'userId': userId,
      'personaId': personaId,
      'text': text,
      if (conversationId != null) 'conversationId': conversationId,
    });
    return ChatResult.fromJson(resp.data as Map<String, dynamic>);
  }
}
