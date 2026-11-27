import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

sealed class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  static String friendlyMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    if (error is AuthException) {
      return ApiException.fromAuthException(error).message;
    }
    if (error is PostgrestException) {
      return ApiException.fromPostgrestException(error).message;
    }
    if (error is DioException) {
      final mapped = error.error;
      if (mapped is ApiException) {
        return mapped.message;
      }
      return ApiException.fromDioException(error).message;
    }
    return UnknownException.defaultMessage;
  }

  factory ApiException.fromAuthException(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return const NetworkException();
    }
    final normalized = error.message.toLowerCase();
    final code = error.code?.toLowerCase() ?? '';
    if (code == 'invalid_credentials' ||
        normalized.contains('invalid login credentials') ||
        normalized.contains('invalid credentials')) {
      return const UnauthorizedException(
        message: 'Invalid email or password.',
      );
    }
    if (code == 'user_already_exists' ||
        normalized.contains('already registered') ||
        normalized.contains('already exists')) {
      return const ValidationException(
        message: 'An account with this email already exists.',
      );
    }
    if (code == 'weak_password' ||
        normalized.contains('weak password') ||
        normalized.contains('password should be at least')) {
      return const ValidationException(
        message: 'Password is too weak. Use at least 6 characters.',
      );
    }
    if (code == 'email_not_confirmed' ||
        normalized.contains('email not confirmed')) {
      return const UnauthorizedException(
        message: 'Please confirm your email address before signing in.',
      );
    }
    if (error.statusCode == '429' ||
        code.contains('rate_limit') ||
        normalized.contains('rate limit') ||
        normalized.contains('too many requests') ||
        normalized.contains('for security purposes')) {
      return const ServerException(
        message: 'Too many attempts. Please wait a moment and try again.',
        statusCode: 429,
      );
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network')) {
      return const NetworkException();
    }
    return ServerException(
      message: error.message.isNotEmpty
          ? error.message
          : ServerException.defaultMessage,
      statusCode: int.tryParse(error.statusCode ?? ''),
    );
  }

  factory ApiException.fromPostgrestException(PostgrestException error) {
    final normalized = error.message.toLowerCase();
    final code = error.code?.toUpperCase() ?? '';
    if (code == '42501' || normalized.contains('permission denied')) {
      return const UnauthorizedException(
        message: 'Permission denied.',
        statusCode: 403,
      );
    }
    if (code == '42P17') {
      return const ServerException(
        message: 'Policy configuration error.',
        statusCode: 500,
      );
    }
    if (code == 'PGRST116') {
      return const ServerException(
        message: 'Not found.',
        statusCode: 404,
      );
    }
    if (normalized.contains('meeting not found')) {
      return const ServerException(
        message: 'Meeting not found. Check the code and try again.',
        statusCode: 404,
      );
    }
    if (normalized.contains('meeting ended')) {
      return const ValidationException(
        message: 'This meeting has already ended.',
      );
    }
    if (normalized.contains('meeting full')) {
      return const ValidationException(
        message: 'This meeting is full (maximum 5 participants).',
      );
    }
    if (normalized.contains('not signed in')) {
      return const UnauthorizedException();
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('network')) {
      return const NetworkException();
    }
    return const ServerException();
  }

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
        return UnknownException(
          message: error.message ?? UnknownException.defaultMessage,
        );
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
    if (statusCode == 403) {
      return UnauthorizedException(
        message: serverMessage ?? 'You do not have permission to do that.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 404) {
      return ServerException(
        message:
            serverMessage ?? 'The requested meeting or resource was not found.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 408) {
      return TimeoutException(
        message: serverMessage ?? TimeoutException.defaultMessage,
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
    if (statusCode == 429) {
      return ServerException(
        message:
            serverMessage ?? 'Too many requests. Please wait and try again.',
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
