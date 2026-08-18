// app/test/audio_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/audio_service.dart';

void main() {
  test('chooses fallback when no bytes', () {
    expect(shouldUseFallback(null), true);
    expect(shouldUseFallback([1, 2, 3]), false);
  });
}
