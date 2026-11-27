import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/models/profile.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
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
    _subscription = ref.listen<AsyncValue<Profile?>>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<Profile?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  const publicAuthPaths = {
    RouteNames.loginPath,
    RouteNames.registerPath,
    RouteNames.forgotPasswordPath,
  };

  return GoRouter(
    initialLocation: RouteNames.splashPath,
    refreshListenable: refreshNotifier,
    // region: REDIRECT
    redirect: (context, state) {
      final authAsync = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (location == RouteNames.splashPath) {
        if (authAsync.isLoading || authAsync.hasError) {
          return null;
        }
        return authAsync.value != null
            ? RouteNames.homePath
            : RouteNames.loginPath;
      }

      if (publicAuthPaths.contains(location)) {
        if (authAsync.hasValue && authAsync.value != null) {
          return RouteNames.homePath;
        }
        return null;
      }

      if (authAsync.isLoading && !authAsync.hasValue) {
        return RouteNames.splashPath;
      }

      if (authAsync.value == null) {
        return RouteNames.loginPath;
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
        path: RouteNames.registerPath,
        name: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPasswordPath,
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
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
