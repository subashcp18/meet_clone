abstract final class RouteNames {
  // region: ROUTE NAMES
  static const String splash = 'splash';
  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgot-password';
  static const String home = 'home';
  static const String join = 'join';
  static const String schedule = 'schedule';
  static const String lobby = 'lobby';
  static const String meeting = 'meeting';
  static const String settings = 'settings';
  // endregion

  // region: ROUTE PATHS
  static const String splashPath = '/';
  static const String loginPath = '/login';
  static const String registerPath = '/register';
  static const String forgotPasswordPath = '/forgot-password';
  static const String homePath = '/home';
  static const String joinPath = '/join';
  static const String schedulePath = '/schedule';
  static const String lobbyPath = '/lobby/:code';
  static const String meetingPath = '/meeting/:code';
  static const String settingsPath = '/settings';
  // endregion

  // region: PATH BUILDERS
  static String lobbyLocation(String code) => '/lobby/$code';
  static String meetingLocation(String code) => '/meeting/$code';
  // endregion
}
