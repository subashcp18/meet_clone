import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/theme/theme_provider.dart';

part 'settings_provider.g.dart';

@immutable
class SettingsState {
  const SettingsState({
    this.defaultMicOn = true,
    this.defaultCameraOn = true,
    this.noiseCancellation = true,
    this.limitDataUsage = false,
  });

  final bool defaultMicOn;
  final bool defaultCameraOn;
  final bool noiseCancellation;
  final bool limitDataUsage;

  SettingsState copyWith({
    bool? defaultMicOn,
    bool? defaultCameraOn,
    bool? noiseCancellation,
    bool? limitDataUsage,
  }) {
    return SettingsState(
      defaultMicOn: defaultMicOn ?? this.defaultMicOn,
      defaultCameraOn: defaultCameraOn ?? this.defaultCameraOn,
      noiseCancellation: noiseCancellation ?? this.noiseCancellation,
      limitDataUsage: limitDataUsage ?? this.limitDataUsage,
    );
  }
}

@Riverpod(keepAlive: true)
class SettingsNotifier extends _$SettingsNotifier {
  static const String _micKey = 'settings_default_mic_on';
  static const String _cameraKey = 'settings_default_camera_on';
  static const String _noiseKey = 'settings_noise_cancellation';
  static const String _dataKey = 'settings_limit_data_usage';

  // region: BUILD
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SettingsState(
      defaultMicOn: prefs.getBool(_micKey) ?? true,
      defaultCameraOn: prefs.getBool(_cameraKey) ?? true,
      noiseCancellation: prefs.getBool(_noiseKey) ?? true,
      limitDataUsage: prefs.getBool(_dataKey) ?? false,
    );
  }
  // endregion

  // region: ACTIONS
  Future<void> setDefaultMicOn(bool value) async {
    state = state.copyWith(defaultMicOn: value);
    await ref.read(sharedPreferencesProvider).setBool(_micKey, value);
  }

  Future<void> setDefaultCameraOn(bool value) async {
    state = state.copyWith(defaultCameraOn: value);
    await ref.read(sharedPreferencesProvider).setBool(_cameraKey, value);
  }

  Future<void> setNoiseCancellation(bool value) async {
    state = state.copyWith(noiseCancellation: value);
    await ref.read(sharedPreferencesProvider).setBool(_noiseKey, value);
  }

  Future<void> setLimitDataUsage(bool value) async {
    state = state.copyWith(limitDataUsage: value);
    await ref.read(sharedPreferencesProvider).setBool(_dataKey, value);
  }
  // endregion
}
