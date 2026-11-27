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
import '../../../meeting/data/models/meeting.dart';
import '../../providers/home_provider.dart';
import '../widgets/meeting_list_card.dart';
import '../widgets/new_meeting_sheet.dart';

enum _AccountMenuAction { settings, signOut }

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // region: ACTIONS
  void _openLobby(BuildContext context, String code) {
    context.push(RouteNames.lobbyLocation(code));
  }

  Future<void> _handleAccountAction(
    BuildContext context,
    WidgetRef ref,
    _AccountMenuAction action,
  ) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(homeTabProvider);
    final user = ref.watch(authControllerProvider).asData?.value;
    final meetingsAsync = ref.watch(upcomingMeetingsProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;
    final userEmail = user?.email ?? user?.displayName ?? 'User';

    ref.listen<AsyncValue<List<Meeting>>>(upcomingMeetingsProvider, (
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
              onSelected: (action) => _handleAccountAction(context, ref, action),
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
                onJoinWithCode: () => context.pushNamed(RouteNames.join),
                onJoinMeeting: (code) => _openLobby(context, code),
                onRefresh: () =>
                    ref.read(upcomingMeetingsProvider.notifier).refresh(),
              )
            : _CalendarTabView(
                meetingsAsync: meetingsAsync,
                onSchedule: () => context.pushNamed(RouteNames.schedule),
                onJoinMeeting: (code) => _openLobby(context, code),
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
    required this.onRefresh,
  });

  final AsyncValue<List<Meeting>> meetingsAsync;
  final VoidCallback onNewMeeting;
  final VoidCallback onJoinWithCode;
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Upcoming meetings',
            style: textStyles.titleSmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: _MeetingsListView(
            meetingsAsync: meetingsAsync,
            emptyTitle: 'No upcoming meetings',
            emptySubtitle: 'Start a new meeting or join one using a code.',
            onJoinMeeting: onJoinMeeting,
            onRefresh: onRefresh,
          ),
        ),
      ],
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

  final AsyncValue<List<Meeting>> meetingsAsync;
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
          child: _MeetingsListView(
            meetingsAsync: meetingsAsync,
            emptyTitle: 'Your calendar is clear',
            emptySubtitle: 'Schedule a meeting to invite participants.',
            onJoinMeeting: onJoinMeeting,
            onRefresh: onRefresh,
          ),
        ),
      ],
    );
  }
}

class _MeetingsListView extends StatelessWidget {
  const _MeetingsListView({
    required this.meetingsAsync,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onJoinMeeting,
    required this.onRefresh,
  });

  final AsyncValue<List<Meeting>> meetingsAsync;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<String> onJoinMeeting;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return meetingsAsync.when(
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
            title: emptyTitle,
            subtitle: emptySubtitle,
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
    );
  }
}
