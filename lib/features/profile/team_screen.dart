import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/models/models.dart';

/// Per-person profiles on a shared device, so every capture is attributed
/// to whoever actually took it (addresses the attribution half of GAP SEC-01).
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider);
    final profiles = ref.watch(profilesProvider);
    final isAdmin = me?.isAdmin ?? false;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Team members')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useRootNavigator: true,
                builder: (_) => const _AddMemberSheet(),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add member'),
            )
          : null,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: profiles.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) => ListView(
              padding: EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, bottom + 100),
              children: [
                Text(
                  'Each person unlocks Cotopole with their own PIN, so captures are attributed to whoever took them.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                for (final p in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ContactAvatar(name: p.displayName, size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.id == me?.id ? '${p.displayName} (you)' : p.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                StatusPill(
                                  label: p.role.label,
                                  color: p.isAdmin ? AppColors.violet : AppColors.cyan,
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                          if (isAdmin && p.id != me?.id)
                            IconButton(
                              tooltip: 'Remove ${p.displayName}',
                              icon: const Icon(Icons.person_remove_rounded, color: AppColors.danger),
                              onPressed: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Remove ${p.displayName}?',
                                  message:
                                      'They will no longer be able to unlock Cotopole on this device. Their captured leads stay.',
                                  confirmLabel: 'Remove',
                                  destructive: true,
                                );
                                if (!ok) return;
                                try {
                                  await ref.read(profileRepoProvider).delete(p.id, actorId: me!.id);
                                  ref.refreshData();
                                } on StateError catch (e) {
                                  if (context.mounted) {
                                    showAppSnack(context, e.message, icon: Icons.error_rounded, color: AppColors.danger);
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  const _AddMemberSheet();

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  UserRole _role = UserRole.staff;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref.read(profileRepoProvider).create(
          displayName: _name.text,
          role: _role,
          pin: _pin.text,
          actorId: ref.read(sessionProvider)?.id,
        );
    ref.refreshData();
    if (!mounted) return;
    showAppSnack(context, '${_name.text.trim()} added');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add team member', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_rounded)),
              validator: (v) => Validators.required(v, field: 'Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Temporary PIN (6 digits)',
                prefixIcon: Icon(Icons.pin_rounded),
                counterText: '',
              ),
              validator: Validators.pin,
            ),
            const SizedBox(height: 12),
            SegmentedButton<UserRole>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: UserRole.staff, label: Text('Event Staff'), icon: Icon(Icons.badge_rounded)),
                ButtonSegment(
                  value: UserRole.admin,
                  label: Text('Organiser'),
                  icon: Icon(Icons.workspace_premium_rounded),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              _role == UserRole.admin
                  ? 'Organisers can create, edit and archive events and resolve duplicates.'
                  : 'Staff see active events and capture leads.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            GradientButton(label: 'Add member', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
