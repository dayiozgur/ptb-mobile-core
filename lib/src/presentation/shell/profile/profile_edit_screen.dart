import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/user/user_profile.dart';

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

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstName = TextEditingController(text: p.firstName ?? '');
    _lastName = TextEditingController(text: p.lastName ?? '');
    _username = TextEditingController(text: p.username ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _bio = TextEditingController(text: p.bio ?? '');
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
          const SnackBar(content: Text('Profil güncellendi')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil güncellenemedi'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
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
            _field(_firstName, 'Ad', Icons.person_outline,
                validator: _required),
            _field(_lastName, 'Soyad', Icons.person_outline,
                validator: _required),
            _field(_username, 'Kullanıcı adı', Icons.alternate_email,
                validator: (v) {
              final t = (v ?? '').trim();
              if (t.isNotEmpty && t.length < 3) return 'En az 3 karakter';
              return null;
            }),
            _field(_phone, 'Telefon', Icons.phone_outlined,
                keyboard: TextInputType.phone),
            _field(_bio, 'Hakkımda', Icons.notes_outlined,
                maxLines: 4, hint: 'Kısa bir tanıtım (headline)'),
            const SizedBox(height: 24),
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
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null;

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
