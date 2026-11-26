import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_sheet_action_tile.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/draggable_self_view.dart';
import '../../../../core/widgets/media_toggle_button.dart';
import '../../data/models/participant_model.dart';
import '../../providers/in_call_ui_provider.dart';
import '../../providers/meeting_session_provider.dart';
import '../chat/in_call_chat_sheet.dart';
import '../participants/participants_sheet.dart';
import 'widgets/participant_video_tile.dart';

class InCallScreen extends ConsumerStatefulWidget {
  const InCallScreen({
    super.key,
    required this.code,
  });

  final String code;

  @override
  ConsumerState<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends ConsumerState<InCallScreen> {
  // region: CONSTANTS & LIFECYCLE
  static const Duration _animDuration = Duration(milliseconds: 250);
  static const Curve _animCurve = Curves.easeInOut;
  static const double _portraitTopBarHeight = 64;
  static const double _portraitBottomBarHeight = 76;
  static const double _landscapeRightRailWidth = 70;
  static const double _landscapeTopOverlayHeight = 52;
  static const double _snapMargin = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(meetingSessionProvider.notifier).ensureJoined(widget.code);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  // endregion

  // region: ACTIONS
  Future<void> _endCall() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await ref.read(meetingSessionProvider.notifier).leaveCall();
    if (!mounted) {
      return;
    }
    context.goNamed(RouteNames.home);
  }

  Future<void> _openModalKeepControls(Future<void> Function() openSheet) async {
    final uiController = ref.read(inCallUiControllerProvider.notifier);
    uiController.keepVisible(true);
    try {
      await openSheet();
    } finally {
      if (mounted) {
        ref.read(inCallUiControllerProvider.notifier).keepVisible(false);
      }
    }
  }

