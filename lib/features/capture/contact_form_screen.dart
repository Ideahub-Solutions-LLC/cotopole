import 'dart:async';
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
import '../../data/repositories/contact_repository.dart';
import '../../data/services/card_extraction_service.dart';
import '../../data/services/image_store.dart';
import '../events/event_picker_sheet.dart';
import 'photo_slot.dart';

class CaptureFormArgs {
  const CaptureFormArgs({
    this.cardPath,
    this.selfiePath,
    this.extraction,
    this.notes = '',
    this.rating,
    this.fromCapture = false,
  });

  /// True when opened from the Capture screen (which resets on return).
  final bool fromCapture;

  /// Relative paths inside [ImageStore].
  final String? cardPath;
  final String? selfiePath;
  final ExtractionResult? extraction;
  final String notes;
  final LeadRating? rating;
}

/// Review-before-save form. Used for OCR/QR review (closing GAP COR-04 —
/// nothing is saved until a human confirms) and for manual entry
/// (SOP-004 Method C).
class ContactFormScreen extends ConsumerStatefulWidget {
  const ContactFormScreen({super.key, required this.args});
  final CaptureFormArgs args;

  @override
  ConsumerState<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends ConsumerState<ContactFormScreen> {
  final _form = GlobalKey<FormState>();
  late final ImageStore _images = ref.read(imageStoreProvider);

  late final _first = TextEditingController(text: _d.firstName);
  late final _last = TextEditingController(text: _d.lastName);
  late final _phone = TextEditingController(text: _d.phone);
  late final _email = TextEditingController(text: _d.email);
  late final _company = TextEditingController(text: _d.company);
  late final _position = TextEditingController(text: _d.position);
  late final _website = TextEditingController(text: _d.website);
  late final _address = TextEditingController(text: _d.address);
  late final _notes = TextEditingController(text: widget.args.notes);

  late LeadRating? _rating = widget.args.rating;
  late String? _selfiePath = widget.args.selfiePath;
  final _ownedPaths = <String>{};
  bool _saving = false;
  bool _saved = false;
  bool _showMore = false;

  Timer? _debounce;
  MatchResult? _match;

  ContactDraft get _d => widget.args.extraction?.draft ?? const ContactDraft();
  bool get _isScan => widget.args.extraction != null;
  Set<String> get _uncertain => widget.args.extraction?.uncertain ?? const {};

  @override
  void initState() {
    super.initState();
    if (widget.args.cardPath != null) _ownedPaths.add(widget.args.cardPath!);
    if (widget.args.selfiePath != null) _ownedPaths.add(widget.args.selfiePath!);
    _showMore = _d.website.isNotEmpty || _d.address.isNotEmpty;
    _phone.addListener(_scheduleMatch);
    _email.addListener(_scheduleMatch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMatch());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_first, _last, _phone, _email, _company, _position, _website, _address, _notes]) {
      c.dispose();
    }
    // Abandoned capture: don't leave orphaned photos on the device.
    if (!_saved) {
      for (final p in _ownedPaths) {
        _images.delete(p);
      }
    }
    super.dispose();
  }

  ContactDraft _draft() => ContactDraft(
        firstName: _first.text,
        lastName: _last.text,
        phone: _phone.text,
        email: _email.text,
        company: _company.text,
        position: _position.text,
        website: _website.text,
        address: _address.text,
      );

  void _scheduleMatch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _checkMatch);
  }

  Future<void> _checkMatch() async {
    if (!mounted) return;
    final m = await ref.read(contactRepoProvider).findMatch(_draft());
    if (mounted) setState(() => _match = m);
  }

  CaptureMethod get _method => widget.args.extraction?.method ?? CaptureMethod.manual;

  Future<void> _save({String? resolveTo, bool forceNew = false}) async {
    if (!_form.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    final contactErr = Validators.phoneOrEmail(_phone.text, _email.text);
    if (contactErr != null) {
      showAppSnack(context, contactErr, icon: Icons.error_rounded, color: AppColors.danger);
      return;
    }
    var event = await ref.read(currentEventProvider.future);
    if (event == null && mounted) event = await showEventPicker(context, ref);
    if (event == null || !mounted) return;

    final session = ref.read(sessionProvider);
    setState(() => _saving = true);
    try {
      final edited = _isScan && !_sameAs(_d, _draft());
      final result = await ref.read(contactRepoProvider).capture(
            CaptureRequest(
              eventId: event.id,
              draft: _draft(),
              method: edited && _method != CaptureMethod.manual ? CaptureMethod.mixed : _method,
              notes: _notes.text,
              rating: _rating,
              businessCardPath: widget.args.cardPath,
              selfiePath: _selfiePath,
              ocrRawText: widget.args.extraction?.rawText,
              capturedByProfileId: session?.id,
              resolveToContactId: resolveTo,
              forceNewContact: forceNew,
            ),
          );
      _saved = true;
      ref.refreshData();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _saving = false);
      await _showResult(result, event.name);
    } on AmbiguousDuplicateException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await _handleAmbiguous(e);
    } on ArchivedEventException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, e.toString(), icon: Icons.archive_rounded, color: AppColors.warning);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, 'Could not save: $e', icon: Icons.error_rounded, color: AppColors.danger);
    }
  }

  bool _sameAs(ContactDraft a, ContactDraft b) =>
      a.firstName.trim() == b.firstName.trim() &&
      a.lastName.trim() == b.lastName.trim() &&
      a.phone.trim() == b.phone.trim() &&
      a.email.trim() == b.email.trim() &&
      a.company.trim() == b.company.trim() &&
      a.position.trim() == b.position.trim();

  Future<void> _handleAmbiguous(AmbiguousDuplicateException e) async {
    final isAdmin = ref.read(sessionProvider)?.isAdmin ?? false;
    if (!isAdmin) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 36),
          title: const Text('Ambiguous duplicate'),
          content: Text(
            '${e.candidates.length} existing leads share this ${e.onPhone ? 'phone number' : 'email'}. '
            "Nothing was saved. Flag it to your organiser — don't edit the number to force it through.",
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))],
        ),
      );
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _AmbiguousSheet(error: e, images: _images),
    );
    if (choice == null) return;
    if (choice == _AmbiguousSheet.createNew) {
      await _save(forceNew: true);
    } else {
      await _save(resolveTo: choice);
    }
  }

  Future<void> _showResult(CaptureResult r, String eventName) async {
    final router = GoRouter.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _ResultSheet(result: r, eventName: eventName),
    );
    if (!mounted) return;
    switch (action) {
      case 'another':
        router.pop(true);
        if (!widget.args.fromCapture) router.push(Routes.capture);
      case 'view':
        router.go(Routes.leads);
        router.push(Routes.lead(r.contact.id));
      default:
        router.go(Routes.home);
    }
  }

  Future<void> _pickSelfie() async {
    final picked = await pickPhoto(context, selfie: true);
    if (picked == null) return;
    final rel = await _images.importFile(picked, kind: 'selfie');
    if (!mounted) return;
    setState(() {
      if (_selfiePath != null && _ownedPaths.contains(_selfiePath)) {
        _images.delete(_selfiePath);
        _ownedPaths.remove(_selfiePath);
      }
      _selfiePath = rel;
      _ownedPaths.add(rel);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.args.extraction;
    final cardFile = _images.resolve(widget.args.cardPath);
    final selfieFile = _images.resolve(_selfiePath);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(_isScan ? 'Review details' : 'New lead'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: AppBackground(
          child: SafeArea(
            bottom: false,
            child: Form(
              key: _form,
              child: ListView(
                padding: EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, bottom + 28),
                children: [
                  if (ext != null) _ExtractionBanner(extraction: ext, cardFile: cardFile),
                  if (ext == null) const _EventLine(),
                  const SizedBox(height: 12),
                  _MatchBanner(match: _match, images: _images),
                  GlassCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                _first,
                                'First name',
                                Icons.person_rounded,
                                key: 'name',
                                validator: (v) => Validators.required(v, field: 'First name'),
                                caps: TextCapitalization.words,
                                autofill: AutofillHints.givenName,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _field(
                                _last,
                                'Last name',
                                null,
                                key: 'name',
                                validator: (v) => Validators.required(v, field: 'Last name'),
                                caps: TextCapitalization.words,
                                autofill: AutofillHints.familyName,
                              ),
                            ),
                          ],
                        ),
                        _gap,
                        _field(
                          _phone,
                          'Phone',
                          Icons.phone_rounded,
                          key: 'phone',
                          keyboard: TextInputType.phone,
                          validator: Validators.phone,
                          autofill: AutofillHints.telephoneNumber,
                        ),
                        _gap,
                        _field(
                          _email,
                          'Email',
                          Icons.alternate_email_rounded,
                          key: 'email',
                          keyboard: TextInputType.emailAddress,
                          validator: Validators.email,
                          autofill: AutofillHints.email,
                        ),
                        _gap,
                        _field(
                          _company,
                          'Company',
                          Icons.business_rounded,
                          key: 'company',
                          caps: TextCapitalization.words,
                        ),
                        _gap,
                        _field(
                          _position,
                          'Position',
                          Icons.work_outline_rounded,
                          key: 'position',
                          caps: TextCapitalization.words,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          child: _showMore
                              ? Column(
                                  children: [
                                    _gap,
                                    _field(
                                      _website,
                                      'Website',
                                      Icons.language_rounded,
                                      keyboard: TextInputType.url,
                                    ),
                                    _gap,
                                    _field(
                                      _address,
                                      'Address',
                                      Icons.place_outlined,
                                      caps: TextCapitalization.words,
                                      maxLines: 2,
                                    ),
                                  ],
                                )
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => setState(() => _showMore = true),
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Website & address'),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader('Conversation context'),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _notes,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: Validators.notesMax,
                          validator: Validators.notes,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Runs ops for 3 clinics. Pain point: double-booking. Wants pricing by Friday.',
                            hintMaxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keep it to the business conversation — this is stored as personal data about them.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        RatingSelector(value: _rating, onChanged: (r) => setState(() => _rating = r)),
                      ],
                    ),
                  ),
                  const SectionHeader('Client photo'),
                  PhotoSlot(
                    title: 'Client selfie',
                    subtitle: 'Optional — helps you remember the face',
                    accent: AppColors.teal,
                    illustration: Icons.face_retouching_natural_rounded,
                    file: selfieFile,
                    height: 120,
                    onTap: _pickSelfie,
                    onClear: _selfiePath == null
                        ? null
                        : () => setState(() {
                              if (_ownedPaths.contains(_selfiePath)) {
                                _images.delete(_selfiePath);
                                _ownedPaths.remove(_selfiePath);
                              }
                              _selfiePath = null;
                            }),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: _isScan ? 'Confirm & save' : 'Save lead',
                    icon: Icons.check_rounded,
                    loading: _saving,
                    onPressed: () => _save(),
                  ),
                ].animate(interval: 40.ms).fadeIn(duration: 280.ms).slideY(begin: 0.05),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _gap = SizedBox(height: 12);

  Widget _field(
    TextEditingController c,
    String label,
    IconData? icon, {
    String? key,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.none,
    String? autofill,
    int maxLines = 1,
  }) {
    final flagged = key != null && _uncertain.contains(key);
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      textCapitalization: caps,
      textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      validator: validator,
      maxLines: maxLines,
      autofillHints: autofill == null ? null : [autofill],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        helperText: flagged ? 'Please double-check' : null,
        helperStyle: const TextStyle(color: AppColors.warning),
        enabledBorder: flagged
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: const BorderSide(color: AppColors.warning),
              )
            : null,
      ),
    );
  }
}

