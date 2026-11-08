import 'dart:convert';

import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lookup `entityType`s of the CRM lead/deal forms (web `CRM_LOOKUP`).
class CrmLookup {
  CrmLookup._();
  static const company = 'crm_companies';
  static const contact = 'contacts';
  static const owner = 'profiles';

  static Map<String, dynamic> ref(String entityType, String id, String name) =>
      {'entityType': entityType, 'entityId': id, 'displayValue': name};
}

/// A company candidate in the wizard's match list.
class CompanyMatch {
  final String id;
  final String name;
  final String? code;
  const CompanyMatch({required this.id, required this.name, this.code});
}

/// A contact candidate in the wizard's match list.
class ContactMatch {
  final String id;
  final String name;
  final String? email;
  const ContactMatch({required this.id, required this.name, this.email});
}

/// A selectable owner (`profiles`).
class MemberOption {
  final String id;
  final String name;
  const MemberOption(this.id, this.name);
}

/// Company choice: existing record, new one by name, or none.
sealed class CompanyChoice {
  const CompanyChoice();
}

class ExistingCompany extends CompanyChoice {
  final String id;
  final String name;
  const ExistingCompany(this.id, this.name);
}

class NewCompany extends CompanyChoice {
  final String name;
  const NewCompany(this.name);
}

class NoCompany extends CompanyChoice {
  const NoCompany();
}

/// Contact choice: existing record, new one, or none.
sealed class ContactChoice {
  const ContactChoice();
}

class ExistingContact extends ContactChoice {
  final String id;
  final String name;
  const ExistingContact(this.id, this.name);
}

class NewContact extends ContactChoice {
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  const NewContact(
      {required this.firstName, this.lastName, this.email, this.phone});
  String get fullName =>
      [firstName, lastName ?? ''].where((s) => s.isNotEmpty).join(' ');
}

class NoContact extends ContactChoice {
  const NoContact();
}

/// A loaded standalone entity (`form_submissions`) with merged values
/// (`{...form_field_values, ...metadata}` — web `entityValues` precedence).
class ConvertEntity {
  final String id;
  final String? code;
  final String? subject;
  final String status;
  final String? formTemplateId;
  final String? assignedTo;
  final String? dueDate;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> values;

  const ConvertEntity({
    required this.id,
    required this.status,
    this.code,
    this.subject,
    this.formTemplateId,
    this.assignedTo,
    this.dueDate,
    this.metadata = const {},
    this.values = const {},
  });
}

/// Wizard deal details (step 3).
class DealDetails {
  final num? amount;
  final String? stage;
  final String? ownerId;
  final String? ownerName;
  final String? expectedClose; // yyyy-MM-dd
  const DealDetails(
      {this.amount, this.stage, this.ownerId, this.ownerName, this.expectedClose});
}

/// Result: the created deal id (null when the automation did not report it in
/// time) and whether the wizard's details reached the deal.
class LeadConvertResult {
  final String? dealId;
  final bool detailsApplied;
  const LeadConvertResult(this.dealId, this.detailsApplied);
}

/// Error carrying an i18n key (`crm.*`) for the UI.
class LeadConvertException implements Exception {
  final String key;
  final String? detail;
  const LeadConvertException(this.key, [this.detail]);
  @override
  String toString() => 'LeadConvertException($key${detail == null ? '' : ': $detail'})';
}

/// Pure helpers of the conversion (web `lead-convert.service.ts` parity).
class LeadConvertLogic {
  LeadConvertLogic._();

  /// The conversion target owned by the wizard.
  static const String convertedStatus = 'converted';

  /// `{entityId, displayValue}` of a lookup value (or a raw uuid string).
  static ({String? id, String? name}) readLookup(dynamic v) {
    if (v is String) return (id: v.isEmpty ? null : v, name: null);
    if (v is Map) {
      final id = v['entityId'] is String ? v['entityId'] as String : null;
      final name = v['displayValue'] is String
          ? v['displayValue'] as String
          : (v['name'] is String ? v['name'] as String : null);
      return (
        id: (id == null || id.isEmpty) ? null : id,
        name: (name == null || name.isEmpty) ? null : name,
      );
    }
    return (id: null, name: null);
  }

  /// Trimmed non-empty text of a value, else null.
  static String? text(dynamic v) {
    if (v == null) return null;
    final s = (v is String ? v : v.toString()).trim();
    return s.isEmpty ? null : s;
  }

