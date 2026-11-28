import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_user_avatar.dart';
import '../../../../core/widgets/media_toggle_button.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/models/meeting.dart';
import '../../data/models/meeting_participant.dart';
import '../../data/models/meeting_preview.dart';
import '../../providers/meeting_session_provider.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({
    super.key,
    required this.code,
  });

  final String code;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  // region: STATE & LIFECYCLE
  bool _isWaitingInLobby = false;
  bool _isJoiningAsHost = false;
  bool _hostCancelled = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(meetingSessionProvider.notifier).clearJoinError();
      ref.invalidate(meetingPreviewProvider(widget.code));
    });
  }
  // endregion

  // region: ACTIONS
  Future<void> _requestOrJoin(String title, {required bool isHost}) async {
    setState(() {
      _inlineError = null;
      _hostCancelled = false;
      _isJoiningAsHost = isHost;
      _isWaitingInLobby = !isHost;
    });

    final status = await ref
        .read(meetingSessionProvider.notifier)
        .requestJoin(code: widget.code, title: title);

    if (!mounted) {
      return;
    }

    if (isHost && _hostCancelled) {
      await ref.read(meetingSessionProvider.notifier).leaveCall();
      return;
    }

    if (status == null) {
      final error = ref.read(meetingSessionProvider).errorMessage;
      setState(() {
        _isJoiningAsHost = false;
        _isWaitingInLobby = false;
        _inlineError = error ?? UnknownException.defaultMessage;
      });
      return;
    }

    if (status == 'admitted') {
      setState(() {
        _isJoiningAsHost = false;
        _isWaitingInLobby = false;
      });
      context.pushReplacement(RouteNames.meetingLocation(widget.code));
      return;
    }

    setState(() {
      _isJoiningAsHost = false;
      _isWaitingInLobby = true;
    });
  }

  Future<void> _cancelJoin() async {
    if (_isJoiningAsHost) {
      setState(() {
        _hostCancelled = true;
        _isJoiningAsHost = false;
      });
      return;
    }
    if (_isWaitingInLobby) {
      setState(() {
        _isWaitingInLobby = false;
      });
      await ref.read(meetingSessionProvider.notifier).cancelJoinRequest();
    }
  }

  Future<void> _enterAdmittedCall(String meetingId) async {
    await ref
        .read(meetingSessionProvider.notifier)
        .activateAdmittedCall(meetingId);
    if (!mounted) {
      return;
    }
    context.pushReplacement(RouteNames.meetingLocation(widget.code));
  }

  Future<void> _showDeviceSettingsSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => _DeviceSettingsSheet(
        onSelectAudio: (device) {
          ref.read(meetingSessionProvider.notifier).setAudioOutput(device);
        },
        onToggleCameraFacing: () {
          ref.read(meetingSessionProvider.notifier).toggleCameraFacing();
        },
      ),
    );
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(meetingSessionProvider);
    final previewAsync = ref.watch(meetingPreviewProvider(widget.code));
    final authUser = ref.watch(authControllerProvider).asData?.value;
    final authEmail = authUser?.email ?? authUser?.displayName ?? 'You';
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    if (_isWaitingInLobby && session.meetingId.isNotEmpty) {
      ref.listen<AsyncValue<MeetingParticipant?>>(
        myParticipantRowProvider(session.meetingId),
        (_, next) {
          final row = next.asData?.value;
          if (!_isWaitingInLobby || row == null) {
            return;
          }
          if (row.isAdmitted) {
            setState(() => _isWaitingInLobby = false);
            _enterAdmittedCall(session.meetingId);
          } else if (row.isDenied) {
            setState(() {
              _isWaitingInLobby = false;
              _inlineError = 'The host denied your request';
            });
          }
        },
      );

      ref.listen<AsyncValue<Meeting?>>(
        meetingStatusProvider(session.meetingId),
        (_, next) {
          final liveMeeting = next.asData?.value;
          if (_isWaitingInLobby && liveMeeting != null && liveMeeting.isEnded) {
            setState(() {
              _isWaitingInLobby = false;
            });
            ref.invalidate(meetingPreviewProvider(widget.code));
          }
        },
      );
    }

    final preview = previewAsync.asData?.value;
    final meetingTitle = preview?.title ?? 'Meeting';
    final isHost =
        preview != null && authUser != null && preview.hostId == authUser.id;
    final isBusyJoining = _isJoiningAsHost || _isWaitingInLobby;
    final previewError = previewAsync.hasError
        ? ApiException.friendlyMessage(previewAsync.error!)
        : null;
    final isEndedError = previewError == 'This meeting has ended.';

    return PopScope(
      canPop: !isBusyJoining,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isBusyJoining) {
          _cancelJoin();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meetingTitle,
                style: textStyles.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.code,
                style: textStyles.caption,
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () =>
                  ref.read(meetingSessionProvider.notifier).toggleCameraFacing(),
              tooltip: session.isFrontCamera
                  ? 'Switch to rear camera'
                  : 'Switch to front camera',
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
            IconButton(
              onPressed: _showDeviceSettingsSheet,
              tooltip: 'Device settings',
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: isEndedError
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 36),
                          Icon(
                            Icons.event_busy_rounded,
                            size: 56,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'This meeting has ended',
                            style: textStyles.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.code,
                            style: textStyles.caption,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => context.goNamed(RouteNames.home),
                            child: const Text('Back to Home'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (preview != null &&
                              !preview.hostInCall &&
                              !isHost) ...[
                            Text(
                              "The host hasn't joined yet",
                              style: textStyles.bodyMedium.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _CameraPreviewPlaceholder(
                            userEmail: authEmail,
                            isMicOn: session.isMicOn,
                            isCameraOn: session.isCameraOn,
                            isFrontCamera: session.isFrontCamera,
                            overlayText: _isJoiningAsHost
                                ? 'Joining the meeting...'
                                : _isWaitingInLobby
                                ? 'Asking to join. Waiting for the host to let you in...'
                                : null,
                            onToggleMic: () => ref
                                .read(meetingSessionProvider.notifier)
                                .toggleMic(),
                            onToggleCamera: () => ref
                                .read(meetingSessionProvider.notifier)
                                .toggleCamera(),
                          ),
                          const SizedBox(height: 16),
                          _DeviceSettingsStrip(
                            audioOutput: session.audioOutput,
                            isFrontCamera: session.isFrontCamera,
                            onTapAudio: _showDeviceSettingsSheet,
                            onTapCameraSwitch: () => ref
                                .read(meetingSessionProvider.notifier)
                                .toggleCameraFacing(),
                          ),
                          const SizedBox(height: 20),
                          _LobbyParticipantsSection(
                            previewAsync: previewAsync,
                            onRetry: () => ref.invalidate(
                              meetingPreviewProvider(widget.code),
                            ),
                          ),
                          if (_inlineError != null) ...[
                            const SizedBox(height: 16),
                            AppErrorBanner(message: _inlineError!),
                          ],
                          const SizedBox(height: 24),
                          if (isBusyJoining)
                            SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _cancelJoin,
                                child: const Text('Cancel'),
                              ),
                            )
                          else
                            SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.joinGreen,
                                  foregroundColor: colorScheme.onSecondary,
                                ),
                                onPressed: previewAsync.hasError ||
                                        previewAsync.isLoading
                                    ? null
                                    : () => _requestOrJoin(
                                          meetingTitle,
                                          isHost: isHost,
                                        ),
                                icon: const Icon(
                                  Icons.videocam_rounded,
                                  size: 20,
                                ),
                                label: Text(
                                  isHost ? 'Join now' : 'Ask to join',
                                ),
                              ),
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
  // endregion
}

