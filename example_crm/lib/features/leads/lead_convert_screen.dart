import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import '../pipeline/crm_stage_service.dart';
import 'lead_convert_service.dart';

/// Opens the convert wizard for [leadId]; [onDone] runs when it closes.
Future<void> openLeadConvert(BuildContext context, String leadId,
    {Future<void> Function()? onDone}) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LeadConvertScreen(leadId: leadId)));
  if (onDone != null) await onDone();
}

/// **Lead → deal convert wizard** — web `LeadConvertWizardComponent`
/// (`/crm/leads/:id/convert`) parity, 4 linear steps:
///  1. review the lead (blocked when it is already in a final status);
///  2. company & contact: pick a match, create a new one, or none;
///  3. deal details: amount (required), stage (open deal stages), owner,
///     expected close — prefilled from the lead;
///  4. confirm → [LeadConvertService.convert]; on success the new deal opens.
class LeadConvertScreen extends StatefulWidget {
  const LeadConvertScreen({
    super.key,
    required this.leadId,
    this.service,
    this.stageService,
    this.onOpenDeal,
  });

  final String leadId;
  final LeadConvertService? service;
  final CrmStageService? stageService;

  /// Test seam: opens the created deal (default: replace with its detail).
  final void Function(BuildContext context, String dealId)? onOpenDeal;

  @override
  State<LeadConvertScreen> createState() => _LeadConvertScreenState();
}

enum _Pick { existing, create, none }

class _LeadConvertScreenState extends State<LeadConvertScreen> {
  late final LeadConvertService _svc = widget.service ?? LeadConvertService();
  late final CrmStageService _stages = widget.stageService ?? CrmStageService();

  bool _loading = true;
  bool _loadError = false;
  bool _converting = false;
  bool _searching = false;
  int _step = 0;

  ConvertEntity? _lead;
  List<CrmStage> _leadStages = const [];
  List<CrmStage> _dealStages = const [];
  List<MemberOption> _members = const [];
  List<CompanyMatch> _companies = const [];
  List<ContactMatch> _contacts = const [];

  // Step 2
  final _companySearch = TextEditingController();
  final _companyName = TextEditingController();
  _Pick _companyPick = _Pick.none;
  String? _companyId;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  _Pick _contactPick = _Pick.none;
  String? _contactId;

  // Step 3
  final _amount = TextEditingController();
  String? _stage;
  String? _ownerId;
  DateTime? _expectedClose;
  bool _dealAttempted = false;
  bool _partiesAttempted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _companySearch,
      _companyName,
      _firstName,
      _lastName,
      _email,
      _phone,
      _amount
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isTerminal {
    final lead = _lead;
    if (lead == null) return false;
    if (lead.status == LeadConvertLogic.convertedStatus) return true;
    return _leadStages.any((s) => s.code == lead.status && s.isFinal);
  }

