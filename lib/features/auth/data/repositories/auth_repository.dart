import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/base_repository.dart';
import '../../../../core/network/supabase_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../models/profile.dart';

part 'auth_repository.g.dart';

abstract interface class AuthRepository {
  Profile? get currentUser;

  Stream<Profile?> get authStateChanges;

  Future<Result<Profile>> signIn({
    required String email,
    required String password,
  });

  Future<Result<Profile?>> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Result<void>> resetPassword({
    required String email,
  });

  Future<Result<void>> signOut();

  Future<Result<Profile?>> getCurrentUser();
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._prefs) {
    final storedEmail = _prefs.getString(_mockUserEmailKey);
    if (storedEmail != null && storedEmail.isNotEmpty) {
      _current = _buildMockProfile(
        storedEmail,
        displayName: _prefs.getString(_mockUserNameKey),
      );
    }
  }

  static const String _mockUserEmailKey = 'mock_user_email';
  static const String _mockUserNameKey = 'mock_user_name';

  final SharedPreferences _prefs;
  final StreamController<Profile?> _controller =
      StreamController<Profile?>.broadcast();
  final Map<String, ({String password, String displayName})> _accounts = {};
  Profile? _current;

  @override
  Profile? get currentUser => _current;

  @override
  Stream<Profile?> get authStateChanges => _controller.stream;

  @override
  Future<Result<Profile>> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final normalized = email.trim().toLowerCase();
    final registered = _accounts[normalized];
    if (registered != null && registered.password != password) {
      return const Failure(
        UnauthorizedException(message: 'Invalid email or password.'),
      );
    }
    final profile = _buildMockProfile(
      normalized,
      displayName: registered?.displayName,
    );
    await _prefs.setString(_mockUserEmailKey, normalized);
    await _prefs.setString(_mockUserNameKey, profile.displayName);
    _current = profile;
    _controller.add(profile);
    return Success(profile);
  }

  @override
  Future<Result<Profile?>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final normalized = email.trim().toLowerCase();
    if (_accounts.containsKey(normalized)) {
      return const Failure(
        ValidationException(
          message: 'An account with this email already exists.',
        ),
      );
    }
    final trimmedName = displayName.trim();
    _accounts[normalized] = (password: password, displayName: trimmedName);
    final profile = _buildMockProfile(normalized, displayName: trimmedName);
    await _prefs.setString(_mockUserEmailKey, normalized);
    await _prefs.setString(_mockUserNameKey, profile.displayName);
    _current = profile;
    _controller.add(profile);
    return Success(profile);
  }

  @override
  Future<Result<void>> resetPassword({
    required String email,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const Success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await _prefs.remove(_mockUserEmailKey);
    await _prefs.remove(_mockUserNameKey);
    _current = null;
    _controller.add(null);
    return const Success(null);
  }

  @override
  Future<Result<Profile?>> getCurrentUser() async {
    return Success(_current);
  }

  void dispose() {
    _controller.close();
  }

  Profile _buildMockProfile(String email, {String? displayName}) {
    final fallbackName = email.split('@').first;
    final resolvedName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : fallbackName;
    return Profile(
      id: 'u-mock',
      displayName: resolvedName,
      email: email,
    );
  }
}

class SupabaseAuthRepository extends BaseRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Profile? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return _fallbackProfile(user);
  }

  @override
  Stream<Profile?> get authStateChanges {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) {
        return null;
      }
      return _loadProfile(user);
    });
  }

  @override
  Future<Result<Profile>> signIn({
    required String email,
    required String password,
  }) {
    return guard(() async {
      final normalized = email.trim();
      final response = await _client.auth.signInWithPassword(
        email: normalized,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const UnauthorizedException(
          message: 'Invalid email or password.',
        );
      }
      return _loadProfile(user);
    });
  }

  @override
  Future<Result<Profile?>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return guard(() async {
      final normalized = email.trim();
      final trimmedName = displayName.trim();
      final response = await _client.auth.signUp(
        email: normalized,
        password: password,
        data: {
          if (trimmedName.isNotEmpty) 'display_name': trimmedName,
        },
      );
      final user = response.user;
      if (user == null) {
        throw const ServerException(
          message: 'Unable to create your account. Please try again.',
        );
      }
      if (response.session == null) {
        return null;
      }
      return _loadProfile(user, fallbackDisplayName: trimmedName);
    });
  }

  @override
  Future<Result<void>> resetPassword({
    required String email,
  }) {
    return guard(() => _client.auth.resetPasswordForEmail(email.trim()));
  }

  @override
  Future<Result<void>> signOut() {
    return guard(() => _client.auth.signOut());
  }

  @override
  Future<Result<Profile?>> getCurrentUser() {
    return guard(() async {
      final user = _client.auth.currentUser;
      if (user == null) {
        return null;
      }
      return _loadProfile(user);
    });
  }

  Future<Profile> _loadProfile(
    User user, {
    String? fallbackDisplayName,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final row = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (row != null) {
          return Profile.fromJson(row).copyWith(email: user.email);
        }
      } on PostgrestException catch (error) {
        if (kDebugMode) {
          debugPrint(
            'PostgrestException code=${error.code} message=${error.message} '
            'details=${error.details} hint=${error.hint}',
          );
        }
      } catch (_) {}
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    return _fallbackProfile(user, fallbackDisplayName: fallbackDisplayName);
  }

  Profile _fallbackProfile(User user, {String? fallbackDisplayName}) {
    final metadataName = user.userMetadata?['display_name'] as String?;
    final emailPrefix = user.email?.split('@').first;
    final resolvedName = (fallbackDisplayName != null &&
            fallbackDisplayName.isNotEmpty)
        ? fallbackDisplayName
        : (metadataName != null && metadataName.trim().isNotEmpty)
        ? metadataName.trim()
        : (emailPrefix != null && emailPrefix.isNotEmpty)
        ? emailPrefix
        : 'User';
    return Profile(
      id: user.id,
      displayName: resolvedName,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      email: user.email,
    );
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final useMock = ref.watch(useMockApiProvider);
  if (useMock) {
    final repo = MockAuthRepository(ref.watch(sharedPreferencesProvider));
    ref.onDispose(repo.dispose);
    return repo;
  }
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
}
