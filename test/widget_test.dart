import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meet_clone/app.dart';
import 'package:meet_clone/core/theme/theme_provider.dart';

void main() {
  testWidgets('MeetCloneApp renders smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MeetCloneApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meet Clone'), findsOneWidget);
  });
}
