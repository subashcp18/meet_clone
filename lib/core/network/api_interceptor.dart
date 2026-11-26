import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'api_exception.dart';

class ApiInterceptor extends Interceptor {
  const ApiInterceptor();

  static Interceptor debugLogger() {
    return PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
      enabled: kDebugMode,
    );
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('Accept', () => 'application/json');
    options.headers.putIfAbsent('Content-Type', () => 'application/json');
    options.headers.putIfAbsent('X-Client-Platform', () => defaultTargetPlatform.name);
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final mapped = ApiException.fromDioException(err);
    handler.next(err.copyWith(error: mapped));
  }
}
