import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/models/models.dart';
import '../events/current_event_card.dart';
import '../events/event_picker_sheet.dart';
import 'contact_form_screen.dart';
import 'photo_slot.dart';
import 'scanning_overlay.dart';

/// Quick Capture (SOP-004 Method A/B): card photo + optional client selfie +
/// context note. The card is read on-device, then shown for review.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  String? _cardPath;
  String? _selfiePath;
  final _notes = TextEditingController();
  LeadRating? _rating;
  bool _scanning = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _cardPath = null;
      _selfiePath = null;
      _rating = null;
      _notes.clear();
    });
  }

  Future<bool> _ensureEvent() async {
    final event = await ref.read(currentEventProvider.future);
    if (event != null) return true;
    if (!mounted) return false;
    final picked = await showEventPicker(context, ref);
    return picked != null;
  }

  Future<void> _submit() async {
    if (_cardPath == null) return;
    if (Validators.notes(_notes.text) != null) return;
    if (!await _ensureEvent()) return;

    setState(() => _scanning = true);
    final images = ref.read(imageStoreProvider);
    final extractor = ref.read(extractionServiceProvider);
    final started = DateTime.now();
    try {
      final extraction = await extractor.extract(_cardPath!);
      final card = await images.importFile(_cardPath!, kind: 'card');
      final selfie = _selfiePath == null ? null : await images.importFile(_selfiePath!, kind: 'selfie');
      // Keep the scan animation on screen long enough to read as feedback.
      final elapsed = DateTime.now().difference(started);
      if (elapsed < const Duration(milliseconds: 1400)) {
        await Future<void>.delayed(const Duration(milliseconds: 1400) - elapsed);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _scanning = false);
      final saved = await context.push<bool>(
        Routes.review,
        extra: CaptureFormArgs(
          cardPath: card,
          selfiePath: selfie,
          extraction: extraction,
          notes: _notes.text,
          rating: _rating,
          fromCapture: true,
        ),
      );
      if (saved == true && mounted) _reset();
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      showAppSnack(context, 'Could not process the photo: $e', icon: Icons.error_rounded, color: AppColors.danger);
    }
  }

  Future<void> _manual() async {
    if (!await _ensureEvent()) return;
    if (!mounted) return;
    final images = ref.read(imageStoreProvider);
    final selfie = _selfiePath == null ? null : await images.importFile(_selfiePath!, kind: 'selfie');
    if (!mounted) return;
    final saved = await context.push<bool>(
      Routes.review,
      extra: CaptureFormArgs(selfiePath: selfie, notes: _notes.text, rating: _rating, fromCapture: true),
    );
    if (saved == true && mounted) _reset();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: !_scanning,
      child: Scaffold(
        body: AppBackground(
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _TopBar(onClose: () => context.pop()),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, bottom + 24),
                        children: [
                          const CurrentEventCard(compact: true),
                          const SizedBox(height: 14),
                          _SlotSection(
                            icon: Icons.badge_outlined,
                            iconColor: AppColors.primary,
                            title: 'Capture Business Card',
                            trailing: const _AiBadge(),
                            child: PhotoSlot(
                              title: 'Business card',
                              subtitle: 'Tap to upload business card',
                              accent: AppColors.primary,
                              illustration: Icons.contact_mail_rounded,
                              file: _cardPath == null ? null : File(_cardPath!),
                              onClear: () => setState(() => _cardPath = null),
                              onTap: () async {
                                final p = await pickPhoto(context, selfie: false);
                                if (p != null) setState(() => _cardPath = p);
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SlotSection(
                            icon: Icons.person_outline_rounded,
                            iconColor: AppColors.teal,
                            title: 'Capture Selfie',
                            trailing: const Text('Optional', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            child: PhotoSlot(
                              title: 'Client selfie',
                              subtitle: 'Tap to take or upload selfie',
                              accent: AppColors.teal,
                              illustration: Icons.face_retouching_natural_rounded,
                              file: _selfiePath == null ? null : File(_selfiePath!),
                              onClear: () => setState(() => _selfiePath = null),
                              onTap: () async {
                                final p = await pickPhoto(context, selfie: true);
                                if (p != null) setState(() => _selfiePath = p);
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _notes,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: Validators.notesMax,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Notes (optional) — what did you talk about?',
                              counterText: '',
                              prefixIcon: Icon(Icons.auto_awesome_rounded, color: AppColors.violet),
                            ),
                          ),
                          const SizedBox(height: 14),
                          RatingSelector(value: _rating, onChanged: (r) => setState(() => _rating = r)),
                          const SizedBox(height: 20),
                          GradientButton(
                            label: 'Submit',
                            onPressed: _cardPath == null ? null : _submit,
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton.icon(
                              onPressed: _manual,
                              icon: const Icon(Icons.keyboard_rounded, size: 18),
                              label: const Text('No card? Type the details instead'),
                            ),
                          ),
                        ].animate(interval: 50.ms).fadeIn(duration: 300.ms).slideY(begin: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
              if (_scanning)
                Positioned.fill(
                  child: ScanningOverlay(imagePath: _cardPath!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
          const Expanded(child: Center(child: CotopoleLogo(height: 34))),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
              color: AppColors.primary.withValues(alpha: 0.12),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 14)],
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => AppColors.primaryGradient.createShader(r),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
          SizedBox(width: 4),
          Text('AI', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}
