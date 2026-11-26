import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/join_with_code_screen.dart';
import '../../features/meeting/presentation/in_call/in_call_screen.dart';
import '../../features/meeting/presentation/lobby/lobby_screen.dart';
import '../../features/schedule/presentation/screens/schedule_meeting_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import 'route_names.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: RouteNames.splashPath,
    refreshListenable: refreshNotifier,
    // region: REDIRECT
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;

      if (authState.status == AuthStatus.unknown) {
        return location == RouteNames.splashPath
            ? null
            : RouteNames.splashPath;
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return location == RouteNames.loginPath ? null : RouteNames.loginPath;
      }

      if (location == RouteNames.splashPath ||
          location == RouteNames.loginPath) {
        return RouteNames.homePath;
      }

      return null;
    },
    // endregion
    // region: ROUTES
    routes: [
      GoRoute(
        path: RouteNames.splashPath,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.homePath,
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RouteNames.joinPath,
        name: RouteNames.join,
        builder: (context, state) => const JoinWithCodeScreen(),
      ),
      GoRoute(
        path: RouteNames.schedulePath,
        name: RouteNames.schedule,
        builder: (context, state) => const ScheduleMeetingScreen(),
      ),
      GoRoute(
        path: RouteNames.lobbyPath,
        name: RouteNames.lobby,
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return LobbyScreen(code: code);
        },
      ),
      GoRoute(
        path: RouteNames.meetingPath,
        name: RouteNames.meeting,
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return InCallScreen(code: code);
        },
      ),
      GoRoute(
        path: RouteNames.settingsPath,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    // endregion
  );
});
