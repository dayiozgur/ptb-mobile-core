import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/user/user_profile.dart';
import '../../widgets/feedback/app_confirm_dialog.dart';

String _tr(String key, {Map<String, dynamic>? params}) =>
    sl<LocalizationService>().translate(key, params: params);

/// Profil düzenleme — ad/soyad/kullanıcı adı/telefon/bio.
///
/// `ProfileService.updateProfile` yalnızca yazılabilir kolonları yazar
/// (`toUpdateJson`: full_name/first_name/last_name/phone/bio/…). full_name
/// ad+soyad'dan türetilir (web ile tutarlı). Başarıda `pop(true)`.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _username;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstName = TextEditingController(text: p.firstName ?? '');
    _lastName = TextEditingController(text: p.lastName ?? '');
    _username = TextEditingController(text: p.username ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _bio = TextEditingController(text: p.bio ?? '');
    for (final c in [_firstName, _lastName, _username, _phone, _bio]) {
      c.addListener(_recomputeDirty);
    }
  }

  /// Başlangıç değerlerinden farklı bir alan var mı (çıkışta onay için).
  void _recomputeDirty() {
    final p = widget.profile;
    final d = _firstName.text != (p.firstName ?? '') ||
        _lastName.text != (p.lastName ?? '') ||
        _username.text != (p.username ?? '') ||
        _phone.text != (p.phone ?? '') ||
        _bio.text != (p.bio ?? '');
    if (d != _dirty && mounted) setState(() => _dirty = d);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final first = _firstName.text.trim();
      final last = _lastName.text.trim();
      final fullName = '$first $last'.trim();
      final updated = widget.profile.copyWith(
        firstName: first,
        lastName: last,
        fullName: fullName.isEmpty ? null : fullName,
        username: _username.text.trim().isEmpty ? null : _username.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      );
      await profileService.updateProfile(updated);
      await profileService.invalidateCache(widget.profile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_tr('profile.updated'))),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_tr('profile.update_failed')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      hasChanges: _dirty && !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_tr('profile.edit')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              _field(
                  _firstName, _tr('profile.first_name'), Icons.person_outline,
                  validator: _required),
              _field(_lastName, _tr('profile.last_name'), Icons.person_outline,
                  validator: _required),
              _field(_username, _tr('profile.username'), Icons.alternate_email,
                  validator: (v) {
                final t = (v ?? '').trim();
                if (t.isNotEmpty && t.length < 3) {
                  return _tr('validation.min_length', params: {'count': 3});
                }
                return null;
              }),
              _field(_phone, _tr('profile.phone'), Icons.phone_outlined,
                  keyboard: TextInputType.phone),
              _field(_bio, _tr('profile.bio'), Icons.notes_outlined,
                  maxLines: 4, hint: _tr('profile.bio_hint')),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_tr('common.save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? _tr('error.required_field') : null;

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: c,
        validator: validator,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
