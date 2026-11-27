import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_exception.dart';
import 'api_result.dart';

abstract class BaseRepository {
  const BaseRepository();

  Future<Result<T>> guard<T>(Future<T> Function() call) async {
    try {
      final data = await call();
      return Success(data);
    } on AuthException catch (error) {
      return Failure(ApiException.fromAuthException(error));
    } on PostgrestException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'PostgrestException code=${error.code} message=${error.message} '
          'details=${error.details} hint=${error.hint}',
        );
      }
      return Failure(ApiException.fromPostgrestException(error));
    } on DioException catch (error) {
      final mapped = error.error;
      if (mapped is ApiException) {
        return Failure(mapped);
      }
      return Failure(ApiException.fromDioException(error));
    } on ApiException catch (error) {
      return Failure(error);
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('socketexception') ||
          text.contains('failed host lookup')) {
        return const Failure(NetworkException());
      }
      return Failure(UnknownException(message: error.toString()));
    }
  }
}