  static num? toNumber(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().trim();
    return s.isEmpty ? null : num.tryParse(s);
  }

  /// "Ada Lovelace King" → (first: Ada, last: Lovelace King).
  static ({String? first, String? last}) splitName(String? full) {
    final parts = (full ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return (first: null, last: null);
    final last = parts.skip(1).join(' ');
    return (first: parts.first, last: last.isEmpty ? null : last);
  }

  /// The created deal id from an execution's `node_results`.
  static String? dealIdFromNodeResults(dynamic nodeResults) {
    if (nodeResults is! Map) return null;
    for (final node in nodeResults.values) {
      if (node is! Map) continue;
      final out = node['output'];
      if (out is Map &&
          out['entityType'] == 'deal' &&
          out['entityId'] is String &&
          out['created'] != false) {
        return out['entityId'] as String;
      }
    }
    return null;
  }

  /// The error of a failed create-entity step, if any.
  static String? dealErrorFromNodeResults(dynamic nodeResults) {
    if (nodeResults is! Map) return null;
    for (final node in nodeResults.values) {
      if (node is! Map) continue;
      if (node['nodeType'] == 'action_create_entity' && node['status'] == 'failed') {
        return node['error'] is String
            ? node['error'] as String
            : 'create_entity failed';
      }
    }
    return null;
  }

  /// form-submit EF `isEmpty`: null, blank string or empty list.
  static bool isEmptyValue(dynamic v) =>
      v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);

  /// Web `mapValueToFieldValueColumns`: one typed `value_*` column per field.
  static Map<String, dynamic> fieldValueColumns(String fieldType, dynamic value) {
    final row = <String, dynamic>{
      'value_text': null,
      'value_number': null,
      'value_date': null,
      'value_boolean': null,
      'value_json': null,
    };
    switch (fieldType) {
      case 'text':
      case 'textarea':
      case 'email':
      case 'phone':
      case 'select':
      case 'radio':
      case 'barcode':
      case 'rich_text':
        row['value_text'] = value is String ? value : value.toString();
      case 'number':
      case 'currency':
      case 'percentage':
      case 'rating':
        row['value_number'] = toNumber(value);
      case 'date':
      case 'datetime':
        row['value_date'] = value;
      case 'checkbox':
        row['value_boolean'] = value == true || value == 'true';
      case 'multiselect':
      case 'file':
      case 'image':
      case 'location':
      case 'daterange':
      case 'lookup':
      case 'signature':
        row['value_json'] = value;
      default:
        row['value_text'] = value is String ? value : jsonEncode(value);
    }
    return row;
  }

  /// Fresh active `form_field_values` rows for [values] (template fields only,
  /// headings/dividers and empties skipped) — web `resyncFieldValues`.
  static List<Map<String, dynamic>> fieldValueRows({
    required String submissionId,
    required Map<String, ({String id, String fieldType})> fields,
    required Map<String, dynamic> values,
    String? userId,
  }) {
    final rows = <Map<String, dynamic>>[];
    values.forEach((code, value) {
      final meta = fields[code];
      if (meta == null) return;
      if (meta.fieldType == 'heading' || meta.fieldType == 'divider') return;
      if (isEmptyValue(value)) return;
      rows.add({
        'form_submission_id': submissionId,
        'form_field_id': meta.id,
        'active': true,
        'created_by': userId,
        'updated_by': userId,
        ...fieldValueColumns(meta.fieldType, value),
      });
    });
    return rows;
  }

  /// Value read back from a `form_field_values` row (first typed column).
  static dynamic valueOfRow(Map<String, dynamic> r) =>
      r['value_json'] ??
      r['value_number'] ??
      r['value_date'] ??
      r['value_boolean'] ??
      r['value_text'];
}

/// Data gate of the conversion — faked in tests.
abstract class LeadConvertBackend {
  String? get tenantId;
  String? get userId;
  Future<ConvertEntity?> loadEntity(String id);
  Future<List<CompanyMatch>> searchCompanies(String term);
  Future<List<ContactMatch>> searchContacts({String? email, String? first, String? last});
  Future<List<MemberOption>> members();
  Future<List<Map<String, dynamic>>> statusTransitionRows(String entityType);
  Future<Set<String>> roles();
  Future<String?> companyTemplateId();
  Future<String> createCompany(String templateId, String name);
  Future<String> createContact(NewContact c, {String? companyId});
  Future<Map<String, ({String id, String fieldType})>> templateFields(String templateId);
  Future<void> patchMetadata(String id, Map<String, dynamic> values);
  Future<void> replaceFieldValues(String submissionId, List<Map<String, dynamic>> rows);
  Future<void> executeTransition(String entityType, String id, String toStatus,
      {String? comment});
  Future<List<Map<String, dynamic>>> executions(String leadId, String sinceIso);
}

