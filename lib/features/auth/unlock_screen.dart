import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'pin_entry.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  List<Profile> _profiles = const [];
  Profile? _selected;
  DateTime? _lockedUntil;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final profiles = await ref.read(profileRepoProvider).list();
    final lastId = await ref.read(settingsRepoProvider).get(SettingsRepository.kLastProfileId);
    if (!mounted) return;
    final selected = profiles.where((p) => p.id == lastId).firstOrNull ?? profiles.firstOrNull;
    setState(() {
      _profiles = profiles;
      _selected = selected;
    });
    _syncLock(selected?.lockedUntil);
  }

  void _syncLock(DateTime? until) {
    _ticker?.cancel();
    if (until == null || !until.isAfter(DateTime.now())) {
      setState(() => _lockedUntil = null);
      return;
    }
    setState(() => _lockedUntil = until);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (!_lockedUntil!.isAfter(DateTime.now())) {
        t.cancel();
        setState(() => _lockedUntil = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<String?> _verify(String pin) async {
    final p = _selected;
    if (p == null) return 'Choose a profile';
    final result = await ref.read(profileRepoProvider).verifyPin(p.id, pin);
    switch (result) {
      case PinOk(:final profile):
        await ref.read(settingsRepoProvider).set(SettingsRepository.kLastProfileId, profile.id);
        ref.read(sessionProvider.notifier).signIn(profile);
        return null;
      case PinWrong(:final attemptsLeft):
        return attemptsLeft <= 2
            ? 'Wrong PIN · $attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} left'
            : 'Wrong PIN';
      case PinLocked(:final until):
        _syncLock(until);
        return 'Too many attempts';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _selected;
    final locked = _lockedUntil != null;
    final secondsLeft = locked ? _lockedUntil!.difference(DateTime.now()).inSeconds + 1 : 0;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: const CotopoleLogo(height: 40).animate().fadeIn(duration: 500.ms),
                    ),
                    if (_profiles.length > 1) _profilePicker(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: p == null
                          ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
                          : PinEntryView(
                              key: ValueKey(p.id),
                              enabled: !locked,
                              header: ContactAvatar(name: p.displayName, size: 72, ring: true)
                                  .animate()
                                  .fadeIn()
                                  .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                              title: 'Welcome back, ${p.displayName.split(' ').first}',
                              subtitle: locked
                                  ? 'Locked for security · try again in ${secondsLeft}s'
                                  : 'Enter your PIN to unlock',
                              onCompleted: _verify,
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Offline · data stays on this device',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profilePicker() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _profiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final p = _profiles[i];
          final selected = p.id == _selected?.id;
          return GestureDetector(
            onTap: () {
              setState(() => _selected = p);
              _syncLock(p.lockedUntil);
            },
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: selected ? 1 : 0.5,
              child: Column(
                children: [
                  ContactAvatar(name: p.displayName, size: 50, ring: selected),
                  const SizedBox(height: 6),
                  Text(
                    p.displayName.split(' ').first,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
