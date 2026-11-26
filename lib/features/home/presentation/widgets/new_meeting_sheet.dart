import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_sheet_action_tile.dart';
import '../../data/models/meeting_summary.dart';
import '../../data/repositories/home_repository.dart';

enum _PendingAction { instant, link }

class NewMeetingSheet extends ConsumerStatefulWidget {
  const NewMeetingSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const NewMeetingSheet(),
    );
  }

  @override
  ConsumerState<NewMeetingSheet> createState() => _NewMeetingSheetState();
}

class _NewMeetingSheetState extends ConsumerState<NewMeetingSheet> {
  // region: STATE
  _PendingAction? _pendingAction;
  MeetingSummary? _generatedMeeting;
  String? _errorMessage;
  bool _copied = false;
  // endregion

  // region: ACTIONS
  Future<void> _getLink() async {
    setState(() {
      _pendingAction = _PendingAction.link;
      _errorMessage = null;
      _copied = false;
    });

    final result = await ref.read(homeRepositoryProvider).createInstantMeeting();
    if (!mounted) {
      return;
    }

    result.when(
      success: (meeting) {
        setState(() {
          _pendingAction = null;
          _generatedMeeting = meeting;
        });
      },
      failure: (exception) {
        setState(() {
          _pendingAction = null;
          _errorMessage = exception.message;
        });
      },
    );
  }

  Future<void> _startInstantMeeting() async {
    setState(() {
      _pendingAction = _PendingAction.instant;
      _errorMessage = null;
    });

    final result = await ref.read(homeRepositoryProvider).createInstantMeeting();
    if (!mounted) {
      return;
    }

    result.when(
      success: (meeting) {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push(RouteNames.lobbyLocation(meeting.code));
      },
      failure: (exception) {
        setState(() {
          _pendingAction = null;
          _errorMessage = exception.message;
        });
      },
    );
  }

  void _openSchedule() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.pushNamed(RouteNames.schedule);
  }

  Future<void> _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Meeting link copied to clipboard')),
      );
  }

  void _joinGeneratedMeeting(String code) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(RouteNames.lobbyLocation(code));
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final generated = _generatedMeeting;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (generated != null)
              _GeneratedLinkView(
                meeting: generated,
                copied: _copied,
                onCopy: () => _copyLink('https://meet.clone/${generated.code}'),
                onJoin: () => _joinGeneratedMeeting(generated.code),
                onBack: () => setState(() => _generatedMeeting = null),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  'New meeting',
                  style: textStyles.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppErrorBanner(message: _errorMessage!),
                ),
              ],
              AppSheetActionTile(
                icon: Icons.link_rounded,
                title: 'Get a meeting link to share',
                subtitle: 'Create a link you can send to guests',
                isLoading: _pendingAction == _PendingAction.link,
                onTap: _pendingAction == null ? _getLink : null,
              ),
              AppSheetActionTile(
                icon: Icons.video_call_rounded,
                title: 'Start an instant meeting',
                subtitle: 'Open the pre-join lobby right now',
                iconColor: colors.primary,
                isLoading: _pendingAction == _PendingAction.instant,
                onTap: _pendingAction == null ? _startInstantMeeting : null,
              ),
              AppSheetActionTile(
                icon: Icons.calendar_today_rounded,
                title: 'Schedule in Calendar',
                subtitle: 'Pick a date, time, and invitees',
                onTap: _pendingAction == null ? _openSchedule : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
  // endregion
}

class _GeneratedLinkView extends StatelessWidget {
  const _GeneratedLinkView({
    required this.meeting,
    required this.copied,
    required this.onCopy,
    required this.onJoin,
    required this.onBack,
  });

  final MeetingSummary meeting;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onJoin;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;
    final shareLink = 'https://meet.clone/${meeting.code}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                "Here's the link to your meeting",
                style: textStyles.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Copy this link and send it to people you want to meet with.',
            style: textStyles.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  shareLink,
                  style: textStyles.meetingCode.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onCopy,
                tooltip: 'Copy link',
                icon: Icon(
                  copied ? Icons.check_rounded : Icons.copy_rounded,
                  color: copied ? colors.joinGreen : colors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: Icon(
                  copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 18,
                ),
                label: Text(copied ? 'Copied' : 'Copy link'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onJoin,
                icon: const Icon(Icons.videocam_rounded, size: 18),
                label: const Text('Join'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