/// Lead → deal conversion (web `LeadConvertService.convert`). The conversion
/// itself stays server-side: the lead walks its workflow to `converted`
/// (status-transition EF) and the `crm-lead-to-deal-convert` automation
/// creates the deal from the lead's `company` / `contact` / `est_value`
/// (read from `form_field_values`). So:
///  1. company/contact are reused or created;
///  2. the lead's own fields are patched (metadata merge + field-value
///     re-sync) so the automation carries them;
///  3. the lead walks the allowed transitions to `converted`;
///  4. the deal is located through `wf_workflow_executions` and the fields the
///     automation does not map (owner, expected close, stage) are applied.
class LeadConvertService {
  LeadConvertService({
    LeadConvertBackend? backend,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
  })  : _backend = backend ?? SupabaseLeadConvertBackend(),
        _sleep = sleep ?? Future<void>.delayed,
        _now = now ?? DateTime.now;

  final LeadConvertBackend _backend;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;

  LeadConvertBackend get backend => _backend;

  /// Poll schedule while waiting for the automation (web `pollDelaysMs`).
  List<Duration> pollDelays = const [
    Duration(milliseconds: 500),
    Duration(milliseconds: 1000),
    Duration(milliseconds: 1000),
    Duration(milliseconds: 1500),
    Duration(milliseconds: 2000),
    Duration(milliseconds: 2000),
    Duration(milliseconds: 3000),
  ];

  Future<List<CompanyMatch>> findCompanies(String term) {
    final q = term.trim();
    if (q.length < 2) return Future.value(const []);
    return _backend.searchCompanies(q);
  }

  /// Contacts matching the e-mail or first + last name (dedup by id).
  Future<List<ContactMatch>> findContacts(String? email, String? fullName) async {
    final split = LeadConvertLogic.splitName(fullName);
    final mail = LeadConvertLogic.text(email);
    if (mail == null && split.first == null) return const [];
    final rows = await _backend.searchContacts(
        email: mail, first: split.first, last: split.last);
    final seen = <String, ContactMatch>{};
    for (final r in rows) {
      seen.putIfAbsent(r.id, () => r);
    }
    return seen.values.toList();
  }

  /// Run the conversion. Throws before/while walking; after the walk a
  /// missing deal yields `dealId: null`.
  Future<LeadConvertResult> convert({
    required ConvertEntity lead,
    required CompanyChoice company,
    required ContactChoice contact,
    required DealDetails deal,
    Set<String> finalLeadCodes = const {},
    String? comment,
  }) async {
    final since = _now().toUtc().subtract(const Duration(minutes: 1));
    final companyRef = await _resolveCompany(company);
    final contactRef = await _resolveContact(
        contact, companyRef == null ? null : companyRef['entityId'] as String);

    final leadPatch = <String, dynamic>{...lead.values};
    if (companyRef != null) leadPatch['company'] = companyRef;
    if (contactRef != null) leadPatch['contact'] = contactRef;
    if (deal.amount != null) leadPatch['est_value'] = deal.amount;
    if (companyRef != null || contactRef != null || deal.amount != null) {
      await _updateEntity(lead.id, lead.formTemplateId, leadPatch);
    }

    await _walkToConverted(lead, finalLeadCodes, comment);

    final dealId = await waitForDeal(lead.id, since.toIso8601String());
    if (dealId == null) return const LeadConvertResult(null, false);
    try {
      await _applyDealDetails(dealId, deal, companyRef, contactRef);
      return LeadConvertResult(dealId, true);
    } catch (e) {
      Logger.error('lead convert: deal details not applied ($dealId)', e);
      return LeadConvertResult(dealId, false);
    }
  }

  Future<Map<String, dynamic>?> _resolveCompany(CompanyChoice c) async {
    switch (c) {
      case NoCompany():
        return null;
      case ExistingCompany(:final id, :final name):
        return CrmLookup.ref(CrmLookup.company, id, name);
      case NewCompany(:final name):
        final tpl = await _backend.companyTemplateId();
        if (tpl == null || tpl.isEmpty) {
          throw const LeadConvertException('crm.lead_convert.error_company_template');
        }
        final id = await _backend.createCompany(tpl, name);
        return CrmLookup.ref(CrmLookup.company, id, name);
    }
  }

