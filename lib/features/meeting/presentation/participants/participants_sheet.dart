import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_user_avatar.dart';
import '../../data/models/meeting_participant.dart';
import '../../providers/meeting_session_provider.dart';

enum _ParticipantMenuAction { mute, remove }

class ParticipantsSheet extends ConsumerStatefulWidget {
  const ParticipantsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: AppTheme.callTheme,
        child: const ParticipantsSheet(),
      ),
    );
  }

  @override
  ConsumerState<ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends ConsumerState<ParticipantsSheet> {
  // region: CONTROLLERS & STATE
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  // endregion

  // region: ACTIONS
  Future<void> _copyInviteLink(String code) async {
    final link = 'https://meet.clone/$code';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Joining info copied to clipboard')),
      );
  }

  Future<void> _handleAction(
    MeetingParticipant participant,
    _ParticipantMenuAction action,
  ) async {
    final notifier = ref.read(meetingSessionProvider.notifier);
    switch (action) {
      case _ParticipantMenuAction.mute:
        await notifier.muteParticipant(participant.id);
      case _ParticipantMenuAction.remove:
        await notifier.removeParticipant(participant.id);
    }
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(meetingSessionProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;

    final filtered = session.participants.where((participant) {
      if (_query.isEmpty) {
        return true;
      }
      final q = _query.toLowerCase();
      return participant.name.toLowerCase().contains(q) ||
          participant.email.toLowerCase().contains(q);
    }).toList();

    final raisedHandsCount = session.participants
        .where((p) => p.isHandRaised)
        .length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'People (${session.participants.length})',
                        style: textStyles.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _copyInviteLink(session.code),
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: const Text('Add others'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search people',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                ),
              ),
              if (raisedHandsCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.callControlSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.back_hand_rounded,
                          size: 16,
                          color: colors.warningAmber,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$raisedHandsCount raised hand${raisedHandsCount == 1 ? '' : 's'}',
                          style: textStyles.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? AppEmptyState(
                        icon: Icons.person_search_rounded,
                        title: session.participants.isEmpty
                            ? 'No participants yet'
                            : 'No matching people',
                        subtitle: session.participants.isEmpty
                            ? 'People who join will show up here.'
                            : 'Try searching with a different name or email.',
                        actionLabel: _query.isNotEmpty ? 'Clear search' : null,
                        onAction: _query.isNotEmpty
                            ? () {
                                _searchController.clear();
                                setState(() => _query = '');
                              }
                            : null,
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final participant = filtered[index];
                          return _ParticipantRow(
                            participant: participant,
                            onSelected: (action) =>
                                _handleAction(participant, action),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
  // endregion
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.onSelected,
  });

  final MeetingParticipant participant;
  final ValueChanged<_ParticipantMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final subtitleParts = <String>[
      if (participant.isSelf) 'You',
      if (participant.isHost) 'Meeting host',
      if (!participant.isVideoOn) 'Camera off',
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: AppUserAvatar(nameOrEmail: participant.name),
      title: Text(
        participant.name,
        style: textStyles.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitleParts.isNotEmpty
          ? Text(
              subtitleParts.join(' • '),
              style: textStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (participant.isHandRaised) ...[
            Icon(
              Icons.back_hand_rounded,
              size: 18,
              color: colors.warningAmber,
            ),
            const SizedBox(width: 10),
          ],
          Icon(
            participant.isMuted
                ? Icons.mic_off_rounded
                : participant.isSpeaking
                ? Icons.graphic_eq_rounded
                : Icons.mic_rounded,
            size: 20,
            color: participant.isMuted
                ? colors.endCallRed
                : participant.isSpeaking
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
          if (!participant.isSelf)
            PopupMenuButton<_ParticipantMenuAction>(
              tooltip: 'Participant actions',
              onSelected: onSelected,
              itemBuilder: (context) => [
                if (!participant.isMuted)
                  const PopupMenuItem<_ParticipantMenuAction>(
                    value: _ParticipantMenuAction.mute,
                    child: Row(
                      children: [
                        Icon(Icons.mic_off_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Mute'),
                      ],
                    ),
                  ),
                const PopupMenuItem<_ParticipantMenuAction>(
                  value: _ParticipantMenuAction.remove,
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Remove from call'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
