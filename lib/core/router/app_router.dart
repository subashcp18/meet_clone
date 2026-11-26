import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
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
        builder: (context, state) => const _RoutePlaceholderScreen(
          title: AppConstants.appName,
          subtitle: 'Splash',
        ),
      ),
      GoRoute(
        path: RouteNames.loginPath,
        name: RouteNames.login,
        builder: (context, state) => const _RoutePlaceholderScreen(
          title: 'Sign in',
        ),
      ),
      GoRoute(
        path: RouteNames.homePath,
        name: RouteNames.home,
        builder: (context, state) => const _RoutePlaceholderScreen(
          title: 'Home',
        ),
      ),
      GoRoute(
        path: RouteNames.schedulePath,
        name: RouteNames.schedule,
        builder: (context, state) => const _RoutePlaceholderScreen(
          title: 'Schedule meeting',
        ),
      ),
      GoRoute(
        path: RouteNames.lobbyPath,
        name: RouteNames.lobby,
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return _RoutePlaceholderScreen(
            title: 'Lobby',
            subtitle: code,
          );
        },
      ),
      GoRoute(
        path: RouteNames.meetingPath,
        name: RouteNames.meeting,
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return Theme(
            data: AppTheme.callTheme,
            child: _RoutePlaceholderScreen(
              title: 'Meeting',
              subtitle: code,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.settingsPath,
        name: RouteNames.settings,
        builder: (context, state) => const _RoutePlaceholderScreen(
          title: 'Settings',
        ),
      ),
    ],
    // endregion
  );
});

class _RoutePlaceholderScreen extends StatelessWidget {
  const _RoutePlaceholderScreen({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(subtitle ?? title),
      ),
    );
  }
}
