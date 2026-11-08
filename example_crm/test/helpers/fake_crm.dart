import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_crm/features/shared/crm_backend.dart';

/// Kayıtlı çağrı (RPC adı / tablo işlemi + parametreler).
class BackendCall {
  final String name;
  final Map<String, dynamic>? params;
  const BackendCall(this.name, [this.params]);
  @override
  String toString() => 'BackendCall($name, $params)';
}

/// Supabase'siz [CrmBackend] — yanıtlar önceden verilir, çağrılar kaydedilir.
class FakeCrmBackend implements CrmBackend {
  FakeCrmBackend({
    this.submissions = const {},
    this.statusDefs = const {},
    this.transitions = const {},
    this.rpcRowResults = const {},
    this.rpcResults = const {},
    this.contacts = const [],
    this.role,
    this.error,
    this.transitionError,
  });

  final Map<String, List<Map<String, dynamic>>> submissions;
  final Map<String, List<Map<String, dynamic>>> statusDefs;
  final Map<String, List<Map<String, dynamic>>> transitions;
  final Map<String, List<Map<String, dynamic>>> rpcRowResults;
  final Map<String, dynamic> rpcResults;
  final List<Map<String, dynamic>> contacts;
  final String? role;

  /// Verilirse okuma çağrıları bunu fırlatır.
  final Object? error;

  /// Verilirse executeTransition bunu fırlatır.
  final Object? transitionError;

  final List<BackendCall> calls = [];
  int transitionRowFetches = 0;

  void _maybeThrow() {
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<List<Map<String, dynamic>>> listSubmissions(String entityType,
      {int limit = 200}) async {
    calls.add(BackendCall('list:$entityType', {'limit': limit}));
    _maybeThrow();
    return submissions[entityType] ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> statusDefinitionRows(
      String entityType) async {
    calls.add(BackendCall('defs:$entityType'));
    _maybeThrow();
    return statusDefs[entityType] ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> statusTransitionRows(
      String entityType) async {
    transitionRowFetches++;
    calls.add(BackendCall('tx:$entityType'));
    _maybeThrow();
    return transitions[entityType] ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> rpcRows(String fn,
      [Map<String, dynamic>? params]) async {
    calls.add(BackendCall(fn, params));
    _maybeThrow();
    return rpcRowResults[fn] ?? const [];
  }

  @override
  Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]) async {
    calls.add(BackendCall(fn, params));
    _maybeThrow();
    return rpcResults[fn];
  }

  @override
  Future<List<Map<String, dynamic>>> contactsOfCompany(
      String companyId) async {
    calls.add(BackendCall('contacts', {'company_id': companyId}));
    _maybeThrow();
    return contacts;
  }

  @override
  Future<void> executeTransition({
    required String entityType,
    required String entityId,
    required String toStatus,
    String? comment,
  }) async {
    calls.add(BackendCall('status-transition', {
      'entityType': entityType,
      'entityId': entityId,
      'toStatus': toStatus,
      'comment': comment,
    }));
    final e = transitionError;
    if (e != null) throw e;
  }

  @override
  Future<String?> currentRole() async => role;
}

/// Anahtarı (ya da verilen tabloyu) döndüren sahte [LocalizationService] —
/// `crmT` anahtar bulunamayınca Türkçe yedeğe düşer.
class FakeLocalization implements LocalizationService {
  FakeLocalization([this.table = const {}]);
  final Map<String, String> table;

  @override
  String translate(String key, {Map<String, dynamic>? params}) =>
      table[key] ?? key;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// [FakeLocalization]'ı service locator'a kaydet (öncekini değiştirerek).
void registerFakeLocalization([Map<String, String> table = const {}]) {
  if (sl.isRegistered<LocalizationService>()) {
    sl.unregister<LocalizationService>();
  }
  sl.registerSingleton<LocalizationService>(FakeLocalization(table));
}

/// Canlı-DB biçiminde CRM durum tanımı satırı (kiracı satırı, metadata.i18n).
Map<String, dynamic> statusRow(String code,
        {int sort = 10,
        bool isFinal = false,
        bool isSystem = false,
        String? color = '#3B82F6',
        String? name}) =>
    {
      'code': code,
      'name': name ?? code[0].toUpperCase() + code.substring(1),
      'color': color,
      'is_initial': sort == 10,
      'is_final': isFinal,
      'sort_order': sort,
      'is_system': isSystem,
      'metadata': {
        'i18n': {'name': 'status.$code'}
      },
    };

/// `status_transitions` satırı (from/to gömülü).
Map<String, dynamic> txRow(String from, String to,
        {List<String>? roles, bool comment = false, bool confirm = false}) =>
    {
      'required_roles': roles,
      'requires_comment': comment,
      'requires_confirmation': confirm,
      'from_status': {'code': from},
      'to_status': {'code': to},
    };
