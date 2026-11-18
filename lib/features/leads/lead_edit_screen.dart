import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/models/models.dart';

class LeadEditScreen extends ConsumerWidget {
  const LeadEditScreen({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contactProvider(contactId));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Edit lead')),
      body: AppBackground(
        child: c.when(
            skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (contact) => contact == null
              ? const Center(child: Text('Lead not found'))
              : _EditForm(contact: contact),
        ),
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.contact});
  final Contact contact;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _form = GlobalKey<FormState>();
  late final ContactDraft _d = widget.contact.toDraft();
  late final _first = TextEditingController(text: _d.firstName);
  late final _last = TextEditingController(text: _d.lastName);
  late final _phone = TextEditingController(text: _d.phone);
  late final _email = TextEditingController(text: _d.email);
  late final _company = TextEditingController(text: _d.company);
  late final _position = TextEditingController(text: _d.position);
  late final _website = TextEditingController(text: _d.website);
  late final _address = TextEditingController(text: _d.address);
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _phone, _email, _company, _position, _website, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final err = Validators.phoneOrEmail(_phone.text, _email.text);
    if (err != null) {
      showAppSnack(context, err, icon: Icons.error_rounded, color: AppColors.danger);
      return;
    }
    setState(() => _saving = true);
    await ref.read(contactRepoProvider).update(
          widget.contact.id,
          ContactDraft(
            firstName: _first.text,
            lastName: _last.text,
            phone: _phone.text,
            email: _email.text,
            company: _company.text,
            position: _position.text,
            website: _website.text,
            address: _address.text,
          ),
          actorId: ref.read(sessionProvider)?.id,
        );
    ref.refreshData();
    if (!mounted) return;
    showAppSnack(context, 'Lead updated');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget field(
      TextEditingController c,
      String label,
      IconData icon, {
      String? Function(String?)? validator,
      TextInputType? keyboard,
      TextCapitalization caps = TextCapitalization.none,
    }) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: c,
            keyboardType: keyboard,
            textCapitalization: caps,
            textInputAction: TextInputAction.next,
            validator: validator,
            decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          ),
        );

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
                  field(_first, 'First name', Icons.person_rounded,
                      caps: TextCapitalization.words,
                      validator: (v) => Validators.required(v, field: 'First name')),
                  field(_last, 'Last name', Icons.person_outline_rounded,
                      caps: TextCapitalization.words,
                      validator: (v) => Validators.required(v, field: 'Last name')),
                  field(_phone, 'Phone', Icons.phone_rounded,
                      keyboard: TextInputType.phone, validator: Validators.phone),
                  field(_email, 'Email', Icons.alternate_email_rounded,
                      keyboard: TextInputType.emailAddress, validator: Validators.email),
                  field(_company, 'Company', Icons.business_rounded, caps: TextCapitalization.words),
                  field(_position, 'Position', Icons.work_outline_rounded, caps: TextCapitalization.words),
                  field(_website, 'Website', Icons.language_rounded, keyboard: TextInputType.url),
                  field(_address, 'Address', Icons.place_outlined, caps: TextCapitalization.words),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Changing the phone or email changes how future captures match this person.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            GradientButton(label: 'Save changes', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