class _EventLine extends ConsumerWidget {
  const _EventLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(currentEventProvider).dataOrNull;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: () => showEventPicker(context, ref),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event == null ? 'Choose the event you are at' : 'At ${event.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Text('Change', style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ExtractionBanner extends StatelessWidget {
  const _ExtractionBanner({required this.extraction, required this.cardFile});
  final ExtractionResult extraction;
  final File? cardFile;

  @override
  Widget build(BuildContext context) {
    final cardFile = this.cardFile;
    final (label, color, icon) = switch (extraction.method) {
      CaptureMethod.qr => ('Read from QR / vCard — exact', AppColors.success, Icons.qr_code_2_rounded),
      CaptureMethod.mixed => ('QR + on-device text recognition', AppColors.cyan, Icons.auto_awesome_rounded),
      _ => ('Read on-device — please check', AppColors.warning, Icons.document_scanner_rounded),
    };
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (cardFile != null)
            GestureDetector(
              onTap: () => PhotoViewerPage.open(context, cardFile, 'Business card'),
              child: Hero(
                tag: cardFile.path,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(cardFile, width: 92, height: 58, fit: BoxFit.cover, cacheWidth: 300),
                ),
              ),
            ),
          if (cardFile != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(label: extraction.method.label, color: color, icon: icon, dense: true),
                const SizedBox(height: 6),
                Text(
                  extraction.error ?? label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: extraction.error != null ? AppColors.warning : AppColors.textSecondary,
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

class _MatchBanner extends StatelessWidget {
  const _MatchBanner({required this.match, required this.images});
  final MatchResult? match;
  final ImageStore images;

  @override
  Widget build(BuildContext context) {
    final m = match;
    Widget? child;
    if (m is SingleMatch) {
      child = GlassCard(
        key: ValueKey('single-${m.contact.id}'),
        borderColor: AppColors.cyan.withValues(alpha: 0.6),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ContactAvatar(name: m.contact.fullName, photo: images.resolve(m.contact.photoPath), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Returning contact · ${m.resolution.label.toLowerCase()}',
                    style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  Text(
                    '${m.contact.fullName} — this meeting will be added to their history.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (m is AmbiguousMatch) {
      child = GlassCard(
        key: const ValueKey('ambiguous'),
        borderColor: AppColors.warning.withValues(alpha: 0.7),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${m.candidates.length} leads share this ${m.onPhone ? 'phone' : 'email'} — '
                'an organiser will need to resolve it.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child == null
          ? const SizedBox.shrink()
          : Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
    );
  }
}

class _AmbiguousSheet extends StatelessWidget {
  const _AmbiguousSheet({required this.error, required this.images});
  final AmbiguousDuplicateException error;
  final ImageStore images;

  static const createNew = '__new__';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resolve duplicate', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'These leads share the same ${error.onPhone ? 'phone number' : 'email'}. '
              'Choose who you met, or keep this as a separate person.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in error.candidates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () => Navigator.pop(context, c.id),
                        child: Row(
                          children: [
                            ContactAvatar(name: c.fullName, photo: images.resolve(c.photoPath), size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    [c.company, c.email, c.phone].whereType<String>().join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Text(
                              'This one',
                              style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinePillButton(
              label: 'Save as a new person',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: () => Navigator.pop(context, createNew),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.result, required this.eventName});
  final CaptureResult result;
  final String eventName;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final (title, body, color) = switch (r.resolution) {
      DuplicateResolution.newContact => (
          'New lead saved',
          '${r.contact.fullName} was added to $eventName.',
          AppColors.success,
        ),
      DuplicateResolution.phoneMatch || DuplicateResolution.emailMatch => (
          'Welcome back, ${r.contact.firstName}',
          'Matched an existing lead by ${r.resolution == DuplicateResolution.phoneMatch ? 'phone' : 'email'} '
              '— this meeting was added to their history.',
          AppColors.cyan,
        ),
      DuplicateResolution.adminResolved => (
          'Resolved & saved',
          'The duplicate was resolved and the meeting recorded.',
          AppColors.violet,
        ),
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 30)],
              ),
              child: Icon(Icons.check_rounded, color: color, size: 46),
            )
                .animate()
                .scale(begin: const Offset(0.4, 0.4), curve: Curves.elasticOut, duration: 700.ms)
                .fadeIn(),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(body, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            if (r.alreadyMetAtEvent) ...[
              const SizedBox(height: 10),
              const StatusPill(
                label: "You've met them at this event before",
                color: AppColors.warning,
                icon: Icons.info_outline_rounded,
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: 'Capture another',
              icon: Icons.qr_code_scanner_rounded,
              onPressed: () => Navigator.pop(context, 'another'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinePillButton(
                    label: 'View lead',
                    onPressed: () => Navigator.pop(context, 'view'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinePillButton(label: 'Done', onPressed: () => Navigator.pop(context, 'done')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
