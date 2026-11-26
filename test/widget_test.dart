import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meet_clone/app.dart';
import 'package:meet_clone/core/theme/theme_provider.dart';
import 'package:meet_clone/core/widgets/draggable_self_view.dart';
import 'package:meet_clone/features/auth/providers/auth_provider.dart';
import 'package:meet_clone/features/meeting/data/models/participant_model.dart';
import 'package:meet_clone/features/meeting/presentation/in_call/in_call_screen.dart';
import 'package:meet_clone/features/meeting/providers/in_call_ui_provider.dart';
import 'package:meet_clone/features/meeting/providers/meeting_session_provider.dart';

List<ParticipantModel> _buildParticipants(int count) {
  return List<ParticipantModel>.generate(count, (index) {
    if (index == 0) {
      return const ParticipantModel(
        id: 'p-self',
        name: 'You',
        email: 'you@example.com',
        isSelf: true,
      );
    }
    return ParticipantModel(
      id: 'p-$index',
      name: 'User $index',
      email: 'user$index@example.com',
      isSpeaking: index == 1,
      isMuted: index.isEven,
    );
  });
}

Future<ProviderContainer> _pumpInCallScreen(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  int participantCount = 5,
  Key? scopeKey,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  final participants = _buildParticipants(participantCount);
  container.read(meetingSessionProvider.notifier).state = MeetingSessionState(
    code: 'abc-defg-hij',
    title: 'Design Review',
    participants: participants,
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      key: scopeKey,
      container: container,
      child: const MaterialApp(
        home: InCallScreen(code: 'abc-defg-hij'),
      ),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _disposeInCallTree(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  container.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  testWidgets('InCallScreen toggles controls, auto-hides, and respects sheets', (
    WidgetTester tester,
  ) async {
    final container = await _pumpInCallScreen(tester);

    expect(container.read(inCallUiControllerProvider).controlsVisible, isTrue);

    await tester.tapAt(const Offset(100, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(inCallUiControllerProvider).controlsVisible, isFalse);

    await tester.tapAt(const Offset(100, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(inCallUiControllerProvider).controlsVisible, isTrue);

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(container.read(inCallUiControllerProvider).controlsVisible, isTrue);

    Navigator.of(tester.element(find.text('People (5)'))).pop();
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(inCallUiControllerProvider).controlsVisible, isFalse);

    await _disposeInCallTree(tester, container);
  });

  testWidgets('InCallScreen keeps controls visible when alone', (
    WidgetTester tester,
  ) async {
    final container = await _pumpInCallScreen(tester, participantCount: 1);

    await tester.pump(const Duration(seconds: 5));
    expect(container.read(inCallUiControllerProvider).controlsVisible, isTrue);

    await tester.tapAt(const Offset(100, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(inCallUiControllerProvider).controlsVisible, isTrue);

    await _disposeInCallTree(tester, container);
  });

  testWidgets('DraggableSelfView drags to corner and keeps state across rotation', (
    WidgetTester tester,
  ) async {
    final container = await _pumpInCallScreen(tester, size: const Size(360, 640));

    expect(
      container.read(selfViewPositionControllerProvider),
      SelfViewCorner.bottomRight,
    );

    final selfViewFinder = find.byType(DraggableSelfView);
    await tester.tap(selfViewFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(container.read(inCallUiControllerProvider).isSelfExpanded, isTrue);
    expect(container.read(inCallUiControllerProvider).controlsVisible, isTrue);

    await tester.drag(selfViewFinder, const Offset(-260, -400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      container.read(selfViewPositionControllerProvider),
      SelfViewCorner.topLeft,
    );

    await tester.pump(const Duration(seconds: 2));
    final elapsedBeforeRotate = container.read(inCallUiControllerProvider).elapsed;
    expect(elapsedBeforeRotate.inSeconds, greaterThanOrEqualTo(2));

    tester.view.physicalSize = const Size(640, 360);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      container.read(selfViewPositionControllerProvider),
      SelfViewCorner.topLeft,
    );
    expect(
      container.read(inCallUiControllerProvider).elapsed.inSeconds,
      greaterThanOrEqualTo(elapsedBeforeRotate.inSeconds),
    );

    await _disposeInCallTree(tester, container);
  });

  testWidgets('InCallScreen renders 1, 2, 3, 4, 6 participants without overflow on small phone and tablet', (
    WidgetTester tester,
  ) async {
    for (final size in const [
      Size(360, 640),
      Size(640, 360),
      Size(1024, 768),
    ]) {
      for (final count in const [1, 2, 3, 4, 6]) {
        final container = await _pumpInCallScreen(
          tester,
          size: size,
          participantCount: count,
          scopeKey: ValueKey('${size}_$count'),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await _disposeInCallTree(tester, container);
      }
    }
  });

  testWidgets('MeetCloneApp boots cleanly through splash and login', (
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
