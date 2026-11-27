import 'package:flutter/material.dart';

import '../../../../../core/utils/extensions.dart';
import '../../../../../core/widgets/app_user_avatar.dart';
import '../../../data/models/meeting_participant.dart';

class ParticipantVideoTile extends StatelessWidget {
  const ParticipantVideoTile({
    super.key,
    required this.participant,
    this.isCompact = false,
    this.onTap,
  });

  final MeetingParticipant participant;
  final bool isCompact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    final borderColor = participant.isSpeaking
        ? colors.primary
        : colors.outline.withValues(alpha: 0.25);

    final content = Container(
      decoration: BoxDecoration(
        color: colors.tileSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: participant.isSpeaking ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppUserAvatar(
                      nameOrEmail: participant.name,
                      radius: isCompact ? 20 : 28,
                      backgroundColor: participant.isVideoOn
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHigh,
                      foregroundColor: participant.isVideoOn
                          ? colorScheme.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                    if (!participant.isVideoOn && !isCompact) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Camera off',
                        style: textStyles.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (participant.isHandRaised)
                  _TileBadge(
                    icon: Icons.back_hand_rounded,
                    backgroundColor: colors.warningAmber,
                    iconColor: colorScheme.onSecondary,
                  ),
                if (participant.isHandRaised &&
                    (participant.isMuted || participant.isSpeaking))
                  const SizedBox(width: 6),
                if (participant.isMuted)
                  _TileBadge(
                    icon: Icons.mic_off_rounded,
                    backgroundColor:
                        colors.callBackground.withValues(alpha: 0.72),
                    iconColor: colors.endCallRed,
                  )
                else if (participant.isSpeaking)
                  _TileBadge(
                    icon: Icons.graphic_eq_rounded,
                    backgroundColor: colors.primary,
                    iconColor: colorScheme.onPrimary,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.callBackground.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  participant.isHost && !isCompact
                      ? '${participant.name} (Host)'
                      : participant.name,
                  style: textStyles.participantName.copyWith(
                    fontSize: isCompact ? 11 : 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _TileBadge extends StatelessWidget {
  const _TileBadge({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 14,
        color: iconColor,
      ),
    );
  }
}
