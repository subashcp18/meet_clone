import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/meeting_summary.dart';
import '../data/repositories/home_repository.dart';

part 'home_provider.g.dart';

enum HomeTab { meet, calendar }

@riverpod
class HomeTabNotifier extends _$HomeTabNotifier {
  @override
  HomeTab build() => HomeTab.meet;

  void select(HomeTab tab) {
    state = tab;
  }
}

@Riverpod(keepAlive: true)
class UpcomingMeetingsNotifier extends _$UpcomingMeetingsNotifier {
  // region: BUILD
  @override
  Future<List<MeetingSummary>> build() async {
    return _fetchMeetings();
  }
  // endregion

  // region: ACTIONS
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchMeetings);
  }

  void addMeeting(MeetingSummary meeting) {
    final current = state.asData?.value ?? const <MeetingSummary>[];
    final updated = [...current, meeting]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    state = AsyncData(updated);
  }

  Future<List<MeetingSummary>> _fetchMeetings() async {
    final result = await ref.read(homeRepositoryProvider).getUpcomingMeetings();
    return result.when(
      success: (meetings) => meetings,
      failure: (exception) => throw exception,
    );
  }
  // endregion
}
