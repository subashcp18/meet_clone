import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/app_brand_mark.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_user_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../meeting/data/models/open_meeting.dart';
import '../../../meeting/data/repositories/meeting_repository.dart';
import '../../providers/home_provider.dart';
import '../widgets/meeting_list_card.dart';
import '../widgets/new_meeting_sheet.dart';

enum _AccountMenuAction { settings, signOut }

enum _OngoingMenuAction { endMeeting }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  // region: LIFECYCLE
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(upcomingMeetingsProvider);
    }
  }
  // endregion

  // region: ACTIONS
  Future<void> _openLobby(String code) async {
    await context.push(RouteNames.lobbyLocation(code));
    if (mounted) {
      ref.invalidate(upcomingMeetingsProvider);
    }
  }

  Future<void> _openJoinWithCode() async {
    await context.pushNamed(RouteNames.join);
    if (mounted) {
      ref.invalidate(upcomingMeetingsProvider);
    }
  }

  Future<void> _confirmEndMeeting(OpenMeeting meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End this meeting?'),
        content: Text(
          'Ending "${meeting.title}" closes the meeting for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dialogContext.colors.endCallRed,
              foregroundColor: dialogContext.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End meeting'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final result = await ref
        .read(meetingRepositoryProvider)
        .endMeeting(meeting.id);
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) {
        ref.invalidate(upcomingMeetingsProvider);
      },
      failure: (exception) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(exception.message)));
      },
    );
  }

  Future<void> _handleAccountAction(_AccountMenuAction action) async {
    switch (action) {
      case _AccountMenuAction.settings:
        await context.pushNamed(RouteNames.settings);
      case _AccountMenuAction.signOut:
        await ref.read(authControllerProvider.notifier).signOut();
    }
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(homeTabProvider);
    final user = ref.watch(authControllerProvider).asData?.value;
    final meetingsAsync = ref.watch(upcomingMeetingsProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;
    final userEmail = user?.email ?? user?.displayName ?? 'User';

    ref.listen<AsyncValue<List<OpenMeeting>>>(upcomingMeetingsProvider, (
      previous,
      next,
    ) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(ApiException.friendlyMessage(next.error!))),
          );
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Settings',
          onPressed: () => context.pushNamed(RouteNames.settings),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppBrandMark(iconSize: 28, showLabel: false),
            const SizedBox(width: 10),
            Text(
              AppConstants.appName,
              style: textStyles.titleLarge,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<_AccountMenuAction>(
              tooltip: userEmail,
              onSelected: _handleAccountAction,
              itemBuilder: (context) => [
                PopupMenuItem<_AccountMenuAction>(
                  enabled: false,
                  child: Text(
                    userEmail,
                    style: textStyles.labelMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<_AccountMenuAction>(
                  value: _AccountMenuAction.settings,
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem<_AccountMenuAction>(
                  value: _AccountMenuAction.signOut,
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Sign out'),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AppUserAvatar(nameOrEmail: userEmail),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: selectedTab == HomeTab.meet
            ? _MeetTabView(
                meetingsAsync: meetingsAsync,
                onNewMeeting: () => NewMeetingSheet.show(context),
                onJoinWithCode: _openJoinWithCode,
                onJoinMeeting: _openLobby,
                onEndMeeting: _confirmEndMeeting,
                onRefresh: () =>
                    ref.read(upcomingMeetingsProvider.notifier).refresh(),
              )
            : _CalendarTabView(
                meetingsAsync: meetingsAsync,
                onSchedule: () => context.pushNamed(RouteNames.schedule),
                onJoinMeeting: _openLobby,
                onRefresh: () =>
                    ref.read(upcomingMeetingsProvider.notifier).refresh(),
              ),
      ),
      floatingActionButton: selectedTab == HomeTab.calendar
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed(RouteNames.schedule),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Schedule'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab.index,
        onDestinationSelected: (index) {
          ref.read(homeTabProvider.notifier).select(HomeTab.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam_rounded),
            label: 'Meet',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
  // endregion
}

class _MeetTabView extends StatelessWidget {
  const _MeetTabView({
    required this.meetingsAsync,
    required this.onNewMeeting,
    required this.onJoinWithCode,
    required this.onJoinMeeting,
    required this.onEndMeeting,
    required this.onRefresh,
  });

  final AsyncValue<List<OpenMeeting>> meetingsAsync;
  final VoidCallback onNewMeeting;
  final VoidCallback onJoinWithCode;
  final ValueChanged<String> onJoinMeeting;
  final ValueChanged<OpenMeeting> onEndMeeting;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onNewMeeting,
                  icon: const Icon(Icons.video_call_rounded, size: 20),
                  label: const Text(
                    'New meeting',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onJoinWithCode,
                  icon: const Icon(Icons.keyboard_rounded, size: 20),
                  label: const Text(
                    'Join with a code',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: meetingsAsync.when(
            loading: () => const AppLoadingIndicator(
              message: 'Loading meetings...',
            ),
            error: (error, _) {
              return AppErrorState(
                message: ApiException.friendlyMessage(error),
                onRetry: onRefresh,
              );
            },
            data: (meetings) {
              final ongoing = meetings.where((m) => m.isLive).toList();
              final upcoming = meetings.where((m) => !m.isLive).toList();

              if (ongoing.isEmpty && upcoming.isEmpty) {
                return AppEmptyState(
                  icon: Icons.event_available_rounded,
                  title: 'No upcoming meetings',
                  subtitle: 'Start a new meeting or join one using a code.',
                  actionLabel: 'Refresh',
                  onAction: onRefresh,
                );
              }

              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (ongoing.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Ongoing',
                          style: textStyles.titleSmall.copyWith(
                            color: colors.joinGreen,
                          ),
                        ),
                      ),
                      for (final meeting in ongoing) ...[
                        _OngoingMeetingCard(
                          meeting: meeting,
                          onRejoin: () => onJoinMeeting(meeting.code),
                          onEndMeeting: meeting.amIHost
                              ? () => onEndMeeting(meeting)
                              : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (upcoming.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          0,
                          ongoing.isNotEmpty ? 10 : 0,
                          0,
                          8,
                        ),
                        child: Text(
                          'Upcoming meetings',
                          style: textStyles.titleSmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      for (final meeting in upcoming) ...[
                        MeetingListCard(
                          meeting: meeting,
                          onJoin: () => onJoinMeeting(meeting.code),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OngoingMeetingCard extends StatelessWidget {
  const _OngoingMeetingCard({
    required this.meeting,
    required this.onRejoin,
    this.onEndMeeting,
  });

  final OpenMeeting meeting;
  final VoidCallback onRejoin;
  final VoidCallback? onEndMeeting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = context.colorScheme;
    final textStyles = context.textStyles;
    final count = meeting.activeParticipantCount;
    final countLabel = count == 1 ? '1 person in call' : '$count people in call';

    return Card(
      child: InkWell(
        onTap: onRejoin,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sensors_rounded,
                  color: colors.joinGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      style: textStyles.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$countLabel  •  ${meeting.code}',
                      style: textStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onRejoin,
                child: const Text('Rejoin'),
              ),
              if (onEndMeeting != null)
                PopupMenuButton<_OngoingMenuAction>(
                  tooltip: 'Meeting options',
                  onSelected: (action) {
                    if (action == _OngoingMenuAction.endMeeting) {
                      onEndMeeting?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<_OngoingMenuAction>(
                      value: _OngoingMenuAction.endMeeting,
                      child: Row(
                        children: [
                          Icon(
                            Icons.call_end_rounded,
                            size: 18,
                            color: colors.endCallRed,
                          ),
                          const SizedBox(width: 10),
                          const Text('End meeting'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarTabView extends StatelessWidget {
  const _CalendarTabView({
    required this.meetingsAsync,
    required this.onSchedule,
    required this.onJoinMeeting,
    required this.onRefresh,
  });

  final AsyncValue<List<OpenMeeting>> meetingsAsync;
  final VoidCallback onSchedule;
  final ValueChanged<String> onJoinMeeting;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scheduled meetings',
                style: textStyles.titleSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              TextButton.icon(
                onPressed: onSchedule,
                icon: const Icon(Icons.event_rounded, size: 18),
                label: const Text('New event'),
              ),
            ],
          ),
        ),
        Expanded(
          child: meetingsAsync.when(
            loading: () => const AppLoadingIndicator(
              message: 'Loading meetings...',
            ),
            error: (error, _) {
              return AppErrorState(
                message: ApiException.friendlyMessage(error),
                onRetry: onRefresh,
              );
            },
            data: (meetings) {
              if (meetings.isEmpty) {
                return AppEmptyState(
                  icon: Icons.event_available_rounded,
                  title: 'Your calendar is clear',
                  subtitle: 'Schedule a meeting to invite participants.',
                  actionLabel: 'Refresh',
                  onAction: onRefresh,
                );
              }
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: meetings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final meeting = meetings[index];
                    return MeetingListCard(
                      meeting: meeting,
                      onJoin: () => onJoinMeeting(meeting.code),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
