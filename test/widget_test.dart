import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meet_clone/app.dart';
import 'package:meet_clone/core/theme/theme_provider.dart';
import 'package:meet_clone/features/auth/providers/auth_provider.dart';

void main() {
  testWidgets('MeetCloneApp renders splash and redirects on auth change', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MeetCloneApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meet Clone'), findsOneWidget);

    await container.read(authProvider.notifier).checkSession();
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);

    unawaited(container.read(authProvider.notifier).signIn('user@example.com'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
  });
}
