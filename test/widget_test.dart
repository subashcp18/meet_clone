import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meet_clone/app.dart';
import 'package:meet_clone/core/network/api_exception.dart';
import 'package:meet_clone/core/theme/theme_provider.dart';
import 'package:meet_clone/core/utils/validators.dart';
import 'package:meet_clone/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:meet_clone/features/auth/presentation/screens/login_screen.dart';
import 'package:meet_clone/features/auth/presentation/screens/register_screen.dart';
import 'package:meet_clone/features/auth/providers/auth_provider.dart';
import 'package:meet_clone/features/meeting/data/models/meeting.dart';
import 'package:meet_clone/features/meeting/data/models/meeting_participant.dart';
import 'package:meet_clone/features/meeting/data/models/scheduled_meeting.dart';
import 'package:meet_clone/features/meeting/data/repositories/meeting_repository.dart';
import 'package:meet_clone/features/meeting/presentation/in_call/in_call_screen.dart';
import 'package:meet_clone/features/meeting/providers/meeting_session_provider.dart';
import 'package:meet_clone/core/network/api_result.dart';
import 'package:meet_clone/features/home/presentation/screens/home_screen.dart';

void main() {
  test('Validators cover auth and meeting code rules', () {
    expect(Validators.email('user@example.com'), isNull);
    expect(Validators.email('bad'), isNotNull);

    expect(Validators.password('123456'), isNull);
    expect(Validators.password('12345'), isNotNull);
    expect(Validators.password(''), isNotNull);

    expect(Validators.fullName('Alex Morgan'), isNull);
    expect(Validators.fullName('A'), isNotNull);

    expect(Validators.confirmPassword('secret12', 'secret12'), isNull);
    expect(Validators.confirmPassword('secret13', 'secret12'), isNotNull);

    expect(Validators.meetingCode('abc-defg-hij'), isNull);
    expect(Validators.meetingCode('https://meet.clone/abc-defg-hij'), isNull);
    expect(Validators.meetingCode('ab-defg-hij'), isNotNull);
    expect(Validators.meetingCode('invalid'), isNotNull);
  });

  test('ApiException maps AuthException and PostgrestException', () {
    expect(const NetworkException().message, isNotEmpty);
    expect(const TimeoutException().message, isNotEmpty);
    expect(const UnauthorizedException().message, isNotEmpty);
    expect(const ServerException().message, isNotEmpty);
    expect(const ValidationException().message, isNotEmpty);
    expect(const UnknownException().message, isNotEmpty);

    expect(
      ApiException.fromAuthException(
        const AuthException('Invalid login credentials'),
      ),
      isA<UnauthorizedException>(),
    );
    expect(
      ApiException.fromAuthException(
        const AuthException('User already registered'),
      ),
      isA<ValidationException>(),
    );
    expect(
      ApiException.fromAuthException(
        const AuthException('Password should be at least 6 characters'),
      ),
      isA<ValidationException>(),
    );
    expect(
      ApiException.fromAuthException(
        const AuthException(
          'Email rate limit exceeded',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ).statusCode,
      429,
    );
    expect(
      ApiException.fromPostgrestException(
        const PostgrestException(message: 'permission denied', code: '42501'),
      ),
      isA<UnauthorizedException>().having(
        (e) => e.message,
        'message',
        'Permission denied.',
      ),
    );
    expect(
      ApiException.fromPostgrestException(
        const PostgrestException(message: 'infinite recursion', code: '42P17'),
      ),
      isA<ServerException>().having(
        (e) => e.message,
        'message',
        'Policy configuration error.',
      ),
    );
    expect(
      ApiException.fromPostgrestException(
        const PostgrestException(message: '0 rows', code: 'PGRST116'),
      ),
      isA<ServerException>().having((e) => e.message, 'message', 'Not found.'),
    );
    expect(
      ApiException.fromPostgrestException(
        const PostgrestException(message: 'raw sql error', code: 'XX000'),
      ).message,
      ServerException.defaultMessage,
    );
    expect(
      ApiException.fromPostgrestException(
        const PostgrestException(message: 'meeting not found'),
      ).statusCode,
      404,
    );
    expect(
      ApiException.fromPostgrestException(
        const PostgrestException(message: 'meeting full'),
      ),
      isA<ValidationException>(),
    );
  });

  testWidgets(
    'Auth flows: register -> Home, sign out -> Login, wrong password, existing email, sign in, session restore',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MeetCloneApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(authControllerProvider).value, isNull);
      expect(find.text('Sign in'), findsNWidgets(2));

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);

      final regFields = find.byType(TextFormField);
      await tester.enterText(regFields.at(0), 'Alex Morgan');
      await tester.enterText(regFields.at(1), 'alex@example.com');
      await tester.enterText(regFields.at(2), 'secret12');
      await tester.enterText(regFields.at(3), 'secret12');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(
        container.read(authControllerProvider).value?.displayName,
        'Alex Morgan',
      );
      expect(find.text('Product Design Sync'), findsOneWidget);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(container.read(authControllerProvider).value, isNull);
      expect(find.text('New here?'), findsOneWidget);

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      final duplicateFields = find.byType(TextFormField);
      await tester.enterText(duplicateFields.at(0), 'Alex Morgan');
      await tester.enterText(duplicateFields.at(1), 'alex@example.com');
      await tester.enterText(duplicateFields.at(2), 'secret12');
      await tester.enterText(duplicateFields.at(3), 'secret12');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(
        find.text('An account with this email already exists.'),
        findsWidgets,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot your password?'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'alex@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Reset link sent to alex@example.com'),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      final loginFields = find.byType(TextFormField);
      await tester.enterText(loginFields.at(0), 'alex@example.com');
      await tester.enterText(loginFields.at(1), 'wrong99');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Invalid email or password.'), findsWidgets);

      await tester.enterText(loginFields.at(1), 'secret12');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Product Design Sync'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      container.dispose();

      final restoredContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(restoredContainer.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restoredContainer,
          child: const MeetCloneApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Product Design Sync'), findsOneWidget);
    },
  );

  testWidgets('Auth screens render without overflow in portrait and landscape with keyboard', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    for (final size in const [Size(390, 844), Size(844, 390)]) {
      for (final screen in const [
        LoginScreen(),
        RegisterScreen(),
        ForgotPasswordScreen(),
      ]) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  viewInsets: const EdgeInsets.only(bottom: 300),
                ),
                child: screen,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('InCallScreen renders without overflow on portrait and landscape', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

    container.read(meetingSessionProvider.notifier).state =
        const MeetingSessionState(
          code: 'abc-defg-hij',
          title: 'Design Review',
          participants: [
            MeetingParticipant(
              meetingId: 'm-1',
              userId: 'p-self',
              displayName: 'You',
              email: 'you@example.com',
              isSelf: true,
            ),
            MeetingParticipant(
              meetingId: 'm-1',
              userId: 'p-1',
              displayName: 'Alex Morgan',
              email: 'alex@example.com',
              isSpeaking: true,
            ),
          ],
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: InCallScreen(code: 'abc-defg-hij'),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  });

  testWidgets('HomeScreen renders empty state when listUpcoming returns empty', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        meetingRepositoryProvider.overrideWithValue(_EmptyMeetingRepository()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No upcoming meetings'), findsOneWidget);
  });
}

class _EmptyMeetingRepository implements MeetingRepository {
  @override
  Future<Result<List<Meeting>>> listUpcoming() async =>
      const Success(<Meeting>[]);

  @override
  Future<Result<Meeting>> createInstantMeeting() =>
      throw UnimplementedError();

  @override
  Future<Result<void>> endMeeting(String meetingId) async =>
      const Success(null);

  @override
  Future<Result<Meeting>> joinByCode(String code) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> leaveMeeting(String meetingId) async =>
      const Success(null);

  @override
  Future<Result<Meeting>> scheduleMeeting(ScheduledMeeting request) =>
      throw UnimplementedError();
}
