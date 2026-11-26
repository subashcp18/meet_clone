import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'api_result.dart';

abstract class BaseRepository {
  const BaseRepository();

  Future<Result<T>> guard<T>(Future<T> Function() call) async {
    try {
      final data = await call();
      return Success(data);
    } on DioException catch (error) {
      final mapped = error.error;
      if (mapped is ApiException) {
        return Failure(mapped);
      }
      return Failure(ApiException.fromDioException(error));
    } on ApiException catch (error) {
      return Failure(error);
    } catch (error) {
      return Failure(UnknownException(message: error.toString()));
    }
  }
}
