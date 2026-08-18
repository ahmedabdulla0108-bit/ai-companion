import 'dart:convert';
import 'dart:typed_data';

class ChatResult {
  final String replyText;
  final Uint8List? audioBytes;
  final String conversationId;
  final String userText; // what the backend heard (Whisper transcript), if any
  const ChatResult({
    required this.replyText,
    required this.audioBytes,
    required this.conversationId,
    this.userText = '',
  });

  factory ChatResult.fromJson(Map<String, dynamic> j) {
    final audio = j['audio'] as String?;
    return ChatResult(
      replyText: j['replyText'] as String,
      audioBytes: audio == null ? null : base64Decode(audio),
      conversationId: j['conversationId'] as String,
      userText: j['userText'] as String? ?? '',
    );
  }
}
