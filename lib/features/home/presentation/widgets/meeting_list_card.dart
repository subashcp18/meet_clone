import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../meeting/data/models/meeting.dart';

class MeetingListCard extends StatelessWidget {
  const MeetingListCard({
    super.key,
    required this.meeting,
    required this.onJoin,
  });

  final Meeting meeting;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;

    return Card(
      child: InkWell(
        onTap: onJoin,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: meeting.isLive
                      ? colorScheme.secondaryContainer
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  meeting.isLive
                      ? Icons.sensors_rounded
                      : Icons.videocam_outlined,
                  color: meeting.isLive ? colors.joinGreen : colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.title,
                            style: textStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (meeting.isLive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'LIVE',
                              style: textStyles.labelSmall.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.formatMeetingWindow(
                        meeting.startTime,
                        meeting.durationMinutes,
                      ),
                      style: textStyles.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${meeting.code}  •  ${meeting.hostName}',
                      style: textStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: onJoin,
                child: const Text('Join'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
