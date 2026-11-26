import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/app_user_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../meeting/providers/meeting_session_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // region: ACTIONS
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text(
          'Are you sure you want to sign out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);
    final useMockApi = ref.watch(useMockApiProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;
    final email = authState.email ?? 'user@example.com';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _SectionLabel(title: 'Account'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AppUserAvatar(nameOrEmail: email, radius: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: textStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            useMockApi
                                ? 'Signed in (Mock Phase 1)'
                                : 'Signed in',
                            style: textStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: authState.isBusy
                          ? null
                          : () => _confirmSignOut(context, ref),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel(title: 'Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: textStyles.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'In-call screens always use the dark call palette.',
                      style: textStyles.caption,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_outlined, size: 18),
                            label: Text('System'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined, size: 18),
                            label: Text('Light'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined, size: 18),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (selection) {
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(selection.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel(title: 'Audio & Video Defaults'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: settings.defaultMicOn,
                    onChanged: (value) async {
                      await ref
                          .read(settingsProvider.notifier)
                          .setDefaultMicOn(value);
                      ref
                          .read(meetingSessionProvider.notifier)
                          .setDefaults(
                            micOn: value,
                            cameraOn: settings.defaultCameraOn,
                          );
                    },
                    secondary: const Icon(Icons.mic_none_rounded),
                    title: const Text('Join with microphone on'),
                    subtitle: const Text(
                      'Automatically enable mic in the pre-join lobby',
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: settings.defaultCameraOn,
                    onChanged: (value) async {
                      await ref
                          .read(settingsProvider.notifier)
                          .setDefaultCameraOn(value);
                      ref
                          .read(meetingSessionProvider.notifier)
                          .setDefaults(
                            micOn: settings.defaultMicOn,
                            cameraOn: value,
                          );
                    },
                    secondary: const Icon(Icons.videocam_outlined),
                    title: const Text('Join with camera on'),
                    subtitle: const Text(
                      'Automatically enable video in the pre-join lobby',
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: settings.noiseCancellation,
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setNoiseCancellation(value),
                    secondary: const Icon(Icons.graphic_eq_rounded),
                    title: const Text('Noise cancellation'),
                    subtitle: const Text(
                      'Filter background sound from your microphone',
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: settings.limitDataUsage,
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setLimitDataUsage(value),
                    secondary: const Icon(Icons.data_saver_on_outlined),
                    title: const Text('Limit data usage'),
                    subtitle: const Text(
                      'Adjust video resolution on metered networks',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel(title: 'About'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.info_outline_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    title: const Text(AppConstants.appName),
                    subtitle: const Text('Version 1.0.0'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // endregion
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: textStyles.titleSmall.copyWith(
          color: colors.primary,
        ),
      ),
    );
  }
}