  Future<void> _load() async {
    try {
      final lead = await _svc.backend.loadEntity(widget.leadId);
      if (lead == null) {
        setState(() {
          _loadError = true;
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        _stages.loadStages('lead'),
        _stages.loadStages('deal'),
        _svc.backend.members().catchError((_) => const <MemberOption>[]),
      ]);
      final v = lead.values;
      final company = LeadConvertLogic.readLookup(v['company']);
      final dealStages = (results[1] as List<CrmStage>).where((s) => !s.isFinal).toList();
      final members = results[2] as List<MemberOption>;
      final owner = LeadConvertLogic.readLookup(v['owner']).id ?? lead.assignedTo;
      final amount = LeadConvertLogic.toNumber(v['est_value']);

      _lead = lead;
      _leadStages = results[0] as List<CrmStage>;
      _dealStages = dealStages;
      _members = members;
      _amount.text = amount == null ? '' : _fmtNum(amount);
      _stage = (dealStages.where((s) => s.isInitial).firstOrNull ??
              dealStages.firstOrNull)
          ?.code;
      _ownerId = owner != null && members.any((m) => m.id == owner) ? owner : null;
      final due = lead.dueDate;
      _expectedClose = due == null ? null : DateTime.tryParse(due);

      final term = company.name ??
          (lead.subject ?? '').split(' - ').first.trim();
      _companySearch.text = term;
      await _searchCompanies(
          pinned: company.id == null
              ? null
              : CompanyMatch(id: company.id!, name: company.name ?? company.id!));
      await _loadContacts(v);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      Logger.error('lead convert load (${widget.leadId}) hata', e);
      if (!mounted) return;
      setState(() {
        _loadError = true;
        _loading = false;
      });
    }
  }

  static String _fmtNum(num n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  Future<void> _searchCompanies({CompanyMatch? pinned}) async {
    setState(() => _searching = true);
    try {
      final found = await _svc.findCompanies(_companySearch.text);
      final keep = pinned ??
          _companies.where((m) => m.id == _companyId).firstOrNull;
      _companies = keep == null
          ? found
          : [keep, ...found.where((f) => f.id != keep.id)];
    } catch (e) {
      Logger.error('lead convert company search hata', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                crmT('crm.lead_convert.search_error', 'Firmalar aranamadı.'))));
      }
    } finally {
      final validExisting = _companyPick == _Pick.existing &&
          _companies.any((m) => m.id == _companyId);
      if (!validExisting && _companyPick != _Pick.create) {
        final term = _companySearch.text.trim().toLowerCase();
        final exact = pinned ??
            _companies
                .where((m) => m.name.trim().toLowerCase() == term)
                .firstOrNull;
        if (exact != null) {
          _companyPick = _Pick.existing;
          _companyId = exact.id;
        } else if (term.isNotEmpty) {
          _companyPick = _Pick.create;
          _companyName.text = _companySearch.text.trim();
        } else {
          _companyPick = _Pick.none;
        }
      }
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _loadContacts(Map<String, dynamic> v) async {
    final linked = LeadConvertLogic.readLookup(v['contact']);
    final email = LeadConvertLogic.text(v['contact_email']) ??
        LeadConvertLogic.text(v['email']);
    final name = LeadConvertLogic.text(v['contact_name']) ??
        LeadConvertLogic.text(v['name']);
    var found = <ContactMatch>[];
    try {
      found = await _svc.findContacts(email, name);
    } catch (_) {/* no matches → new / none */}
    if (linked.id != null && !found.any((f) => f.id == linked.id)) {
      found = [ContactMatch(id: linked.id!, name: linked.name ?? linked.id!), ...found];
    }
    _contacts = found;
    final split = LeadConvertLogic.splitName(name);
    final pre = linked.id ??
        found
            .where((f) =>
                email != null && f.email?.toLowerCase() == email.toLowerCase())
            .firstOrNull
            ?.id;
    if (pre != null) {
      _contactPick = _Pick.existing;
      _contactId = pre;
    } else {
      _contactPick = split.first != null ? _Pick.create : _Pick.none;
    }
    _firstName.text = split.first ?? '';
    _lastName.text = split.last ?? '';
    _email.text = email ?? '';
    _phone.text = LeadConvertLogic.text(v['contact_phone']) ??
        LeadConvertLogic.text(v['phone']) ??
        '';
  }

  // ── Validation ───────────────────────────────────────────────────────────

  bool get _partiesValid {
    if (_companyPick == _Pick.create && _companyName.text.trim().isEmpty) {
      return false;
    }
    if (_companyPick == _Pick.existing && _companyId == null) return false;
    if (_contactPick == _Pick.create && _firstName.text.trim().isEmpty) {
      return false;
    }
    if (_contactPick == _Pick.existing && _contactId == null) return false;
    final mail = _email.text.trim();
    if (_contactPick == _Pick.create && mail.isNotEmpty && !mail.contains('@')) {
      return false;
    }
    return true;
  }

  num? get _amountValue => LeadConvertLogic.toNumber(_amount.text.replaceAll(',', '.'));

  bool get _dealValid {
    final a = _amountValue;
    return a != null && a >= 0 && _stage != null;
  }

  void _next() {
    switch (_step) {
      case 0:
        if (_lead == null || _isTerminal) return;
      case 1:
        if (!_partiesValid) {
          setState(() => _partiesAttempted = true);
          return;
        }
      case 2:
        if (!_dealValid) {
          setState(() => _dealAttempted = true);
          return;
        }
      default:
        return;
    }
    setState(() => _step += 1);
  }

  CompanyChoice get _companyChoice => switch (_companyPick) {
        _Pick.create => NewCompany(_companyName.text.trim()),
        _Pick.none => const NoCompany(),
        _Pick.existing => ExistingCompany(
            _companyId!,
            _companies.where((m) => m.id == _companyId).firstOrNull?.name ??
                _companyId!),
      };

  ContactChoice get _contactChoice => switch (_contactPick) {
        _Pick.create => NewContact(
            firstName: _firstName.text.trim(),
            lastName: _nullIfEmpty(_lastName.text),
            email: _nullIfEmpty(_email.text),
            phone: _nullIfEmpty(_phone.text)),
        _Pick.none => const NoContact(),
        _Pick.existing => ExistingContact(
            _contactId!,
            _contacts.where((m) => m.id == _contactId).firstOrNull?.name ??
                _contactId!),
      };

  static String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  String? get _expectedCloseIso => _expectedClose == null
      ? null
      : '${_expectedClose!.year.toString().padLeft(4, '0')}-'
          '${_expectedClose!.month.toString().padLeft(2, '0')}-'
          '${_expectedClose!.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final lead = _lead;
    if (_converting || lead == null) return;
    if (!_partiesValid || !_dealValid) {
      setState(() {
        _partiesAttempted = true;
        _dealAttempted = true;
        _step = _partiesValid ? 2 : 1;
      });
      return;
    }
    setState(() => _converting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await _svc.convert(
        lead: lead,
        company: _companyChoice,
        contact: _contactChoice,
        deal: DealDetails(
          amount: _amountValue,
          stage: _stage,
          ownerId: _ownerId,
          ownerName: _members.where((m) => m.id == _ownerId).firstOrNull?.name,
          expectedClose: _expectedCloseIso,
        ),
        finalLeadCodes: {for (final s in _leadStages) if (s.isFinal) s.code},
        comment: crmT('crm.leads.converted_comment', 'Fırsata dönüştürüldü'),
      );
      if (!mounted) return;
      final dealId = result.dealId;
      if (dealId == null) {
        messenger.showSnackBar(SnackBar(
            content: Text(crmT('crm.lead_convert.deal_pending',
                'Potansiyel dönüştürüldü; fırsat birazdan görünecek.'))));
        Navigator.of(context).maybePop();
        return;
      }
      messenger.showSnackBar(SnackBar(
          content: Text(result.detailsApplied
              ? crmT('crm.leads.converted', 'Potansiyel fırsata dönüştürüldü')
              : crmT('crm.lead_convert.details_not_applied',
                  'Fırsat oluşturuldu ancak bazı bilgiler uygulanamadı.'))));
      final open = widget.onOpenDeal;
      if (open != null) {
        setState(() => _converting = false);
        open(context, dealId);
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
            builder: (_) => EntityDetailScreen(typeCode: 'deal', id: dealId)));
      }
    } catch (e) {
      Logger.error('lead convert (${lead.id}) hata', e);
      if (!mounted) return;
      final key = e is LeadConvertException && e.key.startsWith('crm.')
          ? e.key
          : 'crm.leads.convert_error';
      messenger.showSnackBar(SnackBar(
          content: Text(crmT(key, 'Potansiyel dönüştürülemedi'))));
      setState(() => _converting = false);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('crm.lead_convert.title', 'Potansiyeli fırsata dönüştür'),
      onBack: _converting ? null : () => Navigator.of(context).maybePop(),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_loadError || _lead == null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: crmT('crm.lead_convert.load_error', 'Potansiyel yüklenemedi.'),
        ),
      );
    }
    return Stepper(
      currentStep: _step,
      onStepTapped: (i) {
        if (!_converting && i < _step) setState(() => _step = i);
      },
      // Yalnız aktif adımın kontrolleri/içeriği kurulur (dikey Stepper tüm
      // adımları çizer; çift anahtar/odak sorunlarını önler).
      controlsBuilder: (ctx, details) => details.stepIndex == details.currentStep
          ? _controls()
          : const SizedBox.shrink(),
      steps: [
        Step(
          title: Text(crmT('crm.lead_convert.step.review', 'Potansiyeli gözden geçir')),
          isActive: _step >= 0,
          state: _step > 0 ? StepState.complete : StepState.indexed,
          content: _step == 0 ? _reviewStep() : const SizedBox.shrink(),
        ),
        Step(
          title: Text(crmT('crm.lead_convert.step.parties', 'Firma ve kişi')),
          isActive: _step >= 1,
          state: _step > 1 ? StepState.complete : StepState.indexed,
          content: _step == 1 ? _partiesStep() : const SizedBox.shrink(),
        ),
        Step(
          title: Text(crmT('crm.lead_convert.step.deal', 'Fırsat bilgileri')),
          isActive: _step >= 2,
          state: _step > 2 ? StepState.complete : StepState.indexed,
          content: _step == 2 ? _dealStep() : const SizedBox.shrink(),
        ),
        Step(
          title: Text(crmT('crm.lead_convert.step.confirm', 'Onayla')),
          isActive: _step >= 3,
          content: _step == 3 ? _confirmStep() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _controls() {
    final last = _step == 3;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_step > 0)
            TextButton(
              onPressed: _converting ? null : () => setState(() => _step -= 1),
              child: Text(crmT('common.back', 'Geri')),
            ),
          const SizedBox(width: AppSpacing.sm),
          if (last)
            AppButton(
              key: const Key('lead-convert-submit'),
              label: _converting
                  ? crmT('crm.lead_convert.converting', 'Dönüştürülüyor…')
                  : crmT('crm.leads.convert', 'Fırsata Dönüştür'),
              icon: Icons.arrow_circle_right_outlined,
              variant: AppButtonVariant.success,
              isLoading: _converting,
              isFullWidth: false,
              onPressed: _converting ? null : _submit,
            )
          else
            AppButton(
              key: const Key('lead-convert-next'),
              label: crmT('common.next', 'Sonraki'),
              trailingIcon: Icons.arrow_forward,
              isFullWidth: false,
              onPressed: (_step == 0 && _isTerminal) ? null : _next,
            ),
        ],
      ),
    );
  }

  Widget _kv(String label, String? value) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.secondaryLabel(context))),
            ),
            Expanded(child: Text((value == null || value.isEmpty) ? '—' : value)),
          ],
        ),
      );

  String _leadTitle(ConvertEntity l) {
    final v = l.values;
    String s(String k) => LeadConvertLogic.readLookup(v[k]).name ??
        (v[k] is String ? (v[k] as String).trim() : '');
    final name = s('name').isNotEmpty ? s('name') : s('contact_name');
    final subject = (l.subject ?? '').trim();
    if (subject.isNotEmpty && subject != name) return subject;
    final parts = [name, s('company')].where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' · ');
    final mail = s('email').isNotEmpty ? s('email') : s('contact_email');
    if (mail.isNotEmpty) return mail;
    return subject.isNotEmpty
        ? subject
        : crmT('crm.leads.untitled', '(başlıksız potansiyel)');
  }

  Widget _reviewStep() {
    final l = _lead!;
    final v = l.values;
    final status = _leadStages.where((s) => s.code == l.status).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kv(crmT('crm.leads.col_subject', 'Konu'),
            [_leadTitle(l), if (l.code != null) l.code!].join('  ')),
        _kv(crmT('crm.leads.col_status', 'Durum'),
            status?.name ?? EntityStatusLabels.humanize(l.status)),
        _kv(crmT('crm.lead_convert.contact_name', 'Kişi adı'),
            LeadConvertLogic.text(v['contact_name']) ?? LeadConvertLogic.text(v['name'])),
        _kv(crmT('crm.lead_convert.contact_email', 'E-posta'),
            LeadConvertLogic.text(v['contact_email']) ?? LeadConvertLogic.text(v['email'])),
        _kv(crmT('crm.lead_convert.contact_phone', 'Telefon'),
            LeadConvertLogic.text(v['contact_phone']) ?? LeadConvertLogic.text(v['phone'])),
        _kv(crmT('crm.lead_convert.company', 'Firma'),
            LeadConvertLogic.readLookup(v['company']).name ??
                LeadConvertLogic.text(v['company_text'])),
        _kv(crmT('crm.lead_convert.est_value', 'Tahmini değer'),
            LeadConvertLogic.toNumber(v['est_value'])?.toString()),
        if (_isTerminal)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              crmT('crm.lead_convert.already_terminal',
                  'Bu potansiyel zaten dönüştürülmüş veya elenmiş; tekrar dönüştürülemez.'),
              key: const Key('lead-convert-terminal'),
              style: AppTypography.caption1.copyWith(color: AppColors.warning),
            ),
          ),
      ],
    );
  }

  Widget _errorText(String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text,
            style: AppTypography.caption1.copyWith(color: AppColors.error)),
      );

  Widget _partiesStep() {
    final required = crmT('common.required', 'Zorunlu');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(crmT('crm.lead_convert.company', 'Firma'), style: AppTypography.headline),
        const SizedBox(height: AppSpacing.xs),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('lead-convert-company-search'),
              controller: _companySearch,
              decoration: InputDecoration(
                labelText: crmT('crm.lead_convert.company_search', 'Firma ara'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _searchCompanies(),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            tooltip: crmT('common.search', 'Ara'),
            onPressed: _searching ? null : () => _searchCompanies(),
            icon: _searching
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
          ),
        ]),
        if (_companies.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
                crmT('crm.lead_convert.no_company_match', 'Eşleşen firma bulunamadı.'),
                style: AppTypography.caption1
                    .copyWith(color: AppColors.secondaryLabel(context))),
          ),
        RadioGroup<String>(
          groupValue: switch (_companyPick) {
            _Pick.existing => _companyId,
            _Pick.create => '__new__',
            _Pick.none => '__none__',
          },
          onChanged: (v) => setState(() {
            if (v == '__new__') {
              _companyPick = _Pick.create;
            } else if (v == '__none__') {
              _companyPick = _Pick.none;
            } else {
              _companyPick = _Pick.existing;
              _companyId = v;
            }
          }),
          child: Column(children: [
            for (final m in _companies)
              RadioListTile<String>(
                key: ValueKey('lead-convert-company-${m.id}'),
                value: m.id,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(m.code == null ? m.name : '${m.name} (${m.code})'),
              ),
            RadioListTile<String>(
              key: const ValueKey('lead-convert-company-new'),
              value: '__new__',
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(crmT('crm.lead_convert.create_new_company', 'Yeni firma oluştur')),
            ),
            RadioListTile<String>(
              key: const ValueKey('lead-convert-company-none'),
              value: '__none__',
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(crmT('crm.lead_convert.no_company', 'Firma bağlama')),
            ),
          ]),
        ),
        if (_companyPick == _Pick.create) ...[
          TextField(
            key: const Key('lead-convert-company-name'),
            controller: _companyName,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: crmT('crm.lead_convert.new_company_name', 'Yeni firma adı'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_partiesAttempted && _companyName.text.trim().isEmpty) _errorText(required),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(crmT('crm.lead_convert.contact', 'Kişi'), style: AppTypography.headline),
        if (_contacts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
                crmT('crm.lead_convert.no_contact_match',
                    'E-posta veya adla eşleşen kişi bulunamadı.'),
                style: AppTypography.caption1
                    .copyWith(color: AppColors.secondaryLabel(context))),
          ),
        RadioGroup<String>(
          groupValue: switch (_contactPick) {
            _Pick.existing => _contactId,
            _Pick.create => '__new__',
            _Pick.none => '__none__',
          },
          onChanged: (v) => setState(() {
            if (v == '__new__') {
              _contactPick = _Pick.create;
            } else if (v == '__none__') {
              _contactPick = _Pick.none;
            } else {
              _contactPick = _Pick.existing;
              _contactId = v;
            }
          }),
          child: Column(children: [
            for (final m in _contacts)
              RadioListTile<String>(
                key: ValueKey('lead-convert-contact-${m.id}'),
                value: m.id,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(m.email == null ? m.name : '${m.name} <${m.email}>'),
              ),
            RadioListTile<String>(
              key: const ValueKey('lead-convert-contact-new'),
              value: '__new__',
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(crmT('crm.lead_convert.create_new_contact', 'Yeni kişi oluştur')),
            ),
            RadioListTile<String>(
              key: const ValueKey('lead-convert-contact-none'),
              value: '__none__',
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(crmT('crm.lead_convert.no_contact', 'Kişi bağlama')),
            ),
          ]),
        ),
        if (_contactPick == _Pick.create) ...[
          _field(_firstName, crmT('crm.lead_convert.first_name', 'Ad'),
              key: const Key('lead-convert-first-name')),
          if (_partiesAttempted && _firstName.text.trim().isEmpty) _errorText(required),
          const SizedBox(height: AppSpacing.xs),
          _field(_lastName, crmT('crm.lead_convert.last_name', 'Soyad')),
          const SizedBox(height: AppSpacing.xs),
          _field(_email, crmT('crm.lead_convert.contact_email', 'E-posta'),
              keyboard: TextInputType.emailAddress),
          const SizedBox(height: AppSpacing.xs),
          _field(_phone, crmT('crm.lead_convert.contact_phone', 'Telefon'),
              keyboard: TextInputType.phone),
        ],
      ],
    );
  }

  Widget _field(TextEditingController c, String label,
          {Key? key, TextInputType? keyboard}) =>
      TextField(
        key: key,
        controller: c,
        keyboardType: keyboard,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      );

  Widget _dealStep() {
    final required = crmT('common.required', 'Zorunlu');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(_amount, '${crmT('crm.lead_convert.amount', 'Tutar')} *',
            key: const Key('lead-convert-amount'),
            keyboard: const TextInputType.numberWithOptions(decimal: true)),
        if (_dealAttempted && (_amountValue == null || _amountValue! < 0))
          _errorText(required),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          key: const Key('lead-convert-stage'),
          initialValue: _stage,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: '${crmT('crm.lead_convert.stage', 'Aşama')} *',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          hint: Text(crmT('crm.lead_convert.select', 'Seçin')),
          items: [
            for (final s in _dealStages)
              DropdownMenuItem(value: s.code, child: Text(s.name)),
          ],
          onChanged: (v) => setState(() => _stage = v),
        ),
        if (_dealAttempted && _stage == null) _errorText(required),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          key: const Key('lead-convert-owner'),
          initialValue: _ownerId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: crmT('crm.lead_convert.owner', 'Sorumlu'),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          hint: Text(crmT('crm.lead_convert.select', 'Seçin')),
          items: [
            for (final m in _members)
              DropdownMenuItem(value: m.id, child: Text(m.name)),
          ],
          onChanged: (v) => setState(() => _ownerId = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _expectedClose ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 10),
            );
            if (picked != null) setState(() => _expectedClose = picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: crmT('crm.lead_convert.expected_close', 'Beklenen kapanış tarihi'),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.event_outlined),
            ),
            child: Text(_expectedClose == null ? '—' : AppClock.date(_expectedClose!)),
          ),
        ),
      ],
    );
  }

  String _summary(_Pick pick, String name) => switch (pick) {
        _Pick.create => crmTp('crm.lead_convert.summary_new',
            'Yeni oluşturulacak: {{name}}', {'name': name}),
        _Pick.existing => crmTp(
            'crm.lead_convert.summary_existing', 'Mevcut: {{name}}', {'name': name}),
        _Pick.none => crmT('crm.lead_convert.summary_none', 'Bağlanmayacak'),
      };

  Widget _confirmStep() {
    final companyName = _companyPick == _Pick.create
        ? _companyName.text.trim()
        : _companies.where((m) => m.id == _companyId).firstOrNull?.name ?? '';
    final contactName = _contactPick == _Pick.create
        ? [_firstName.text.trim(), _lastName.text.trim()]
            .where((s) => s.isNotEmpty)
            .join(' ')
        : _contacts.where((m) => m.id == _contactId).firstOrNull?.name ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kv(crmT('crm.leads.col_subject', 'Konu'), _leadTitle(_lead!)),
        _kv(crmT('crm.lead_convert.company', 'Firma'), _summary(_companyPick, companyName)),
        _kv(crmT('crm.lead_convert.contact', 'Kişi'), _summary(_contactPick, contactName)),
        _kv(crmT('crm.lead_convert.amount', 'Tutar'), _amount.text.trim()),
        _kv(crmT('crm.lead_convert.stage', 'Aşama'),
            _dealStages.where((s) => s.code == _stage).firstOrNull?.name),
        _kv(crmT('crm.lead_convert.owner', 'Sorumlu'),
            _members.where((m) => m.id == _ownerId).firstOrNull?.name),
        _kv(crmT('crm.lead_convert.expected_close', 'Beklenen kapanış tarihi'),
            _expectedClose == null ? null : AppClock.date(_expectedClose!)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          crmT('crm.lead_convert.confirm_hint',
              'Dönüştürme potansiyeli kapatır ve fırsatı oluşturur. Bu işlem geri alınamaz.'),
          style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context)),
        ),
      ],
    );
  }
}
