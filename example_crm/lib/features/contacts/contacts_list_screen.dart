import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'contact_detail_screen.dart';
import 'contacts_service.dart';

/// CRM **Kişiler** — ara / listele / hızlı-ekle. `public.contacts` (tenant-scoped).
class ContactsListScreen extends StatefulWidget {
  const ContactsListScreen({super.key});

  @override
  State<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends State<ContactsListScreen> {
  final _svc = ContactsService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load([String? query]) async {
    setState(() => _loading = true);
    final list = await _svc.list(query: query);
    if (mounted) {
      setState(() {
        _contacts = list;
        _loading = false;
      });
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(v));
  }

  Future<void> _quickAdd() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _QuickAddSheet(),
    );
    if (created == true) _load(_searchCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kişiler',
      onBack: () => context.pop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: () => _load())],
      floatingActionButton: FloatingActionButton(
        onPressed: _quickAdd,
        child: const Icon(Icons.person_add_alt_1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Ara: ad, e-posta, telefon…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(_searchCtrl.text),
              child: _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_contacts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: AppEmptyState(
                icon: Icons.people_outline, title: 'Kişi bulunamadı'),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      itemCount: _contacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final c = _contacts[i];
        return AppCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ContactDetailScreen(contactId: c.id))),
            child: Padding(
              padding: AppSpacing.cardInsets,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      (c.displayName.isNotEmpty
                              ? c.displayName.characters.first
                              : '?')
                          .toUpperCase(),
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.displayName, style: AppTypography.subhead),
                        if ((c.title ?? '').isNotEmpty || (c.email ?? '').isNotEmpty)
                          Text(
                            [c.title, c.email]
                                .where((s) => (s ?? '').isNotEmpty)
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption1.copyWith(
                                color: AppColors.secondaryLabel(context)),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hızlı kişi ekleme alt-sayfası.
class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _svc = ContactsService();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final id = await _svc.create(
      firstName: _first.text,
      lastName: _last.text,
      email: _email.text,
      phone: _phone.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kişi eklenemedi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni Kişi', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.md),
          TextField(
              controller: _first,
              decoration: const InputDecoration(
                  labelText: 'Ad *', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _last,
              decoration: const InputDecoration(
                  labelText: 'Soyad', isDense: true, border: OutlineInputBorder())),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'E-posta',
                  isDense: true,
                  border: OutlineInputBorder())),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Telefon',
                  isDense: true,
                  border: OutlineInputBorder())),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
