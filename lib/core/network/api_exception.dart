import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badCertificate:
        return const NetworkException(
          message: 'Unable to establish a secure connection.',
        );
      case DioExceptionType.cancel:
        return const UnknownException(message: 'The request was cancelled.');
      case DioExceptionType.badResponse:
        return _fromStatusCode(error.response);
      case DioExceptionType.unknown:
        return UnknownException(message: error.message ?? UnknownException.defaultMessage);
    }
  }

  static ApiException _fromStatusCode(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final serverMessage = _extractMessage(response?.data);

    if (statusCode == 401) {
      return UnauthorizedException(
        message: serverMessage ?? UnauthorizedException.defaultMessage,
        statusCode: statusCode,
      );
    }
    if (statusCode == 400 || statusCode == 422) {
      return ValidationException(
        message: serverMessage ?? ValidationException.defaultMessage,
        statusCode: statusCode,
        fieldErrors: _extractFieldErrors(response?.data),
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return ServerException(
        message: serverMessage ?? ServerException.defaultMessage,
        statusCode: statusCode,
      );
    }
    return ServerException(
      message: serverMessage ?? ServerException.defaultMessage,
      statusCode: statusCode,
    );
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return null;
  }

  static Map<String, List<String>>? _extractFieldErrors(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final rawErrors = data['errors'];
    if (rawErrors is! Map<String, dynamic>) {
      return null;
    }
    final result = <String, List<String>>{};
    for (final entry in rawErrors.entries) {
      if (entry.value is List) {
        result[entry.key] = (entry.value as List).map((e) => '$e').toList();
      } else if (entry.value != null) {
        result[entry.key] = ['${entry.value}'];
      }
    }
    return result.isEmpty ? null : result;
  }

  @override
  String toString() => '$runtimeType(statusCode: $statusCode, message: $message)';
}

final class NetworkException extends ApiException {
  const NetworkException({
    super.message = defaultMessage,
    super.statusCode,
  });

  static const String defaultMessage =
      'No internet connection. Check your network and try again.';
}

final class TimeoutException extends ApiException {
  const TimeoutException({
    super.message = defaultMessage,
    super.statusCode,
  });

  static const String defaultMessage =
      'The request timed out. Please try again.';
}

final class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    super.message = defaultMessage,
    super.statusCode = 401,
  });

  static const String defaultMessage =
      'Your session has expired. Please sign in again.';
}

final class ServerException extends ApiException {
  const ServerException({
    super.message = defaultMessage,
    super.statusCode,
  });

  static const String defaultMessage =
      'Something went wrong on our end. Please try again later.';
}

final class ValidationException extends ApiException {
  const ValidationException({
    super.message = defaultMessage,
    super.statusCode = 422,
    this.fieldErrors,
  });

  static const String defaultMessage =
      'Please check your input and try again.';

  final Map<String, List<String>>? fieldErrors;
}

final class UnknownException extends ApiException {
  const UnknownException({
    super.message = defaultMessage,
    super.statusCode,
  });

  static const String defaultMessage =
      'An unexpected error occurred. Please try again.';
}
