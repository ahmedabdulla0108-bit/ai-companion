class AppSettings {
  final String backendUrl;
  final String bearerToken;
  final String userId;

  const AppSettings({
    required this.backendUrl,
    required this.bearerToken,
    required this.userId,
  });

  AppSettings copyWith({String? backendUrl, String? bearerToken, String? userId}) =>
      AppSettings(
        backendUrl: backendUrl ?? this.backendUrl,
        bearerToken: bearerToken ?? this.bearerToken,
        userId: userId ?? this.userId,
      );

  Map<String, dynamic> toJson() =>
      {'backendUrl': backendUrl, 'bearerToken': bearerToken, 'userId': userId};

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        backendUrl: j['backendUrl'] as String? ?? '',
        bearerToken: j['bearerToken'] as String? ?? '',
        userId: j['userId'] as String? ?? 'me',
      );

  static const empty = AppSettings(backendUrl: '', bearerToken: '', userId: 'me');

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.backendUrl == backendUrl &&
      other.bearerToken == bearerToken &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(backendUrl, bearerToken, userId);
}
