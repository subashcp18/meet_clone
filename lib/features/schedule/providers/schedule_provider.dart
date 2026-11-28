import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../home/providers/home_provider.dart';
import '../../meeting/data/models/meeting.dart';
import '../../meeting/data/models/scheduled_meeting.dart';
import '../../meeting/data/repositories/meeting_repository.dart';

part 'schedule_provider.g.dart';

@immutable
class ScheduleState {
  const ScheduleState({
    this.isSubmitting = false,
    this.errorMessage,
  });

  final bool isSubmitting;
  final String? errorMessage;

  ScheduleState copyWith({
    bool? isSubmitting,
    String? errorMessage,
  }) {
    return ScheduleState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

@riverpod
class ScheduleController extends _$ScheduleController {
  @override
  ScheduleState build() => const ScheduleState();

  Future<Meeting?> submit(ScheduledMeeting request) async {
    state = const ScheduleState(isSubmitting: true);
    final result = await ref
        .read(meetingRepositoryProvider)
        .scheduleMeeting(request);

    return result.when(
      success: (meeting) {
        ref.invalidate(upcomingMeetingsProvider);
        state = const ScheduleState();
        return meeting;
      },
      failure: (exception) {
        state = ScheduleState(errorMessage: exception.message);
        return null;
      },
    );
  }
}
