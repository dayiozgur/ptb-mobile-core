import 'package:protoolbag_crm/features/leads/lead_convert_service.dart';

/// Supabase-free [LeadConvertBackend]: canned answers, recorded calls.
class FakeLeadConvertBackend implements LeadConvertBackend {
  FakeLeadConvertBackend({
    this.entities = const {},
    this.companies = const [],
    this.contacts = const [],
    this.memberList = const [],
    this.leadTransitions = const [],
    this.companyTemplate = 'tpl-company',
    this.fields = const {},
    this.executionRows = const [],
    this.roleSet = const {},
  });

  final Map<String, ConvertEntity> entities;
  final List<CompanyMatch> companies;
  final List<ContactMatch> contacts;
  final List<MemberOption> memberList;
  final List<Map<String, dynamic>> leadTransitions;
  final String? companyTemplate;
  final Map<String, Map<String, ({String id, String fieldType})>> fields;
  List<Map<String, dynamic>> executionRows;
  final Set<String> roleSet;

  /// Ordered log of write calls (`name:arg`).
  final List<String> log = [];
  final Map<String, Map<String, dynamic>> patched = {};
  final Map<String, List<Map<String, dynamic>>> replacedRows = {};
  final List<({String type, String id, String to, String? comment})> transitions = [];
  int executionPolls = 0;

  @override
  String? get tenantId => 't1';

  @override
  String? get userId => 'u1';

  @override
  Future<ConvertEntity?> loadEntity(String id) async => entities[id];

  @override
  Future<List<CompanyMatch>> searchCompanies(String term) async {
    log.add('searchCompanies:$term');
    return companies;
  }

  @override
  Future<List<ContactMatch>> searchContacts(
      {String? email, String? first, String? last}) async {
    log.add('searchContacts:$email|$first|$last');
    return contacts;
  }

  @override
  Future<List<MemberOption>> members() async => memberList;

  @override
  Future<List<Map<String, dynamic>>> statusTransitionRows(String entityType) async =>
      entityType == 'lead' ? leadTransitions : const [];

  @override
  Future<Set<String>> roles() async => roleSet;

  @override
  Future<String?> companyTemplateId() async => companyTemplate;

  @override
  Future<String> createCompany(String templateId, String name) async {
    log.add('createCompany:$templateId:$name');
    return 'co-new';
  }

  @override
  Future<String> createContact(NewContact c, {String? companyId}) async {
    log.add('createContact:${c.fullName}:$companyId');
    return 'ct-new';
  }

  @override
  Future<Map<String, ({String id, String fieldType})>> templateFields(
          String templateId) async =>
      fields[templateId] ?? const {};

  @override
  Future<void> patchMetadata(String id, Map<String, dynamic> values) async {
    log.add('patch:$id');
    patched[id] = values;
  }

  @override
  Future<void> replaceFieldValues(
      String submissionId, List<Map<String, dynamic>> rows) async {
    log.add('ffv:$submissionId');
    replacedRows[submissionId] = rows;
  }

  @override
  Future<void> executeTransition(String entityType, String id, String toStatus,
      {String? comment}) async {
    log.add('tx:$entityType:$toStatus');
    transitions.add((type: entityType, id: id, to: toStatus, comment: comment));
  }

  @override
  Future<List<Map<String, dynamic>>> executions(String leadId, String sinceIso) async {
    executionPolls++;
    return executionRows;
  }
}

Map<String, dynamic> leadTx(String from, String to) => {
      'id': '$from-$to',
      'required_roles': null,
      'requires_comment': false,
      'requires_confirmation': false,
      'required_form_template_id': null,
      'sort_order': 0,
      'from_status': {'code': from},
      'to_status': {'code': to},
    };

const leadLadder = [
  ('new', 'contacted'),
  ('contacted', 'qualified'),
  ('qualified', 'converted'),
  ('new', 'disqualified'),
];

List<Map<String, dynamic>> leadLadderRows() =>
    [for (final (f, t) in leadLadder) leadTx(f, t)];

Map<String, dynamic> createdDealExecution(String dealId) => {
      'node_results': {
        'n1': {'nodeType': 'trigger_status_change', 'status': 'completed'},
        'n2': {
          'nodeType': 'action_create_entity',
          'status': 'completed',
          'output': {'entityType': 'deal', 'entityId': dealId, 'created': true},
        },
      },
    };
