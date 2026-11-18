import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/models/models.dart';
import '../../data/repositories/event_repository.dart';
import 'event_picker_sheet.dart';

/// Create or edit an event (organiser only). Rules from SOP-004 §5.1.
class EventFormScreen extends ConsumerWidget {
  const EventFormScreen({super.key, this.eventId});
  final String? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(sessionProvider)?.isAdmin ?? false;
    Widget body;
    if (!isAdmin) {
      body = const Center(
        child: EmptyState(
          icon: Icons.lock_rounded,
          title: 'Organisers only',
          message: 'Only an organiser can create or edit events.',
        ),
      );
    } else if (eventId == null) {
      body = const _EventForm();
    } else {
      body = ref.watch(eventProvider(eventId!)).when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (e) => e == null ? const Center(child: Text('Event not found')) : _EventForm(event: e),
          );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(eventId == null ? 'New event' : 'Edit event')),
      body: AppBackground(child: body),
    );
  }
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({this.event});
  final Event? event;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.event?.name ?? '');
  late final _location = TextEditingController(text: widget.event?.location ?? '');
  late final _notes = TextEditingController(text: widget.event?.notes ?? '');
  late DateTime _startsAt = widget.event?.startsAt ?? _defaultStart();
  bool _makeCurrent = true;
  bool _saving = false;

  static DateTime _defaultStart() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, n.hour < 9 ? 9 : n.hour + 1);
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startsAt));
    setState(() {
      _startsAt = DateTime(d.year, d.month, d.day, t?.hour ?? _startsAt.hour, t?.minute ?? _startsAt.minute);
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(eventRepoProvider);
    final actor = ref.read(sessionProvider)?.id;
    try {
      if (widget.event == null) {
        final r = await repo.create(
          name: _name.text,
          startsAt: _startsAt,
          location: _location.text,
          notes: _notes.text,
          ownerProfileId: actor,
        );
        if (_makeCurrent) await setCurrentEvent(ref, r.event.id);
        ref.refreshData();
        if (!mounted) return;
        if (r.existed) {
          showAppSnack(
            context,
            'An active "${r.event.name}" already exists on that date — opened it instead.',
            icon: Icons.info_rounded,
            color: AppColors.cyan,
          );
        } else {
          showAppSnack(context, 'Event created');
        }
        final router = GoRouter.of(context);
        router.pop();
        router.push(Routes.event(r.event.id));
      } else {
        await repo.update(
          widget.event!,
          name: _name.text,
          startsAt: _startsAt,
          location: _location.text,
          notes: _notes.text,
          actorId: actor,
        );
        ref.refreshData();
        if (!mounted) return;
        showAppSnack(context, 'Event updated');
        context.pop();
      }
    } on EventConflictException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, e.toString(), icon: Icons.error_rounded, color: AppColors.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, bottom + 28),
          children: [
            GlassCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    maxLength: Validators.eventNameMax,
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.eventName,
                    decoration: const InputDecoration(
                      labelText: 'Event name',
                      hintText: 'e.g. Dental Expo Manila 2026',
                      prefixIcon: Icon(Icons.celebration_rounded),
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Starts at',
                        prefixIcon: Icon(Icons.event_rounded),
                        suffixIcon: Icon(Icons.edit_calendar_rounded),
                      ),
                      child: Text(
                        Fmt.dateTime(_startsAt),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _location,
                    maxLength: Validators.locationMax,
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.location,
                    decoration: const InputDecoration(
                      labelText: 'Location (optional)',
                      prefixIcon: Icon(Icons.place_rounded),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notes,
                    maxLength: Validators.notesMax,
                    minLines: 3,
                    maxLines: 6,
                    validator: Validators.notes,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes for the team (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.event == null) ...[
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: SwitchListTile(
                  value: _makeCurrent,
                  onChanged: (v) => setState(() => _makeCurrent = v),
                  title: const Text('Capture leads here now', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Make this the current event on this device'),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'Events are de-duplicated on name + date: creating one that already exists opens the existing event.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: widget.event == null ? 'Create event' : 'Save changes',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
