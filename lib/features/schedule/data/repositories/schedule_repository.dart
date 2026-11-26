import 'dart:math';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/dio_client.dart';
import '../../../home/data/models/meeting_summary.dart';
import '../models/schedule_meeting_request.dart';

part 'schedule_repository.g.dart';

abstract interface class ScheduleRepository {
  Future<Result<MeetingSummary>> scheduleMeeting(
    ScheduleMeetingRequest request,
  );
}

class MockScheduleRepository implements ScheduleRepository {
  static const String _alphabet = 'abcdefghijkmnpqrstuvwxyz';
  final Random _random = Random();

  @override
  Future<Result<MeetingSummary>> scheduleMeeting(
    ScheduleMeetingRequest request,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final code = '${_segment(3)}-${_segment(4)}-${_segment(3)}';
    return Success(
      MeetingSummary(
        id: 'm-${DateTime.now().millisecondsSinceEpoch}',
        title: request.title.trim(),
        code: code,
        startTime: request.startTime,
        durationMinutes: request.durationMinutes,
        hostName: 'You',
        participantCount: request.invitees.length + 1,
      ),
    );
  }

  String _segment(int length) {
    return List.generate(
      length,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
  }
}

class RemoteScheduleRepository extends BaseRepository
    implements ScheduleRepository {
  const RemoteScheduleRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<MeetingSummary>> scheduleMeeting(
    ScheduleMeetingRequest request,
  ) {
    return guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.createMeeting,
        data: request.toJson(),
      );
      return MeetingSummary.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    });
  }
}

@Riverpod(keepAlive: true)
ScheduleRepository scheduleRepository(Ref ref) {
  final useMock = ref.watch(useMockApiProvider);
  if (useMock) {
    return MockScheduleRepository();
  }
  return RemoteScheduleRepository(ref.watch(dioClientProvider));
}
