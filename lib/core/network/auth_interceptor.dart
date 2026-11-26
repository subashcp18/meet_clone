import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_endpoints.dart';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required FlutterSecureStorage secureStorage,
    required Dio refreshDio,
    required VoidCallback onSessionExpired,
  }) : _secureStorage = secureStorage,
       _refreshDio = refreshDio,
       _onSessionExpired = onSessionExpired;

  // region: CONSTANTS & DEPENDENCIES
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String _retriedExtraKey = '_auth_retried';

  final FlutterSecureStorage _secureStorage;
  final Dio _refreshDio;
  final VoidCallback _onSessionExpired;
  // endregion

  // region: INTERCEPTOR HOOKS
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.read(key: accessTokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_retriedExtraKey] == true;
    final isRefreshCall = err.requestOptions.path == ApiEndpoints.refreshToken;

    if (!isUnauthorized || alreadyRetried || isRefreshCall) {
      handler.next(err);
      return;
    }

    final refreshToken = await _secureStorage.read(key: refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearSession();
      handler.next(err);
      return;
    }

    try {
      final refreshResponse = await _refreshDio.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        data: {'refresh_token': refreshToken},
      );
      final body = refreshResponse.data;
      final newAccessToken = body?['access_token'] as String?;
      final newRefreshToken = body?['refresh_token'] as String?;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        await _clearSession();
        handler.next(err);
        return;
      }

      await _secureStorage.write(key: accessTokenKey, value: newAccessToken);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _secureStorage.write(
          key: refreshTokenKey,
          value: newRefreshToken,
        );
      }

      final retryOptions = err.requestOptions;
      retryOptions.extra[_retriedExtraKey] = true;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryResponse = await _refreshDio.fetch<dynamic>(retryOptions);
      handler.resolve(retryResponse);
    } on DioException catch (_) {
      await _clearSession();
      handler.next(err);
    }
  }
  // endregion

  // region: SESSION CLEANUP
  Future<void> _clearSession() async {
    await _secureStorage.delete(key: accessTokenKey);
    await _secureStorage.delete(key: refreshTokenKey);
    _onSessionExpired();
  }
  // endregion
}