  Future<Map<String, dynamic>?> _resolveContact(
      ContactChoice c, String? companyId) async {
    switch (c) {
      case NoContact():
        return null;
      case ExistingContact(:final id, :final name):
        return CrmLookup.ref(CrmLookup.contact, id, name);
      case NewContact():
        final id = await _backend.createContact(c, companyId: companyId);
        return CrmLookup.ref(CrmLookup.contact, id, c.fullName);
    }
  }

  /// Web `patchStandaloneEntity({metadata})`: merge onto stored metadata, then
  /// re-sync `form_field_values` from the full snapshot.
  Future<void> _updateEntity(
      String id, String? templateId, Map<String, dynamic> values) async {
    await _backend.patchMetadata(id, values);
    if (templateId == null || templateId.isEmpty) return;
    final fields = await _backend.templateFields(templateId);
    if (fields.isEmpty) return;
    await _backend.replaceFieldValues(
      id,
      LeadConvertLogic.fieldValueRows(
          submissionId: id, fields: fields, values: values, userId: _backend.userId),
    );
  }

  /// Advance one allowed transition at a time up to `converted` (the workflow
  /// permits no skips). Path from `status_transitions`, not a fixed ladder.
  Future<void> _walkToConverted(
      ConvertEntity lead, Set<String> finalCodes, String? comment) async {
    if (lead.status == LeadConvertLogic.convertedStatus) return;
    final rows = await _backend.statusTransitionRows('lead');
    final roles = await _backend.roles();
    final path = StatusTransitionRules.pathTo(
          rows,
          entityType: 'lead',
          fromCode: lead.status,
          toCode: LeadConvertLogic.convertedStatus,
          roles: roles,
          tenantId: _backend.tenantId,
          finalCodes: finalCodes,
        ) ??
        const [LeadConvertLogic.convertedStatus];
    for (final to in path) {
      await _backend.executeTransition('lead', lead.id, to, comment: comment);
    }
  }

  /// Poll the automation's execution record for this lead's created deal.
  /// Throws the step's error when the automation failed.
  Future<String?> waitForDeal(String leadId, String sinceIso) async {
    for (final d in pollDelays) {
      await _sleep(d);
      String? failure;
      try {
        final rows = await _backend.executions(leadId, sinceIso);
        for (final r in rows) {
          final id = LeadConvertLogic.dealIdFromNodeResults(r['node_results']);
          if (id != null) return id;
          failure ??= LeadConvertLogic.dealErrorFromNodeResults(r['node_results']);
        }
      } catch (_) {/* transient — keep polling */}
      if (failure != null) {
        throw LeadConvertException('crm.leads.convert_error', failure);
      }
    }
    return null;
  }

  Future<void> _applyDealDetails(String dealId, DealDetails d,
      Map<String, dynamic>? company, Map<String, dynamic>? contact) async {
    final deal = await _backend.loadEntity(dealId);
    if (deal == null) throw StateError('deal $dealId not readable');
    final merged = <String, dynamic>{...deal.values};
    if (company != null) merged['company'] = company;
    if (contact != null) merged['contact'] = contact;
    if (d.amount != null) merged['amount'] = d.amount;
    if (d.ownerId != null && d.ownerId!.isNotEmpty) {
      merged['owner'] =
          CrmLookup.ref(CrmLookup.owner, d.ownerId!, d.ownerName ?? d.ownerId!);
    }
    merged['expected_close'] =
        (d.expectedClose == null || d.expectedClose!.isEmpty) ? null : d.expectedClose;
    await _updateEntity(dealId, deal.formTemplateId, merged);
    final stage = d.stage;
    if (stage != null && stage.isNotEmpty && stage != deal.status) {
      await _backend.executeTransition('deal', dealId, stage);
    }
  }
}

/// Supabase implementation (same tables / EFs / RPCs as the web service).
class SupabaseLeadConvertBackend implements LeadConvertBackend {
  SupabaseLeadConvertBackend({SupabaseClient? supabase}) : _client = supabase;

  final SupabaseClient? _client;
  SupabaseClient get _sb => _client ?? sl<SupabaseClient>();

  @override
  String? get tenantId => TenantScope().tenantId;

  @override
  String? get userId => _sb.auth.currentUser?.id;

