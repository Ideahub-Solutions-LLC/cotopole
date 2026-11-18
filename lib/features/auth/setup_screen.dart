import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/models/models.dart';
import '../../data/repositories/settings_repository.dart';
import 'pin_entry.dart';

/// First-run setup: create the device's organiser profile and PIN.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

enum _Step { profile, pin, confirm }

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _title = TextEditingController();
  _Step _step = _Step.profile;
  String _firstPin = '';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<String?> _onPin(String pin) async {
    if (_step == _Step.pin) {
      if (RegExp(r'^(\d)\1+$').hasMatch(pin) || pin == '123456' || pin == '654321') {
        return 'Pick a less predictable PIN';
      }
      setState(() {
        _firstPin = pin;
        _step = _Step.confirm;
      });
      return null;
    }
    if (pin != _firstPin) {
      setState(() => _step = _Step.pin);
      showAppSnack(
        context,
        "PINs didn't match — try again",
        icon: Icons.error_rounded,
        color: AppColors.danger,
      );
      return null;
    }
    final profile = await ref.read(profileRepoProvider).create(
          displayName: _name.text,
          email: _email.text,
          title: _title.text,
          role: UserRole.admin,
          pin: pin,
        );
    await ref.read(settingsRepoProvider).set(SettingsRepository.kLastProfileId, profile.id);
    ref.read(sessionProvider.notifier).signIn(profile);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: _step == _Step.profile
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _step = _Step.profile),
              ),
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: switch (_step) {
              _Step.profile => _profileStep(context),
              _Step.pin => _pinStep(
                  key: const ValueKey('pin'),
                  title: 'Create your PIN',
                  subtitle: 'Six digits to unlock Cotopole on this phone',
                ),
              _Step.confirm => _pinStep(
                  key: const ValueKey('confirm'),
                  title: 'Confirm your PIN',
                  subtitle: 'Enter the same six digits again',
                ),
            },
          ),
        ),
      ),
    );
  }

  Widget _pinStep({required Key key, required String title, required String subtitle}) {
    return Center(
      key: key,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: PinEntryView(
          title: title,
          subtitle: subtitle,
          header: const IconBadge(icon: Icons.lock_rounded, size: 64, iconSize: 30, circle: true),
          onCompleted: _onPin,
        ),
      ),
    );
  }

  Widget _profileStep(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const ValueKey('profile'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBadge(icon: Icons.badge_rounded, size: 60, iconSize: 28),
            const SizedBox(height: 20),
            Text('Set up your profile', style: t.headlineMedium),
            const SizedBox(height: 8),
            Text(
              "You'll be this device's Organiser: you can create events and add team members.",
              style: t.bodyMedium,
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (v) => Validators.required(v, field: 'Name'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Role / title (optional)',
                prefixIcon: Icon(Icons.work_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Work email (optional)',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 28),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Everything stays on this device, inside Cotopole's private app storage. Nothing is uploaded.",
                      style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Continue',
              onPressed: () {
                if (_form.currentState!.validate()) setState(() => _step = _Step.pin);
              },
            ),
          ].animate(interval: 40.ms).fadeIn(duration: 300.ms).slideY(begin: 0.08),
        ),
      ),
    );
  }
}
