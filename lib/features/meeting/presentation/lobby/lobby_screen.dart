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
import '../../data/models/meeting_lobby_info.dart';
import '../../data/models/participant_model.dart';
import '../../providers/meeting_session_provider.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({
    super.key,
    required this.code,
  });

  final String code;

  // region: ACTIONS
  Future<void> _joinNow(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    final success = await ref
        .read(meetingSessionProvider.notifier)
        .joinMeeting(code: code, title: title);
    if (!context.mounted || !success) {
      return;
    }
    context.pushReplacement(RouteNames.meetingLocation(code));
  }

  Future<void> _showDeviceSettingsSheet(
    BuildContext context,
    WidgetRef ref,
  ) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(meetingSessionProvider);
    final lobbyAsync = ref.watch(meetingLobbyProvider(code));
    final authEmail = ref.watch(authProvider).email ?? 'You';
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    final meetingTitle = lobbyAsync.asData?.value.title ?? 'Meeting';

    return Scaffold(
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
              code,
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
            onPressed: () => _showDeviceSettingsSheet(context, ref),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CameraPreviewPlaceholder(
                    userEmail: authEmail,
                    isMicOn: session.isMicOn,
                    isCameraOn: session.isCameraOn,
                    isFrontCamera: session.isFrontCamera,
                    onToggleMic: () =>
                        ref.read(meetingSessionProvider.notifier).toggleMic(),
                    onToggleCamera: () =>
                        ref.read(meetingSessionProvider.notifier).toggleCamera(),
                  ),
                  const SizedBox(height: 16),
                  _DeviceSettingsStrip(
                    audioOutput: session.audioOutput,
                    isFrontCamera: session.isFrontCamera,
                    onTapAudio: () => _showDeviceSettingsSheet(context, ref),
                    onTapCameraSwitch: () => ref
                        .read(meetingSessionProvider.notifier)
                        .toggleCameraFacing(),
                  ),
                  const SizedBox(height: 20),
                  _LobbyParticipantsSection(
                    lobbyAsync: lobbyAsync,
                    onRetry: () => ref.invalidate(meetingLobbyProvider(code)),
                  ),
                  if (session.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    AppErrorBanner(message: session.errorMessage!),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.joinGreen,
                        foregroundColor: colorScheme.onSecondary,
                      ),
                      onPressed: session.isJoining
                          ? null
                          : () => _joinNow(context, ref, meetingTitle),
                      icon: session.isJoining
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onSecondary,
                              ),
                            )
                          : const Icon(Icons.videocam_rounded, size: 20),
                      label: Text(session.isJoining ? 'Joining...' : 'Join now'),
                    ),
                  ),
                ],
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
  });

  final String userEmail;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isFrontCamera;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
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
                    tooltip: isMicOn ? 'Turn off microphone' : 'Turn on microphone',
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
    required this.lobbyAsync,
    required this.onRetry,
  });

  final AsyncValue<MeetingLobbyInfo> lobbyAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return lobbyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: AppLoadingIndicator(size: 20),
      ),
      error: (error, _) {
        final message = error is ApiException
            ? error.message
            : 'Unable to load meeting details.';
        return Column(
          children: [
            AppErrorBanner(message: message),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        );
      },
      data: (info) {
        final participants = info.waitingParticipants;
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

  String _summaryText(List<ParticipantModel> participants) {
    if (participants.length == 1) {
      return '${participants.first.name} is in this call';
    }
    if (participants.length == 2) {
      return '${participants[0].name} and ${participants[1].name} are in this call';
    }
    final remaining = participants.length - 2;
    final suffix = remaining == 1 ? 'other' : 'others';
    return '${participants[0].name}, ${participants[1].name}, and $remaining $suffix are in this call';
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.participants});

  final List<ParticipantModel> participants;

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
              nameOrEmail: visible[i].name,
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