  static List<Map<String, dynamic>> _rows(dynamic res) =>
      ((res as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  static String _escapeLike(String s) =>
      s.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');

  Future<String?> _organizationId() async {
    if (sl.isRegistered<OrganizationService>()) {
      final id = sl<OrganizationService>().currentOrganizationId;
      if (id != null) return id;
    }
    if (sl.isRegistered<ProfileService>()) {
      try {
        return (await sl<ProfileService>().getCurrentProfile())?.organizationId;
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<ConvertEntity?> loadEntity(String id) async {
    final row = await _sb
        .from('form_submissions')
        .select('id, code, subject, status, metadata, form_template_id, '
            'assigned_to, due_date')
        .eq('id', id)
        .eq('is_standalone', true)
        .maybeSingle();
    if (row == null) return null;
    final ffv = _rows(await _sb
        .from('form_field_values')
        .select('value_text, value_number, value_date, value_boolean, '
            'value_json, form_fields!inner(code)')
        .eq('form_submission_id', id)
        .eq('active', true));
    final fieldValues = <String, dynamic>{};
    for (final r in ffv) {
      final f = r['form_fields'];
      final code = f is Map ? f['code'] as String? : null;
      if (code == null) continue;
      fieldValues[code] = LeadConvertLogic.valueOfRow(r);
    }
    final meta = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : <String, dynamic>{};
    return ConvertEntity(
      id: row['id'] as String,
      code: row['code'] as String?,
      subject: row['subject'] as String?,
      status: (row['status'] as String?) ?? '',
      formTemplateId: row['form_template_id'] as String?,
      assignedTo: row['assigned_to'] as String?,
      dueDate: row['due_date']?.toString(),
      metadata: meta,
      values: {...fieldValues, ...meta},
    );
  }

  @override
  Future<List<CompanyMatch>> searchCompanies(String term) async {
    final q = term.replaceAll(RegExp(r'[,()]'), ' ').trim();
    var query = _sb
        .from('form_submissions')
        .select('id, code, subject')
        .eq('entity_type', 'company')
        .eq('is_standalone', true)
        .eq('active', true);
    final t = tenantId;
    if (t != null) query = query.eq('tenant_id', t);
    final res = await query
        .or('subject.ilike.%$q%,code.ilike.%$q%')
        .order('subject', ascending: true)
        .limit(8);
    return _rows(res)
        .map((r) => CompanyMatch(
              id: r['id'] as String,
              name: LeadConvertLogic.text(r['subject']) ??
                  LeadConvertLogic.text(r['code']) ??
                  r['id'] as String,
              code: r['code'] as String?,
            ))
        .toList();
  }

  @override
  Future<List<ContactMatch>> searchContacts(
      {String? email, String? first, String? last}) async {
    const select = 'id, first_name, last_name, email';
    final out = <Map<String, dynamic>>[];
    if (email != null) {
      out.addAll(_rows(await _sb
          .from('contacts')
          .select(select)
          .eq('active', true)
          .ilike('email', _escapeLike(email))
          .limit(5)));
    }
    if (first != null) {
      var q = _sb
          .from('contacts')
          .select(select)
          .eq('active', true)
          .ilike('first_name', _escapeLike(first));
      if (last != null) q = q.ilike('last_name', _escapeLike(last));
      out.addAll(_rows(await q.limit(5)));
    }
    return out.map((r) {
      final name = [r['first_name'], r['last_name']]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .join(' ');
      return ContactMatch(
        id: r['id'] as String,
        name: name.isNotEmpty ? name : (r['email'] as String? ?? r['id'] as String),
        email: r['email'] as String?,
      );
    }).toList();
  }

  @override
  Future<List<MemberOption>> members() async {
    final res = await _sb
        .from('profiles')
        .select('id, full_name, email')
        .eq('active', true)
        .order('full_name', ascending: true);
    return _rows(res)
        .map((r) => MemberOption(
            r['id'] as String,
            LeadConvertLogic.text(r['full_name']) ??
                LeadConvertLogic.text(r['email']) ??
                r['id'] as String))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> statusTransitionRows(String entityType) async =>
      _rows(await _sb
          .from('status_transitions')
          .select('id, name, tenant_id, required_roles, requires_comment, '
              'requires_confirmation, required_form_template_id, sort_order, '
              'from_status:status_definitions!from_status_id(code), '
              'to_status:status_definitions!to_status_id(code)')
          .eq('entity_type', entityType)
          .eq('active', true)
          .order('sort_order', ascending: true));

  @override
  Future<Set<String>> roles() => currentStatusTransitionRoles(_sb);

  @override
  Future<String?> companyTemplateId() async {
    if (!sl.isRegistered<EntityConfigService>()) return null;
    return (await sl<EntityConfigService>().getByCode('company'))
        ?.defaultFormTemplateId;
  }

  /// Web `createEntityWithValues`: form-submit EF draft (entity_type stamped
  /// from the start), promote to standalone with the initial status, code.
  @override
  Future<String> createCompany(String templateId, String name) async {
    final values = {'name': name};
    final res = await _sb.functions.invoke('form-submit', body: {
      'templateId': templateId,
      'values': values,
      'entityType': 'company',
      'entityId': null,
      'submissionId': null,
      'action': 'save',
    });
    final data = res.data;
    final inner = data is Map && data['data'] is Map ? data['data'] as Map : data;
    final id = inner is Map ? inner['submissionId'] as String? : null;
    if (id == null) {
      throw const LeadConvertException('crm.leads.convert_error', 'company not created');
    }
    final t = tenantId ?? StatusTransitionRules.systemTenantId;
    final init = await _sb
        .from('status_definitions')
        .select('code')
        .eq('entity_type', 'company')
        .eq('is_initial', true)
        .eq('active', true)
        .or('tenant_id.eq.$t,tenant_id.eq.${StatusTransitionRules.systemTenantId}')
        .order('is_system', ascending: true)
        .limit(1)
        .maybeSingle();
    await _sb.from('form_submissions').update({
      'entity_type': 'company',
      'entity_id': id,
      'is_standalone': true,
      'status': (init?['code'] as String?) ?? 'open',
      'subject': name,
      'organization_id': await _organizationId(),
      'metadata': values,
      'updated_by': userId,
    }).eq('id', id);
    await _sb.rpc('generate_entity_code', params: {
      'p_submission_id': id,
      'p_entity_type': 'company',
      'p_tenant_id': tenantId,
    });
    return id;
  }

  @override
  Future<String> createContact(NewContact c, {String? companyId}) async {
    final row = await _sb
        .from('contacts')
        .insert({
          'tenant_id': tenantId,
          'organization_id': await _organizationId(),
          'company_id': companyId,
          'first_name': c.firstName,
          'last_name': c.lastName,
          'email': c.email,
          'phone': c.phone,
          'is_primary': false,
          'active': true,
          'visibility': 'organization',
          'created_by': userId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  @override
  Future<Map<String, ({String id, String fieldType})>> templateFields(
      String templateId) async {
    final res = await _sb
        .from('form_fields')
        .select('id, code, field_type, form_sections!inner(form_template_id)')
        .eq('form_sections.form_template_id', templateId)
        .eq('active', true);
    return {
      for (final r in _rows(res))
        if (r['code'] is String)
          r['code'] as String: (
            id: r['id'] as String,
            fieldType: (r['field_type'] as String?) ?? 'text'
          ),
    };
  }

  @override
  Future<void> patchMetadata(String id, Map<String, dynamic> values) async {
    final stored = await _sb
        .from('form_submissions')
        .select('metadata')
        .eq('id', id)
        .maybeSingle();
    final base = stored?['metadata'] is Map
        ? Map<String, dynamic>.from(stored!['metadata'] as Map)
        : <String, dynamic>{};
    await _sb
        .from('form_submissions')
        .update({'metadata': {...base, ...values}, 'updated_by': userId})
        .eq('id', id)
        .eq('is_standalone', true);
  }

  @override
  Future<void> replaceFieldValues(
      String submissionId, List<Map<String, dynamic>> rows) async {
    // Deactivate first: partial unique index (submission, field) WHERE active.
    await _sb
        .from('form_field_values')
        .update({'active': false, 'updated_by': userId})
        .eq('form_submission_id', submissionId)
        .eq('active', true);
    if (rows.isNotEmpty) await _sb.from('form_field_values').insert(rows);
  }

  @override
  Future<void> executeTransition(String entityType, String id, String toStatus,
          {String? comment}) =>
      sl<EntityDataService>().updateStatus(
          entityType: entityType, entityId: id, toStatus: toStatus, comment: comment);

  @override
  Future<List<Map<String, dynamic>>> executions(String leadId, String sinceIso) async =>
      _rows(await _sb
          .from('wf_workflow_executions')
          .select('node_results, created_at')
          .eq('trigger_data->entity->>id', leadId)
          .gte('created_at', sinceIso)
          .order('created_at', ascending: false)
          .limit(5));
}
