import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/widgets/draggable_self_view.dart';

part 'in_call_ui_provider.g.dart';

@immutable
class InCallUiState {
  const InCallUiState({
    this.controlsVisible = true,
    this.elapsed = Duration.zero,
    this.isSelfExpanded = false,
  });

  final bool controlsVisible;
  final Duration elapsed;
  final bool isSelfExpanded;

  InCallUiState copyWith({
    bool? controlsVisible,
    Duration? elapsed,
    bool? isSelfExpanded,
  }) {
    return InCallUiState(
      controlsVisible: controlsVisible ?? this.controlsVisible,
      elapsed: elapsed ?? this.elapsed,
      isSelfExpanded: isSelfExpanded ?? this.isSelfExpanded,
    );
  }
}

@riverpod
class InCallUiController extends _$InCallUiController {
  // region: TIMERS & FLAGS
  static const Duration autoHideDelay = Duration(seconds: 4);

  Timer? _autoHideTimer;
  Timer? _elapsedTimer;
  int _keepVisibleDepth = 0;
  bool _isAlone = false;
  // endregion

  // region: BUILD
  @override
  InCallUiState build() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
    });

    ref.onDispose(() {
      _autoHideTimer?.cancel();
      _autoHideTimer = null;
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    });

    _restartAutoHideTimer();
    return const InCallUiState();
  }
  // endregion

  // region: CONTROLS VISIBILITY
  void toggle() {
    if (state.controlsVisible) {
      hide();
    } else {
      show();
    }
  }

  void show() {
    if (!state.controlsVisible) {
      state = state.copyWith(controlsVisible: true);
    }
    _restartAutoHideTimer();
  }

  void hide() {
    if (_isAlone || _keepVisibleDepth > 0) {
      if (!state.controlsVisible) {
        state = state.copyWith(controlsVisible: true);
      }
      return;
    }
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    if (state.controlsVisible) {
      state = state.copyWith(controlsVisible: false);
    }
  }

  void keepVisible(bool value) {
    if (value) {
      _keepVisibleDepth++;
      _autoHideTimer?.cancel();
      _autoHideTimer = null;
      if (!state.controlsVisible) {
        state = state.copyWith(controlsVisible: true);
      }
      return;
    }

    if (_keepVisibleDepth > 0) {
      _keepVisibleDepth--;
    }
    if (_keepVisibleDepth == 0 && state.controlsVisible) {
      _restartAutoHideTimer();
    }
  }

  void setAlone(bool alone) {
    if (_isAlone == alone) {
      return;
    }
    _isAlone = alone;
    if (_isAlone) {
      _autoHideTimer?.cancel();
      _autoHideTimer = null;
      if (!state.controlsVisible) {
        state = state.copyWith(controlsVisible: true);
      }
    } else if (state.controlsVisible && _keepVisibleDepth == 0) {
      _restartAutoHideTimer();
    }
  }

  void recordInteraction() {
    if (state.controlsVisible && !_isAlone && _keepVisibleDepth == 0) {
      _restartAutoHideTimer();
    }
  }

  void toggleSelfExpanded() {
    state = state.copyWith(isSelfExpanded: !state.isSelfExpanded);
    recordInteraction();
  }

  void _restartAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    if (_isAlone || _keepVisibleDepth > 0) {
      return;
    }
    _autoHideTimer = Timer(autoHideDelay, hide);
  }
  // endregion
}

@riverpod
class SelfViewPositionController extends _$SelfViewPositionController {
  @override
  SelfViewCorner build() => SelfViewCorner.bottomRight;

  void setCorner(SelfViewCorner corner) {
    if (state != corner) {
      state = corner;
    }
  }
}
