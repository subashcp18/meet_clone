import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  const AuthInterceptor({required this.readAccessToken});

  final String? Function() readAccessToken;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
