import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/app_settings.dart';

void main() {
  test('copyWith and json roundtrip', () {
    const s = AppSettings(backendUrl: 'http://x', bearerToken: 't', userId: 'u');
    final s2 = s.copyWith(userId: 'u2');
    expect(s2.userId, 'u2');
    expect(s2.backendUrl, 'http://x');
    final restored = AppSettings.fromJson(s2.toJson());
    expect(restored.userId, 'u2');
  });
}
