import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/profile.dart';
import '../data/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

enum RegisterOutcome {
  signedIn,
  confirmationRequired,
  failed,
}

@immutable
class AuthFormState {
  const AuthFormState({
    this.isLoading = false,
    this.errorMessage,
    this.isSubmitted = false,
  });

  final bool isLoading;
  final String? errorMessage;
  final bool isSubmitted;

  AuthFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSubmitted,
  }) {
    return AuthFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSubmitted: isSubmitted ?? this.isSubmitted,
    );
  }
}

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  // region: STATE & BUILD
  StreamSubscription<Profile?>? _authSubscription;

  @override
  Future<Profile?> build() async {
    final repository = ref.watch(authRepositoryProvider);

    await _authSubscription?.cancel();
    _authSubscription = repository.authStateChanges.listen(
      (profile) {
        state = AsyncData(profile);
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );
    ref.onDispose(() {
      _authSubscription?.cancel();
      _authSubscription = null;
    });

    final result = await repository.getCurrentUser();
    return result.when(
      success: (user) => user,
      failure: (exception) => throw exception,
    );
  }
  // endregion

  // region: ACTIONS
  void setAuthenticatedUser(Profile profile) {
    state = AsyncData(profile);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }

  void retrySessionRestore() {
    ref.invalidateSelf();
  }
  // endregion
}

@riverpod
class LoginController extends _$LoginController {
  @override
  AuthFormState build() => const AuthFormState();

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  Future<bool> submit({
    required String email,
    required String password,
  }) async {
    state = const AuthFormState(isLoading: true);
    final result = await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
    return result.when(
      success: (profile) {
        ref.read(authControllerProvider.notifier).setAuthenticatedUser(profile);
        state = const AuthFormState();
        return true;
      },
      failure: (exception) {
        state = AuthFormState(errorMessage: exception.message);
        return false;
      },
    );
  }
}

@riverpod
class RegisterController extends _$RegisterController {
  @override
  AuthFormState build() => const AuthFormState();

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  Future<RegisterOutcome> submit({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AuthFormState(isLoading: true);
    final result = await ref
        .read(authRepositoryProvider)
        .signUp(
          email: email,
          password: password,
          displayName: fullName,
        );
    return result.when(
      success: (profile) {
        state = const AuthFormState();
        if (profile != null) {
          ref
              .read(authControllerProvider.notifier)
              .setAuthenticatedUser(profile);
          return RegisterOutcome.signedIn;
        }
        return RegisterOutcome.confirmationRequired;
      },
      failure: (exception) {
        state = AuthFormState(errorMessage: exception.message);
        return RegisterOutcome.failed;
      },
    );
  }
}

@riverpod
class ForgotPasswordController extends _$ForgotPasswordController {
  @override
  AuthFormState build() => const AuthFormState();

  void clearFeedback() {
    if (state.errorMessage != null || state.isSubmitted) {
      state = const AuthFormState();
    }
  }

  Future<bool> submit({required String email}) async {
    state = const AuthFormState(isLoading: true);
    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(email: email);
    return result.when(
      success: (_) {
        state = const AuthFormState(isSubmitted: true);
        return true;
      },
      failure: (exception) {
        state = AuthFormState(errorMessage: exception.message);
        return false;
      },
    );
  }
}