  Future<void> _showAudioOutputSheet() {
    return _openModalKeepControls(() {
      return showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => Theme(
          data: AppTheme.callTheme,
          child: Consumer(
            builder: (context, sheetRef, _) {
              final current = sheetRef.watch(meetingSessionProvider).audioOutput;
              final colors = context.colors;
              final textStyles = context.textStyles;

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          'Audio output',
                          style: textStyles.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final device in AudioOutputDevice.values)
                        ListTile(
                          onTap: () {
                            sheetRef
                                .read(meetingSessionProvider.notifier)
                                .setAudioOutput(device);
                            Navigator.of(sheetContext).pop();
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Icon(
                            _audioIcon(device),
                            color: current == device
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          title: Text(device.label),
                          trailing: current == device
                              ? Icon(Icons.check_rounded, color: colors.primary)
                              : null,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Future<void> _showMoreOptionsSheet(MeetingSessionState session) {
    return _openModalKeepControls(() {
      return showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => Theme(
          data: AppTheme.callTheme,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSheetActionTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'In-call messages',
                      subtitle: 'Chat with everyone in the meeting',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _openModalKeepControls(
                          () => InCallChatSheet.show(context, code: widget.code),
                        );
                      },
                    ),
                    AppSheetActionTile(
                      icon: Icons.people_outline_rounded,
                      title: 'Participants (${session.participants.length})',
                      subtitle: 'View and manage attendees',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _openModalKeepControls(
                          () => ParticipantsSheet.show(context),
                        );
                      },
                    ),
                    AppSheetActionTile(
                      icon: Icons.cameraswitch_outlined,
                      title: 'Switch camera',
                      subtitle: session.isFrontCamera
                          ? 'Currently using front camera'
                          : 'Currently using rear camera',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        ref
                            .read(meetingSessionProvider.notifier)
                            .toggleCameraFacing();
                      },
                    ),
                    AppSheetActionTile(
                      icon: _audioIcon(session.audioOutput),
                      title: 'Audio output',
                      subtitle: session.audioOutput.label,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showAudioOutputSheet();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  IconData _audioIcon(AudioOutputDevice device) {
    return switch (device) {
      AudioOutputDevice.speaker => Icons.volume_up_rounded,
      AudioOutputDevice.earpiece => Icons.phone_in_talk_rounded,
      AudioOutputDevice.bluetooth => Icons.bluetooth_audio_rounded,
    };
  }
  // endregion

  // region: BOUNDS & LAYOUT HELPERS
  Rect _computeSelfViewBounds({
    required BoxConstraints constraints,
    required EdgeInsets safePadding,
    required bool isLandscape,
    required bool controlsVisible,
  }) {
    final left = safePadding.left + _snapMargin;
    if (isLandscape) {
      final top =
          safePadding.top +
          (controlsVisible ? _landscapeTopOverlayHeight : 0) +
          _snapMargin;
      final right =
          constraints.maxWidth -
          safePadding.right -
          (controlsVisible ? _landscapeRightRailWidth : 0) -
          _snapMargin;
      final bottom = constraints.maxHeight - safePadding.bottom - _snapMargin;
      return Rect.fromLTRB(
        left,
        top,
        right < left ? left : right,
        bottom < top ? top : bottom,
      );
    }

    final top =
        safePadding.top +
        (controlsVisible ? _portraitTopBarHeight : 0) +
        _snapMargin;
    final right = constraints.maxWidth - safePadding.right - _snapMargin;
    final bottom =
        constraints.maxHeight -
        safePadding.bottom -
        (controlsVisible ? _portraitBottomBarHeight : 0) -
        _snapMargin;
    return Rect.fromLTRB(
      left,
      top,
      right < left ? left : right,
      bottom < top ? top : bottom,
    );
  }

  Size _selfViewSize({
    required bool isLandscape,
    required bool isExpanded,
  }) {
    if (isLandscape) {
      return isExpanded ? const Size(200, 112) : const Size(160, 90);
    }
    return isExpanded ? const Size(144, 196) : const Size(110, 150);
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(meetingSessionProvider);
    final uiState = ref.watch(inCallUiControllerProvider);
    final selfCorner = ref.watch(selfViewPositionControllerProvider);
    final uiNotifier = ref.read(inCallUiControllerProvider.notifier);

    ref.listen<bool>(
      inCallUiControllerProvider.select((s) => s.controlsVisible),
      (_, visible) {
        SystemChrome.setEnabledSystemUIMode(
          visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
        );
      },
    );

    final isAlone = session.participants.length <= 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        uiNotifier.setAlone(isAlone);
      }
    });

    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final safePadding = MediaQuery.paddingOf(context);
    final controlsVisible = uiState.controlsVisible || isAlone;

    final selfParticipant = session.participants
        .where((p) => p.isSelf)
        .firstOrNull;
    final remoteParticipants = session.participants
        .where((p) => !p.isSelf)
        .toList();
    final showFloatingSelf =
        selfParticipant != null && remoteParticipants.isNotEmpty;

    final meetingTitle = session.title.isNotEmpty
        ? session.title
        : widget.code;

    return Theme(
      data: AppTheme.callTheme,
      child: Scaffold(
        backgroundColor: colors.callBackground,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => uiNotifier.recordInteraction(),
          onPointerMove: (_) => uiNotifier.recordInteraction(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final selfBounds = _computeSelfViewBounds(
                constraints: constraints,
                safePadding: safePadding,
                isLandscape: isLandscape,
                controlsVisible: controlsVisible,
              );
              final selfSize = _selfViewSize(
                isLandscape: isLandscape,
                isExpanded: uiState.isSelfExpanded,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: uiNotifier.toggle,
                      child: SafeArea(
                        top: controlsVisible || isLandscape,
                        bottom: controlsVisible || isLandscape,
                        child: AnimatedPadding(
                          duration: _animDuration,
                          curve: _animCurve,
                          padding: isLandscape
                              ? EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  controlsVisible
                                      ? _landscapeRightRailWidth + 8
                                      : 12,
                                  12,
                                )
                              : EdgeInsets.fromLTRB(
                                  12,
                                  controlsVisible
                                      ? _portraitTopBarHeight + 4
                                      : 12,
                                  12,
                                  controlsVisible
                                      ? _portraitBottomBarHeight + 8
                                      : 12,
                                ),
                          child: _CallStage(
                            session: session,
                            remoteParticipants: remoteParticipants,
                            isLandscape: isLandscape,
                            onRetryJoin: () => ref
                                .read(meetingSessionProvider.notifier)
                                .ensureJoined(widget.code),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (session.isPresenting)
                    Positioned(
                      top: safePadding.top +
                          (controlsVisible && !isLandscape
                              ? _portraitTopBarHeight + 4
                              : 12),
                      left: safePadding.left + 16,
                      right: safePadding.right +
                          (controlsVisible && isLandscape
                              ? _landscapeRightRailWidth + 12
                              : 16),
                      child: Center(
                        child: AppStatusPill(
                          icon: Icons.present_to_all_rounded,
                          label: 'You are presenting to everyone',
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          actionLabel: 'Stop',
                          onAction: () => ref
                              .read(meetingSessionProvider.notifier)
                              .togglePresenting(),
                        ),
                      ),
                    ),
                  if (showFloatingSelf)
                    DraggableSelfView(
                      corner: selfCorner,
                      bounds: selfBounds,
                      tileSize: selfSize,
                      onCornerChanged: (corner) {
                        ref
                            .read(selfViewPositionControllerProvider.notifier)
                            .setCorner(corner);
                      },
                      onTap: uiNotifier.toggleSelfExpanded,
                      child: ParticipantVideoTile(
                        participant: selfParticipant,
                        isCompact: true,
                      ),
                    ),
                  if (isLandscape) ...[
                    _LandscapeTopOverlay(
                      title: meetingTitle,
                      elapsed: uiState.elapsed,
                      visible: controlsVisible,
                      duration: _animDuration,
                      curve: _animCurve,
                    ),
                    _LandscapeRightControlRail(
                      visible: controlsVisible,
                      duration: _animDuration,
                      curve: _animCurve,
                      isMicOn: session.isMicOn,
                      isCameraOn: session.isCameraOn,
                      isPresenting: session.isPresenting,
                      isHandRaised: session.isHandRaised,
                      onToggleMic: () => ref
                          .read(meetingSessionProvider.notifier)
                          .toggleMic(),
                      onToggleCamera: () => ref
                          .read(meetingSessionProvider.notifier)
                          .toggleCamera(),
                      onTogglePresenting: () => ref
                          .read(meetingSessionProvider.notifier)
                          .togglePresenting(),
                      onToggleHandRaised: () => ref
                          .read(meetingSessionProvider.notifier)
                          .toggleHandRaised(),
                      onMore: () => _showMoreOptionsSheet(session),
                      onEndCall: _endCall,
                    ),
                  ] else ...[
                    _PortraitTopBarOverlay(
                      title: meetingTitle,
                      elapsed: uiState.elapsed,
                      participantCount: session.participants.length,
                      isFrontCamera: session.isFrontCamera,
                      audioIcon: _audioIcon(session.audioOutput),
                      audioTooltip: session.audioOutput.label,
                      visible: controlsVisible,
                      duration: _animDuration,
                      curve: _animCurve,
                      onSwitchCamera: () => ref
                          .read(meetingSessionProvider.notifier)
                          .toggleCameraFacing(),
                      onAudioOutput: _showAudioOutputSheet,
                      onOpenParticipants: () => _openModalKeepControls(
                        () => ParticipantsSheet.show(context),
                      ),
                    ),
                    _PortraitBottomBarOverlay(
                      visible: controlsVisible,
                      duration: _animDuration,
                      curve: _animCurve,
                      isMicOn: session.isMicOn,
                      isCameraOn: session.isCameraOn,
                      isPresenting: session.isPresenting,
                      isHandRaised: session.isHandRaised,
                      onToggleMic: () => ref
                          .read(meetingSessionProvider.notifier)
                          .toggleMic(),
                      onToggleCamera: () => ref
                          .read(meetingSessionProvider.notifier)
                          .toggleCamera(),
                      onTogglePresenting: () => ref
                          .read(meetingSessionProvider.notifier)
                          .togglePresenting(),
                      onToggleHandRaised: () => ref
                          .read(meetingSessionProvider.notifier)
                          .toggleHandRaised(),
                      onMore: () => _showMoreOptionsSheet(session),
                      onEndCall: _endCall,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  // endregion
}

class _PortraitTopBarOverlay extends StatelessWidget {
  const _PortraitTopBarOverlay({
    required this.title,
    required this.elapsed,
    required this.participantCount,
    required this.isFrontCamera,
    required this.audioIcon,
    required this.audioTooltip,
    required this.visible,
    required this.duration,
    required this.curve,
    required this.onSwitchCamera,
    required this.onAudioOutput,
    required this.onOpenParticipants,
  });

  final String title;
  final Duration elapsed;
  final int participantCount;
  final bool isFrontCamera;
  final IconData audioIcon;
  final String audioTooltip;
  final bool visible;
  final Duration duration;
  final Curve curve;
  final VoidCallback onSwitchCamera;
  final VoidCallback onAudioOutput;
  final VoidCallback onOpenParticipants;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1),
          duration: duration,
          curve: curve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            curve: curve,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.scrim.withValues(alpha: 0.55),
                    colorScheme.scrim.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: textStyles.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.formatDuration(elapsed),
                              style: textStyles.callTimer,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onSwitchCamera,
                        tooltip: isFrontCamera
                            ? 'Switch to rear camera'
                            : 'Switch to front camera',
                        icon: const Icon(Icons.cameraswitch_outlined),
                      ),
                      IconButton(
                        onPressed: onAudioOutput,
                        tooltip: audioTooltip,
                        icon: Icon(audioIcon),
                      ),
                      const SizedBox(width: 4),
                      ActionChip(
                        backgroundColor: colors.callControlSurface,
                        side: BorderSide.none,
                        avatar: Icon(
                          Icons.people_outline_rounded,
                          size: 16,
                          color: colors.onSurface,
                        ),
                        label: Text('$participantCount'),
                        onPressed: onOpenParticipants,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitBottomBarOverlay extends StatelessWidget {
  const _PortraitBottomBarOverlay({
    required this.visible,
    required this.duration,
    required this.curve,
    required this.isMicOn,
    required this.isCameraOn,
    required this.isPresenting,
    required this.isHandRaised,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onTogglePresenting,
    required this.onToggleHandRaised,
    required this.onMore,
    required this.onEndCall,
  });

  final bool visible;
  final Duration duration;
  final Curve curve;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isPresenting;
  final bool isHandRaised;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onTogglePresenting;
  final VoidCallback onToggleHandRaised;
  final VoidCallback onMore;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1),
          duration: duration,
          curve: curve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            curve: curve,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    colorScheme.scrim.withValues(alpha: 0.55),
                    colorScheme.scrim.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.callControlSurface,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ..._buildControlButtons(
                          context: context,
                          isMicOn: isMicOn,
                          isCameraOn: isCameraOn,
                          isPresenting: isPresenting,
                          isHandRaised: isHandRaised,
                          onToggleMic: onToggleMic,
                          onToggleCamera: onToggleCamera,
                          onTogglePresenting: onTogglePresenting,
                          onToggleHandRaised: onToggleHandRaised,
                          onMore: onMore,
                          buttonSize: 44,
                        ),
                        _EndCallButton(
                          width: 54,
                          height: 44,
                          onPressed: onEndCall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandscapeTopOverlay extends StatelessWidget {
  const _LandscapeTopOverlay({
    required this.title,
    required this.elapsed,
    required this.visible,
    required this.duration,
    required this.curve,
  });

  final String title;
  final Duration elapsed;
  final bool visible;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    return Positioned(
      top: 0,
      left: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1),
          duration: duration,
          curve: curve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            curve: curve,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 28, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.scrim.withValues(alpha: 0.52),
                    colorScheme.scrim.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SafeArea(
                right: false,
                bottom: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        title,
                        style: textStyles.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      Formatters.formatDuration(elapsed),
                      style: textStyles.callTimer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandscapeRightControlRail extends StatelessWidget {
  const _LandscapeRightControlRail({
    required this.visible,
    required this.duration,
    required this.curve,
    required this.isMicOn,
    required this.isCameraOn,
    required this.isPresenting,
    required this.isHandRaised,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onTogglePresenting,
    required this.onToggleHandRaised,
    required this.onMore,
    required this.onEndCall,
  });

  final bool visible;
  final Duration duration;
  final Curve curve;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isPresenting;
  final bool isHandRaised;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onTogglePresenting;
  final VoidCallback onToggleHandRaised;
  final VoidCallback onMore;
  final VoidCallback onEndCall;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;

    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(1, 0),
          duration: duration,
          curve: curve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            curve: curve,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    colorScheme.scrim.withValues(alpha: 0.55),
                    colorScheme.scrim.withValues(alpha: 0),
                  ],
                ),
              ),
              child: SafeArea(
                left: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.callControlSurface,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final button in _buildControlButtons(
                              context: context,
                              isMicOn: isMicOn,
                              isCameraOn: isCameraOn,
                              isPresenting: isPresenting,
                              isHandRaised: isHandRaised,
                              onToggleMic: onToggleMic,
                              onToggleCamera: onToggleCamera,
                              onTogglePresenting: onTogglePresenting,
                              onToggleHandRaised: onToggleHandRaised,
                              onMore: onMore,
                              buttonSize: 38,
                            )) ...[
                              button,
                              const SizedBox(height: 6),
                            ],
                            _EndCallButton(
                              width: 42,
                              height: 38,
                              onPressed: onEndCall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _buildControlButtons({
  required BuildContext context,
  required bool isMicOn,
  required bool isCameraOn,
  required bool isPresenting,
  required bool isHandRaised,
  required VoidCallback onToggleMic,
  required VoidCallback onToggleCamera,
  required VoidCallback onTogglePresenting,
  required VoidCallback onToggleHandRaised,
  required VoidCallback onMore,
  required double buttonSize,
}) {
  final colors = context.colors;
  final colorScheme = context.colorScheme;

  return [
    MediaToggleButton(
      isActive: isMicOn,
      activeIcon: Icons.mic_rounded,
      inactiveIcon: Icons.mic_off_rounded,
      tooltip: isMicOn ? 'Mute' : 'Unmute',
      activeBackgroundColor: colors.tileSurface,
      onPressed: onToggleMic,
      size: buttonSize,
    ),
    MediaToggleButton(
      isActive: isCameraOn,
      activeIcon: Icons.videocam_rounded,
      inactiveIcon: Icons.videocam_off_rounded,
      tooltip: isCameraOn ? 'Turn off camera' : 'Turn on camera',
      activeBackgroundColor: colors.tileSurface,
      onPressed: onToggleCamera,
      size: buttonSize,
    ),
    MediaToggleButton(
      isActive: !isPresenting,
      activeIcon: Icons.present_to_all_rounded,
      inactiveIcon: Icons.stop_screen_share_rounded,
      tooltip: isPresenting ? 'Stop presenting' : 'Present screen',
      activeBackgroundColor: colors.tileSurface,
      inactiveBackgroundColor: colors.primary,
      inactiveForegroundColor: colorScheme.onPrimary,
      onPressed: onTogglePresenting,
      size: buttonSize,
    ),
    MediaToggleButton(
      isActive: !isHandRaised,
      activeIcon: Icons.back_hand_outlined,
      inactiveIcon: Icons.back_hand_rounded,
      tooltip: isHandRaised ? 'Lower hand' : 'Raise hand',
      activeBackgroundColor: colors.tileSurface,
      inactiveBackgroundColor: colors.warningAmber,
      inactiveForegroundColor: colorScheme.onSecondary,
      onPressed: onToggleHandRaised,
      size: buttonSize,
    ),
    MediaToggleButton(
      isActive: true,
      activeIcon: Icons.more_vert_rounded,
      inactiveIcon: Icons.more_vert_rounded,
      tooltip: 'More options',
      activeBackgroundColor: colors.tileSurface,
      onPressed: onMore,
      size: buttonSize,
    ),
  ];
}

class _EndCallButton extends StatelessWidget {
  const _EndCallButton({
    required this.width,
    required this.height,
    required this.onPressed,
  });

  final double width;
  final double height;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;

    return Tooltip(
      message: 'Leave call',
      child: Material(
        color: colors.endCallRed,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: width,
            height: height,
            child: Icon(
              Icons.call_end_rounded,
              color: colorScheme.onError,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _CallStage extends StatelessWidget {
  const _CallStage({
    required this.session,
    required this.remoteParticipants,
    required this.isLandscape,
    required this.onRetryJoin,
  });

  final MeetingSessionState session;
  final List<ParticipantModel> remoteParticipants;
  final bool isLandscape;
  final VoidCallback onRetryJoin;

  @override
  Widget build(BuildContext context) {
    if (session.participants.isEmpty) {
      if (session.isJoining) {
        return const AppLoadingIndicator(message: 'Joining meeting...');
      }
      if (session.errorMessage != null) {
        return AppErrorState(
          message: session.errorMessage!,
          onRetry: onRetryJoin,
        );
      }
      return const AppEmptyState(
        icon: Icons.groups_outlined,
        title: 'Waiting for participants',
        subtitle: 'Others who join this meeting will appear here.',
      );
    }

    final gridParticipants = remoteParticipants.isNotEmpty
        ? remoteParticipants
        : session.participants;

    return _ParticipantGrid(
      participants: gridParticipants,
      isLandscape: isLandscape,
    );
  }
}

class _ParticipantGrid extends StatelessWidget {
  const _ParticipantGrid({
    required this.participants,
    required this.isLandscape,
  });

  final List<ParticipantModel> participants;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    final count = participants.length;
    if (count == 1) {
      return ParticipantVideoTile(participant: participants.first);
    }

    if (count == 2) {
      if (isLandscape) {
        return Row(
          children: [
            Expanded(child: ParticipantVideoTile(participant: participants[0])),
            const SizedBox(width: 8),
            Expanded(child: ParticipantVideoTile(participant: participants[1])),
          ],
        );
      }
      return Column(
        children: [
          Expanded(child: ParticipantVideoTile(participant: participants[0])),
          const SizedBox(height: 8),
          Expanded(child: ParticipantVideoTile(participant: participants[1])),
        ],
      );
    }

    if (count <= 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ParticipantVideoTile(
                    participant: participants[0],
                    isCompact: isLandscape,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ParticipantVideoTile(
                    participant: participants[1],
                    isCompact: isLandscape,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ParticipantVideoTile(
                    participant: participants[2],
                    isCompact: isLandscape,
                  ),
                ),
                if (count == 4) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ParticipantVideoTile(
                      participant: participants[3],
                      isCompact: isLandscape,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      itemCount: participants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLandscape ? 3 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: isLandscape ? 16 / 9 : 0.78,
      ),
      itemBuilder: (context, index) {
        return ParticipantVideoTile(
          participant: participants[index],
          isCompact: isLandscape,
        );
      },
    );
  }
}
