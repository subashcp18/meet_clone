import 'dart:math';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/dio_client.dart';
import '../models/meeting_summary.dart';

part 'home_repository.g.dart';

abstract interface class HomeRepository {
  Future<Result<List<MeetingSummary>>> getUpcomingMeetings();
  Future<Result<MeetingSummary>> createInstantMeeting();
  Future<Result<MeetingSummary>> lookupMeetingByCode(String code);
}

class MockHomeRepository implements HomeRepository {
  static const String _alphabet = 'abcdefghijkmnpqrstuvwxyz';
  final Random _random = Random();

  List<MeetingSummary> _mockUpcoming() {
    final now = DateTime.now();
    final todayBase = DateTime(now.year, now.month, now.day, 14, 30);

    return [
      MeetingSummary(
        id: 'm-1',
        title: 'Product Design Sync',
        code: 'abc-defg-hij',
        startTime: todayBase,
        durationMinutes: 45,
        hostName: 'Alex Morgan',
        participantCount: 6,
        isLive: true,
      ),
      MeetingSummary(
        id: 'm-2',
        title: 'Flutter Architecture Review',
        code: 'kmn-pqrs-tuv',
        startTime: todayBase.add(const Duration(hours: 2)),
        durationMinutes: 30,
        hostName: 'Sam Rivera',
        participantCount: 4,
      ),
      MeetingSummary(
        id: 'm-3',
        title: 'Weekly Sprint Planning',
        code: 'wxy-zabc-def',
        startTime: todayBase.add(const Duration(days: 1, hours: -4)),
        durationMinutes: 60,
        hostName: 'Jordan Lee',
        participantCount: 9,
      ),
    ];
  }

  @override
  Future<Result<List<MeetingSummary>>> getUpcomingMeetings() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return Success(_mockUpcoming());
  }

  @override
  Future<Result<MeetingSummary>> createInstantMeeting() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final code = '${_segment(3)}-${_segment(4)}-${_segment(3)}';
    final now = DateTime.now();

    return Success(
      MeetingSummary(
        id: 'm-${now.millisecondsSinceEpoch}',
        title: 'Instant meeting',
        code: code,
        startTime: now,
        durationMinutes: 60,
        hostName: 'You',
        participantCount: 1,
        isLive: true,
      ),
    );
  }

  @override
  Future<Result<MeetingSummary>> lookupMeetingByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final existing = _mockUpcoming().where((m) => m.code == code).firstOrNull;
    if (existing != null) {
      return Success(existing);
    }
    return Success(
      MeetingSummary(
        id: 'm-$code',
        title: 'Meeting ($code)',
        code: code,
        startTime: DateTime.now(),
        durationMinutes: 60,
        hostName: 'Host',
        participantCount: 2,
        isLive: true,
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

class RemoteHomeRepository extends BaseRepository implements HomeRepository {
  const RemoteHomeRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<List<MeetingSummary>>> getUpcomingMeetings() {
    return guard(() async {
      final response = await _dio.get<List<dynamic>>(ApiEndpoints.meetings);
      final items = response.data ?? const <dynamic>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map(MeetingSummary.fromJson)
          .toList();
    });
  }

  @override
  Future<Result<MeetingSummary>> createInstantMeeting() {
    return guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.createMeeting,
      );
      return MeetingSummary.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<Result<MeetingSummary>> lookupMeetingByCode(String code) {
    return guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.meetingByCode(code),
      );
      return MeetingSummary.fromJson(response.data ?? const <String, dynamic>{});
    });
  }
}

@Riverpod(keepAlive: true)
HomeRepository homeRepository(Ref ref) {
  final useMock = ref.watch(useMockApiProvider);
  if (useMock) {
    return MockHomeRepository();
  }
  return RemoteHomeRepository(ref.watch(dioClientProvider));
}