class _CameraPreviewPlaceholder extends StatelessWidget {
  const _CameraPreviewPlaceholder({
    required this.userEmail,
    required this.isMicOn,
    required this.isCameraOn,
    required this.isFrontCamera,
    required this.onToggleMic,
    required this.onToggleCamera,
    this.overlayText,
  });

  final String userEmail;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isFrontCamera;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final String? overlayText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isCameraOn
              ? colors.tileSurface
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppUserAvatar(
                    nameOrEmail: userEmail,
                    radius: 44,
                    backgroundColor: isCameraOn
                        ? colors.primary
                        : colorScheme.surfaceContainer,
                    foregroundColor: isCameraOn
                        ? colorScheme.onPrimary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isCameraOn
                        ? 'Camera preview (${isFrontCamera ? 'Front' : 'Rear'})'
                        : 'Camera is off',
                    style: textStyles.bodyMedium.copyWith(
                      color: isCameraOn
                          ? colorScheme.onPrimary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (overlayText != null)
              Positioned.fill(
                child: Container(
                  color: colors.callBackground.withValues(alpha: 0.62),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: colorScheme.onPrimary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        overlayText!,
                        style: textStyles.bodyMedium.copyWith(
                          color: colorScheme.onPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MediaToggleButton(
                    isActive: isMicOn,
                    activeIcon: Icons.mic_rounded,
                    inactiveIcon: Icons.mic_off_rounded,
                    tooltip: isMicOn
                        ? 'Turn off microphone'
                        : 'Turn on microphone',
                    onPressed: onToggleMic,
                  ),
                  const SizedBox(width: 20),
                  MediaToggleButton(
                    isActive: isCameraOn,
                    activeIcon: Icons.videocam_rounded,
                    inactiveIcon: Icons.videocam_off_rounded,
                    tooltip: isCameraOn ? 'Turn off camera' : 'Turn on camera',
                    onPressed: onToggleCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceSettingsStrip extends StatelessWidget {
  const _DeviceSettingsStrip({
    required this.audioOutput,
    required this.isFrontCamera,
    required this.onTapAudio,
    required this.onTapCameraSwitch,
  });

  final AudioOutputDevice audioOutput;
  final bool isFrontCamera;
  final VoidCallback onTapAudio;
  final VoidCallback onTapCameraSwitch;

  @override
  Widget build(BuildContext context) {
    final audioIcon = switch (audioOutput) {
      AudioOutputDevice.speaker => Icons.volume_up_rounded,
      AudioOutputDevice.earpiece => Icons.phone_in_talk_rounded,
      AudioOutputDevice.bluetooth => Icons.bluetooth_audio_rounded,
    };

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: Icon(audioIcon, size: 18),
          label: Text(audioOutput.label),
          onPressed: onTapAudio,
        ),
        ActionChip(
          avatar: const Icon(Icons.cameraswitch_outlined, size: 18),
          label: Text(isFrontCamera ? 'Front camera' : 'Rear camera'),
          onPressed: onTapCameraSwitch,
        ),
      ],
    );
  }
}

class _LobbyParticipantsSection extends StatelessWidget {
  const _LobbyParticipantsSection({
    required this.previewAsync,
    required this.onRetry,
  });

  final AsyncValue<MeetingPreview> previewAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return previewAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: AppLoadingIndicator(size: 20),
      ),
      error: (error, _) {
        return Column(
          children: [
            AppErrorBanner(message: ApiException.friendlyMessage(error)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        );
      },
      data: (preview) {
        final participants = preview.previewParticipants;
        if (participants.isEmpty) {
          return Text(
            'No one else is here yet',
            style: textStyles.bodyMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          );
        }
        return Column(
          children: [
            _AvatarStack(participants: participants),
            const SizedBox(height: 8),
            Text(
              _summaryText(participants),
              style: textStyles.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  String _summaryText(List<MeetingPreviewParticipant> participants) {
    if (participants.length == 1) {
      return '${participants.first.displayName} is in this call';
    }
    if (participants.length == 2) {
      return '${participants[0].displayName} and ${participants[1].displayName} are in this call';
    }
    final remaining = participants.length - 2;
    final suffix = remaining == 1 ? 'other' : 'others';
    return '${participants[0].displayName}, ${participants[1].displayName}, and $remaining $suffix are in this call';
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.participants});

  final List<MeetingPreviewParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final visible = participants.take(4).toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < visible.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: AppUserAvatar(
              nameOrEmail: visible[i].displayName,
              radius: 18,
            ),
          ),
      ],
    );
  }
}

class _DeviceSettingsSheet extends ConsumerWidget {
  const _DeviceSettingsSheet({
    required this.onSelectAudio,
    required this.onToggleCameraFacing,
  });

  final ValueChanged<AudioOutputDevice> onSelectAudio;
  final VoidCallback onToggleCameraFacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(meetingSessionProvider);
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Device settings',
                style: textStyles.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            for (final device in AudioOutputDevice.values)
              ListTile(
                onTap: () {
                  onSelectAudio(device);
                  Navigator.of(context).pop();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: Icon(
                  switch (device) {
                    AudioOutputDevice.speaker => Icons.volume_up_rounded,
                    AudioOutputDevice.earpiece => Icons.phone_in_talk_rounded,
                    AudioOutputDevice.bluetooth => Icons.bluetooth_audio_rounded,
                  },
                  color: session.audioOutput == device
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                title: Text(device.label, style: textStyles.bodyLarge),
                trailing: session.audioOutput == device
                    ? Icon(Icons.check_rounded, color: colors.primary)
                    : null,
              ),
            const Divider(),
            ListTile(
              onTap: () {
                onToggleCameraFacing();
                Navigator.of(context).pop();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.cameraswitch_outlined),
              title: const Text('Camera facing'),
              trailing: Text(
                session.isFrontCamera ? 'Front' : 'Rear',
                style: textStyles.labelMedium.copyWith(color: colors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
