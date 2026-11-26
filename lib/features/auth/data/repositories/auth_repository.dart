import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/dio_client.dart';

part 'auth_repository.g.dart';

abstract interface class AuthRepository {
  Future<Result<String>> signInWithEmail(String email);
  Future<Result<void>> signOut();
  Future<Result<String?>> getCurrentUserEmail();
}

class MockAuthRepository implements AuthRepository {
  String? _currentEmail;

  @override
  Future<Result<String>> signInWithEmail(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _currentEmail = email.trim();
    return Success(_currentEmail!);
  }

  @override
  Future<Result<void>> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _currentEmail = null;
    return const Success(null);
  }

  @override
  Future<Result<String?>> getCurrentUserEmail() async {
    return Success(_currentEmail);
  }
}

class RemoteAuthRepository extends BaseRepository implements AuthRepository {
  const RemoteAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<String>> signInWithEmail(String email) {
    return guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {'email': email.trim()},
      );
      final user = response.data?['email'] as String?;
      return user ?? email.trim();
    });
  }

  @override
  Future<Result<void>> signOut() {
    return guard(() async {
      await _dio.post<void>(ApiEndpoints.logout);
    });
  }

  @override
  Future<Result<String?>> getCurrentUserEmail() {
    return guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.currentUser,
      );
      return response.data?['email'] as String?;
    });
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final useMock = ref.watch(useMockApiProvider);
  if (useMock) {
    return MockAuthRepository();
  }
  return RemoteAuthRepository(ref.watch(dioClientProvider));
}
