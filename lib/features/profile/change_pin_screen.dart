import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../data/repositories/profile_repository.dart';
import '../auth/pin_entry.dart';

enum _Step { current, next, confirm }

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Step _step = _Step.current;
  String _new = '';

  Future<String?> _onPin(String pin) async {
    final profile = ref.read(sessionProvider);
    if (profile == null) return 'Not signed in';
    final repo = ref.read(profileRepoProvider);
    switch (_step) {
      case _Step.current:
        final r = await repo.verifyPin(profile.id, pin);
        if (r is PinOk) {
          setState(() => _step = _Step.next);
          return null;
        }
        if (r is PinLocked) {
          ref.read(sessionProvider.notifier).signOut();
          return 'Too many attempts';
        }
        return 'Wrong PIN';
      case _Step.next:
        if (RegExp(r'^(\d)\1+$').hasMatch(pin) || pin == '123456') return 'Pick a less predictable PIN';
        setState(() {
          _new = pin;
          _step = _Step.confirm;
        });
        return null;
      case _Step.confirm:
        if (pin != _new) {
          setState(() => _step = _Step.next);
          return null;
        }
        await repo.changePin(profile.id, pin);
        if (mounted) {
          showAppSnack(context, 'PIN updated');
          context.pop();
        }
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      _Step.current => ('Enter current PIN', 'Confirm it is you'),
      _Step.next => ('New PIN', 'Choose six digits'),
      _Step.confirm => ('Confirm new PIN', 'Enter it once more'),
    };
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Change PIN')),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: PinEntryView(
                key: ValueKey(_step),
                title: title,
                subtitle: subtitle,
                header: const IconBadge(icon: Icons.pin_rounded, size: 60, iconSize: 28, circle: true),
                onCompleted: _onPin,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
