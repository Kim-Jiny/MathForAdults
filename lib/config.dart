/// 앱 전역 설정. 빌드 시 --dart-define 으로 주입 가능.
class AppConfig {
  AppConfig._();

  /// Minigame 서버의 성인의 수학 API 베이스.
  static const apiBase = 'https://duo.jiny.shop/api/mathforadults';

  /// Google 웹 OAuth 클라이언트 ID (서버 토큰 검증 audience).
  /// Google Cloud Console에서 발급 후 빌드 시 주입:
  ///   flutter build ... --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');
}
