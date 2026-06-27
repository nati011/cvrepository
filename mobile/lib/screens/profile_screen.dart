import 'package:cv_exec_feed/models.dart';
import 'package:cv_exec_feed/providers/app_provider.dart';
import 'package:cv_exec_feed/providers/stats_provider.dart';
import 'package:cv_exec_feed/screens/stats_screen.dart';
import 'package:cv_exec_feed/theme.dart';
import 'package:cv_exec_feed/widgets/common.dart';
import 'package:cv_exec_feed/widgets/linkedin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String execIdInitials(String execId) {
  final parts = execId.split(RegExp(r'[-_\s]+')).where((p) => p.isNotEmpty);
  final list = parts.toList();
  if (list.isEmpty) return 'EX';
  if (list.length == 1) return list.first.substring(0, 1).toUpperCase();
  return (list.first.substring(0, 1) + list.last.substring(0, 1)).toUpperCase();
}

String execDisplayName(String execId) {
  final parts = execId
      .split(RegExp(r'[-_\s]+'))
      .where((p) => p.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p))
      .toList();
  if (parts.isEmpty) return 'Talent Reviewer';
  return parts.map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final execId = ref.watch(execIdProvider);
    final themeMode = ref.watch(appProvider).themeMode;
    final statsAsync = ref.watch(statsProvider);
    final myStat = statsAsync.maybeWhen(
      data: (stats) {
        for (final s in stats) {
          if (s.execId == execId) return s;
        }
        return null;
      },
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ProfileHero(
            initials: execIdInitials(execId),
            name: execDisplayName(execId),
            role: 'Executive reviewer',
          ),
          const SizedBox(height: 16),
          _ActivitySection(
            stat: myStat,
            loading: statsAsync.isLoading,
            onViewLeaderboard: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _AccountSection(
            execId: execId,
            onEdit: () => _editExecId(context, ref, execId),
          ),
          const SizedBox(height: 16),
          _AppearanceSection(
            themeMode: themeMode,
            onChanged: (mode) =>
                ref.read(appProvider.notifier).setThemeMode(mode),
          ),
        ],
      ),
    );
  }

  void _editExecId(BuildContext context, WidgetRef ref, String execId) {
    final ctrl = TextEditingController(text: execId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reviewer identity',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Exec ID',
                  helperText: 'Used for reactions and leaderboard stats.',
                ),
              ),
              const SizedBox(height: 16),
              LiButton(
                label: 'Save',
                onPressed: () {
                  ref.read(appProvider.notifier).setExecId(ctrl.text);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String initials;
  final String name;
  final String role;

  const _ProfileHero({
    required this.initials,
    required this.name,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: LiAvatar(initials: initials, size: 64),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  final ExecStat? stat;
  final bool loading;
  final VoidCallback onViewLeaderboard;

  const _ActivitySection({
    required this.stat,
    required this.loading,
    required this.onViewLeaderboard,
  });

  @override
  Widget build(BuildContext context) {
    return LiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(
            icon: Icons.insights_outlined,
            label: 'Your activity',
          ),
          const SizedBox(height: 14),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (stat == null)
            Text(
              'No activity yet. Like or star candidates in the Feed to track your score.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _StatPill(
                    label: 'Total',
                    value: stat!.totalReviews,
                    color: AppTheme.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    label: 'Likes',
                    value: stat!.likes,
                    color: AppTheme.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatPill(
                    label: 'Stars',
                    value: stat!.stars,
                    color: AppTheme.gold,
                  ),
                ),
              ],
            ),
          if (stat != null) ...[
            const SizedBox(height: 12),
            LiTag(label: '🔥 ${stat!.streakDays} day streak', color: AppTheme.gold),
          ],
          const SizedBox(height: 16),
          LiButton(
            label: 'View leaderboard',
            icon: Icons.leaderboard_outlined,
            variant: LiButtonVariant.secondary,
            expand: true,
            onPressed: onViewLeaderboard,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  final String execId;
  final VoidCallback onEdit;

  const _AccountSection({required this.execId, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(icon: Icons.person_outline, label: 'Account'),
          const SizedBox(height: 14),
          _Field(label: 'Exec ID', value: execId),
          const SizedBox(height: 12),
          const _Field(
            label: 'Organization',
            value: 'Kifiya Financial Technology',
          ),
          const SizedBox(height: 16),
          LiButton(
            label: 'Edit reviewer identity',
            icon: Icons.edit_outlined,
            variant: LiButtonVariant.secondary,
            expand: true,
            onPressed: onEdit,
          ),
          const SizedBox(height: 8),
          Text(
            'Your exec ID is used to attribute reactions and appear on the leaderboard.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  const _AppearanceSection({
    required this.themeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(icon: Icons.palette_outlined, label: 'Appearance'),
          const SizedBox(height: 6),
          Text(
            'Light, dark, or match your system setting.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.settings_brightness_outlined, size: 18),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}
