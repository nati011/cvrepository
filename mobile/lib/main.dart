import 'package:cv_exec_feed/data/providers.dart';
import 'package:cv_exec_feed/providers/app_provider.dart';
import 'package:cv_exec_feed/providers/feed_provider.dart';
import 'package:cv_exec_feed/screens/campaigns_screen.dart';
import 'package:cv_exec_feed/screens/jobs_screen.dart';
import 'package:cv_exec_feed/screens/chat_screen.dart';
import 'package:cv_exec_feed/screens/feed_screen.dart';
import 'package:cv_exec_feed/screens/lists_screen.dart';
import 'package:cv_exec_feed/screens/profile_screen.dart';
import 'package:cv_exec_feed/providers/notifications_provider.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:cv_exec_feed/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CVExecFeedApp(),
    ),
  );
}

class CVExecFeedApp extends ConsumerWidget {
  const CVExecFeedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appProvider).themeMode;
    return MaterialApp(
      title: 'CV Exec Feed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _RootTabs(),
    );
  }
}

class _NavItem {
  final String label;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const _NavItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}

class _RootTabs extends ConsumerWidget {
  const _RootTabs();

  static const _items = <_NavItem>[
    _NavItem(
      label: 'Feed',
      subtitle: 'Ranked candidates to review',
      icon: Icons.view_agenda_outlined,
      selectedIcon: Icons.view_agenda,
      page: FeedScreen(),
    ),
    _NavItem(
      label: 'Jobs',
      subtitle: 'Reusable role definitions',
      icon: Icons.work_outline,
      selectedIcon: Icons.work,
      page: JobsScreen(),
    ),
    _NavItem(
      label: 'Campaigns',
      subtitle: 'Hiring initiatives & ranking',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      page: CampaignsScreen(),
    ),
    _NavItem(
      label: 'Lists',
      subtitle: 'Liked & starred',
      icon: Icons.bookmarks_outlined,
      selectedIcon: Icons.bookmarks,
      page: ListsScreen(),
    ),
    _NavItem(
      label: 'Chat',
      subtitle: 'Ask the CV pile anything',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      page: ChatScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(feedPipelineWatcherProvider);
    final index = ref.watch(appProvider).selectedTabIndex;
    final hasUnread = ref.watch(visibleNotificationsProvider).maybeWhen(
          data: (notices) =>
              notices.isNotEmpty && !ref.watch(notificationsReadProvider),
          orElse: () => false,
        );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 56,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: GestureDetector(
              onTap: () => _openProfile(context),
              child: LiAvatar(
                initials: execIdInitials(ref.watch(execIdProvider)),
                size: 32,
                muted: true,
              ),
            ),
          ),
        ),
        title: const _TopSearch(),
        actions: [
          LiIconButton(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            showBadge: hasUnread,
            onPressed: () => openNotificationsScreen(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: index,
          children: _items.map((e) => e.page).toList(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: _items
            .map((e) => NavigationDestination(
                  icon: Icon(e.icon),
                  selectedIcon: Icon(e.selectedIcon),
                  label: e.label,
                ))
            .toList(),
        onDestinationSelected: (i) =>
            ref.read(appProvider.notifier).setTab(i),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }
}

class _TopSearch extends ConsumerStatefulWidget {
  const _TopSearch();

  @override
  ConsumerState<_TopSearch> createState() => _TopSearchState();
}

class _TopSearchState extends ConsumerState<_TopSearch> {
  late final TextEditingController _c =
      TextEditingController(text: ref.read(feedSearchProvider));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: LiSearchField(
        controller: _c,
        hint: 'Search candidates, skills, roles',
        onChanged: (v) {
          ref.read(feedSearchProvider.notifier).state = v;
          setState(() {});
        },
        onClear: () {
          _c.clear();
          ref.read(feedSearchProvider.notifier).state = '';
          setState(() {});
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}
