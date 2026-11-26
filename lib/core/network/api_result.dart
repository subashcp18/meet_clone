import 'api_exception.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
    Success<T>(:final data) => data,
    Failure<T>() => null,
  };

  ApiException? get exceptionOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(:final exception) => exception,
  };

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException exception) failure,
  }) {
    return switch (this) {
      Success<T>(:final data) => success(data),
      Failure<T>(:final exception) => failure(exception),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.data);

  final T data;
}

final class Failure<T> extends Result<T> {
  const Failure(this.exception);

  final ApiException exception;
}
