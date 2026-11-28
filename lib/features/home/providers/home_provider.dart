import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/providers/auth_provider.dart';
import '../../meeting/data/models/open_meeting.dart';
import '../../meeting/data/repositories/meeting_repository.dart';

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
  Future<List<OpenMeeting>> build() async {
    final userId = ref.watch(authControllerProvider).asData?.value?.id;
    if (userId == null) {
      return const <OpenMeeting>[];
    }
    return _fetchMeetings();
  }
  // endregion

  // region: ACTIONS
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchMeetings);
  }

  Future<List<OpenMeeting>> _fetchMeetings() async {
    final result = await ref.read(meetingRepositoryProvider).listOpenMeetings();
    return result.when(
      success: (meetings) => meetings,
      failure: (exception) => throw exception,
    );
  }
  // endregion
}
