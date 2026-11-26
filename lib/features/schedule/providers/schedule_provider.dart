import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../home/data/models/meeting_summary.dart';
import '../../home/providers/home_provider.dart';
import '../data/models/schedule_meeting_request.dart';
import '../data/repositories/schedule_repository.dart';

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

  Future<MeetingSummary?> submit(ScheduleMeetingRequest request) async {
    state = const ScheduleState(isSubmitting: true);
    final result = await ref
        .read(scheduleRepositoryProvider)
        .scheduleMeeting(request);

    return result.when(
      success: (meeting) {
        ref.read(upcomingMeetingsProvider.notifier).addMeeting(meeting);
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
