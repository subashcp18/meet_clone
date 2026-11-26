import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/api_endpoints.dart';
import 'api_interceptor.dart';
import 'auth_interceptor.dart';

part 'dio_client.g.dart';

@Riverpod(keepAlive: true)
bool useMockApi(Ref ref) {
  return const bool.fromEnvironment('USE_MOCK_API', defaultValue: true);
}

@Riverpod(keepAlive: true)
FlutterSecureStorage secureStorage(Ref ref) {
  return const FlutterSecureStorage();
}

@Riverpod(keepAlive: true)
class SessionExpiredNotifier extends _$SessionExpiredNotifier {
  @override
  bool build() => false;

  void markExpired() {
    state = true;
  }

  void reset() {
    state = false;
  }
}

@Riverpod(keepAlive: true)
Dio dioClient(Ref ref) {
  const timeout = Duration(seconds: 30);
  final baseOptions = BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: timeout,
    receiveTimeout: timeout,
    sendTimeout: timeout,
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  );

  final refreshDio = Dio(baseOptions)
    ..interceptors.add(const ApiInterceptor());

  final storage = ref.watch(secureStorageProvider);
  final dio = Dio(baseOptions)
    ..interceptors.addAll([
      AuthInterceptor(
        secureStorage: storage,
        refreshDio: refreshDio,
        onSessionExpired: () {
          ref.read(sessionExpiredProvider.notifier).markExpired();
        },
      ),
      const ApiInterceptor(),
      if (kDebugMode) ApiInterceptor.debugLogger(),
    ]);

  return dio;
}
