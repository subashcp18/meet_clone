import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_env.dart';
import 'api_interceptor.dart';
import 'auth_interceptor.dart';
import 'supabase_provider.dart';

part 'dio_client.g.dart';

@Riverpod(keepAlive: true)
Dio dioClient(Ref ref) {
  const timeout = Duration(seconds: 30);
  final baseOptions = BaseOptions(
    baseUrl: AppEnv.edgeFunctionsBaseUrl,
    connectTimeout: timeout,
    receiveTimeout: timeout,
    sendTimeout: timeout,
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  );

  final useMock = ref.watch(useMockApiProvider);
  final dio = Dio(baseOptions)
    ..interceptors.addAll([
      AuthInterceptor(
        readAccessToken: useMock
            ? () => null
            : () => ref
                .read(supabaseClientProvider)
                .auth
                .currentSession
                ?.accessToken,
      ),
      const ApiInterceptor(),
      if (kDebugMode) ApiInterceptor.debugLogger(),
    ]);

  return dio;
}
