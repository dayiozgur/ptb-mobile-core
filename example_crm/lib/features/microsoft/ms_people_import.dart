import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import '../contacts/contacts_service.dart';

/// "Suggest from Microsoft" sheet — lists the connected user's relevance-ranked
/// people (Graph /me/people, People.Read) and adds the ones missing from the CRM
/// as contacts. Dedupes against [existingEmails]. Returns true if anything was
/// imported (so the caller can refresh).
Future<bool> showMsPeopleImport(
  BuildContext context, {
  required ContactsService contactsService,
  required Set<String> existingEmails,
}) async {
  final svc = sl<MicrosoftIntegrationService>();
  final connected = await svc.getConnected();
  if (!context.mounted) return false;
  if (connected == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(crmT('integrations.ms.not_connected', 'Microsoft hesabı bağlı değil')),
    ));
    return false;
  }
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _PeopleImportSheet(
        contactsService: contactsService,
        existingEmails: existingEmails.map((e) => e.toLowerCase()).toSet(),
      ),
    ),
  );
  return result ?? false;
}

class _Person {
  final String name;
  final String email;
  final String? title;
  final String? company;
  final String? first;
  final String? last;
  bool existing;
  bool added = false;
  bool adding = false;
  _Person(this.name, this.email, this.title, this.company, this.first, this.last,
      {this.existing = false});
}

class _PeopleImportSheet extends StatefulWidget {
  final ContactsService contactsService;
  final Set<String> existingEmails;
  const _PeopleImportSheet({required this.contactsService, required this.existingEmails});
  @override
  State<_PeopleImportSheet> createState() => _PeopleImportSheetState();
}

class _PeopleImportSheetState extends State<_PeopleImportSheet> {
  MicrosoftIntegrationService get _svc => sl<MicrosoftIntegrationService>();
  List<_Person> _people = const [];
  bool _loading = true;
  bool _importedAny = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await _svc.graphCall('GET', '/me/people', query: {
      '\$top': '25',
      '\$select': 'displayName,givenName,surname,scoredEmailAddresses,jobTitle,companyName,personType',
    });
    if (!mounted) return;
    if (res == null || !res.ok || res.data is! Map) {
      setState(() {
        _people = const [];
        _loading = false;
      });
      return;
    }
    final value = (res.data['value'] as List?) ?? const [];
    final mapped = <_Person>[];
    for (final raw in value) {
      final p = _mapPerson(raw as Map);
      if (p != null) mapped.add(p);
    }
    setState(() {
      _people = mapped;
      _loading = false;
    });
  }

  _Person? _mapPerson(Map p) {
    final emails = (p['scoredEmailAddresses'] as List?) ?? const [];
    String email = '';
    for (final e in emails) {
      final a = (e is Map) ? e['address'] as String? : null;
      if (a != null && a.isNotEmpty) {
        email = a;
        break;
      }
    }
    if (email.isEmpty) return null;
    final cls = (p['personType'] is Map) ? p['personType']['class'] as String? : 'Person';
    if ((cls ?? 'Person') != 'Person') return null;
    String? first = p['givenName'] as String?;
    String? last = p['surname'] as String?;
    final display = (p['displayName'] as String?) ??
        [first, last].where((e) => e != null && e.isNotEmpty).join(' ');
    if ((first == null || first.isEmpty) && (last == null || last.isEmpty) && display.isNotEmpty) {
      final parts = display.trim().split(RegExp(r'\s+'));
      first = parts.isNotEmpty ? parts.first : display;
      last = parts.length > 1 ? parts.sublist(1).join(' ') : null;
    }
    return _Person(
      display.isEmpty ? email : display,
      email,
      p['jobTitle'] as String?,
      p['companyName'] as String?,
      first,
      last,
      existing: widget.existingEmails.contains(email.toLowerCase()),
    );
  }

  Future<void> _add(_Person p) async {
    setState(() => p.adding = true);
    final id = await widget.contactsService.create(
      firstName: (p.first == null || p.first!.isEmpty) ? p.name : p.first!,
      lastName: p.last,
      email: p.email,
      title: p.title,
      company: p.company,
    );
    if (!mounted) return;
    setState(() {
      p.adding = false;
      p.added = id != null;
      if (id != null) _importedAny = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(id != null
          ? crmT('crm.people.add_ok', '{{name}} kişi olarak eklendi.').replaceAll('{{name}}', p.name)
          : crmT('crm.people.load_failed', 'Eklenemedi.')),
      backgroundColor: id != null ? null : Colors.red.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(crmT('crm.people.hint',
              'Microsoft hesabınızda sık çalıştığınız kişiler. CRM\'de olmayanları ekleyin.'),
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_people.isEmpty
                  ? Center(child: Text(crmT('crm.people.empty', 'Önerilen kişi bulunamadı.')))
                  : ListView.separated(
                      itemCount: _people.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = _people[i];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text(
                            [p.email, p.title, p.company].where((e) => e != null && e.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: p.existing
                              ? Text(crmT('crm.people.already', 'Zaten kayıtlı'),
                                  style: Theme.of(context).textTheme.bodySmall)
                              : (p.added
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : (p.adding
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : TextButton(onPressed: () => _add(p), child: Text(crmT('crm.people.add', 'Ekle'))))),
                        );
                      },
                    )),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              onPressed: () => Navigator.pop(context, _importedAny),
              child: Text(crmT('common.close', 'Kapat')),
            ),
          ),
        ),
      ],
    );
  }
}
