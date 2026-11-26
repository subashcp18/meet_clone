import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../data/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

@immutable
class AuthState {
  const AuthState._({
    required this.status,
    this.email,
    this.errorMessage,
    this.isBusy = false,
  });

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.authenticated(String email)
    : this._(status: AuthStatus.authenticated, email: email);

  const AuthState.unauthenticated({String? errorMessage})
    : this._(status: AuthStatus.unauthenticated, errorMessage: errorMessage);

  final AuthStatus status;
  final String? email;
  final String? errorMessage;
  final bool isBusy;

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? errorMessage,
    bool? isBusy,
  }) {
    return AuthState._(
      status: status ?? this.status,
      email: email ?? this.email,
      errorMessage: errorMessage,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  // region: BUILD
  @override
  AuthState build() {
    ref.listen<bool>(sessionExpiredProvider, (_, expired) {
      if (expired) {
        state = const AuthState.unauthenticated();
        ref.read(sessionExpiredProvider.notifier).reset();
      }
    });
    return const AuthState.unknown();
  }
  // endregion

  // region: ACTIONS
  Future<void> checkSession() async {
    final result = await ref.read(authRepositoryProvider).getCurrentUserEmail();
    result.when(
      success: (email) {
        if (email != null && email.isNotEmpty) {
          state = AuthState.authenticated(email);
        } else {
          state = const AuthState.unauthenticated();
        }
      },
      failure: (_) {
        state = const AuthState.unauthenticated();
      },
    );
  }

  Future<bool> signIn(String email) async {
    state = state.copyWith(isBusy: true, errorMessage: null);
    final result = await ref.read(authRepositoryProvider).signInWithEmail(email);
    return result.when(
      success: (signedInEmail) {
        state = AuthState.authenticated(signedInEmail);
        return true;
      },
      failure: (exception) {
        state = AuthState.unauthenticated(errorMessage: exception.message);
        return false;
      },
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(isBusy: true, errorMessage: null);
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState.unauthenticated();
  }
  // endregion
}
