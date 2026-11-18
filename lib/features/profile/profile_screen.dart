import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/models/models.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/stats_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider);
    if (p == null) return const SizedBox.shrink();
    final stats = ref.watch(dashboardProvider).dataOrNull ?? DashboardStats.empty;
    final autoLock = ref.watch(autoLockMinutesProvider).dataOrNull ?? SettingsRepository.defaultAutoLockMinutes;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, bottom + 24),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          GlassCard(
            radius: AppRadii.xl,
            glowColor: AppColors.violet,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    ContactAvatar(name: p.displayName, size: 64, ring: true),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.displayName, style: Theme.of(context).textTheme.titleLarge),
                          if (p.title != null) Text(p.title!, style: Theme.of(context).textTheme.bodyMedium),
                          if (p.email != null) Text(p.email!, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 8),
                          StatusPill(
                            label: p.role.label,
                            color: p.isAdmin ? AppColors.violet : AppColors.cyan,
                            icon: p.isAdmin ? Icons.workspace_premium_rounded : Icons.badge_rounded,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit profile',
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => _editProfile(context, ref, p),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    _Stat(label: 'Leads', value: stats.totalContacts),
                    _Stat(label: 'Events', value: stats.activeEvents),
                    _Stat(label: 'This week', value: stats.capturesThisWeek),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),
          const SectionHeader('Team'),
          _Group(children: [
            _Row(
              icon: Icons.groups_rounded,
              color: AppColors.primary,
              label: 'Team members',
              value: p.isAdmin ? 'Manage' : null,
              onTap: () => context.push(Routes.team),
            ),
          ]),
          const SectionHeader('Security'),
          _Group(children: [
            _Row(
              icon: Icons.pin_rounded,
              color: AppColors.cyan,
              label: 'Change PIN',
              onTap: () => context.push(Routes.changePin),
            ),
            _Row(
              icon: Icons.timer_outlined,
              color: AppColors.teal,
              label: 'Auto-lock',
              value: autoLock <= 0 ? 'Never' : 'After $autoLock min',
              onTap: () => _pickAutoLock(context, ref, autoLock),
            ),
          ]),
          const SectionHeader('Data'),
          _Group(children: [
            _Row(
              icon: Icons.shield_rounded,
              color: AppColors.violet,
              label: 'Data & privacy',
              value: 'On device',
              onTap: () => context.push(Routes.dataPrivacy),
            ),
          ]),
          const SectionHeader('Session'),
          _Group(children: [
            _Row(
              icon: Icons.lock_rounded,
              color: AppColors.warning,
              label: 'Lock / switch user',
              onTap: () => ref.read(sessionProvider.notifier).signOut(),
            ),
          ]),
          const SizedBox(height: 28),
          const Center(child: CotopoleLogo(height: 26)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Cotopole Mobile · v1.0.0 · Offline edition',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Center(
            child: Text('© Ideahub Solutions LLC', style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAutoLock(BuildContext context, WidgetRef ref, int current) async {
    const options = [1, 5, 15, 30, 0];
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Auto-lock', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final m in options)
                ListTile(
                  title: Text(m == 0 ? 'Never' : 'After $m minute${m == 1 ? '' : 's'} in background'),
                  trailing: m == current ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () => Navigator.pop(ctx, m),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(settingsRepoProvider).set(SettingsRepository.kAutoLockMinutes, '$picked');
    ref.refreshData();
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref, Profile p) async {
    final name = TextEditingController(text: p.displayName);
    final title = TextEditingController(text: p.title ?? '');
    final email = TextEditingController(text: p.email ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 10),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final repo = ref.read(profileRepoProvider);
      await repo.update(p, displayName: name.text, title: title.text, email: email.text);
      final updated = await repo.get(p.id);
      if (updated != null) ref.read(sessionProvider.notifier).refresh(updated);
      ref.refreshData();
    }
    // Controllers are left to GC: disposing here would race the dialog's
    // exit animation, which still reads them.
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 64, height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.color, required this.label, required this.onTap, this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: IconBadge(icon: icon, color: color, size: 38, iconSize: 19),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
