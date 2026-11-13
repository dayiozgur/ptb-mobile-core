import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/supabase_fakes.dart';

class MockTenantService extends Mock implements TenantService {}

/// Primary-screen reads that used to turn a failure into an empty list now
/// rethrow, so their screens say "could not load" (AsyncView /
/// AppLoadFailedView, no-access aware) instead of "nothing here".
void main() {
  late SupabaseHarness h;

  setUp(() {
    h = SupabaseHarness();
    final tenant = MockTenantService();
    when(() => tenant.currentTenantId).thenReturn('tenant-1');
    final sl = GetIt.instance;
    if (sl.isRegistered<TenantService>()) sl.unregister<TenantService>();
    sl.registerSingleton<TenantService>(tenant);
  });

  tearDown(() => GetIt.instance.reset());

  group('OrgChartService', () {
    test('organizationTree: a failed read throws', () async {
      h.stubFrom('organizations', error: Exception('db down'));
      final svc = OrgChartService(supabase: h.client);
      await expectLater(svc.organizationTree(), throwsException);
    });

    test('departmentTree: a failed read throws', () async {
      h.stubFrom('departments', error: Exception('db down'));
      final svc = OrgChartService(supabase: h.client);
      await expectLater(svc.departmentTree(), throwsException);
    });

    test('an empty tenant is still an empty tree', () async {
      h.stubFrom('organizations', result: <Map<String, dynamic>>[]);
      h.stubFrom('staffs', result: <Map<String, dynamic>>[]);
      final svc = OrgChartService(supabase: h.client);
      expect(await svc.organizationTree(), isEmpty);
    });
  });

  group('AccountService', () {
    test('creditTransactions: a failed read throws', () async {
      h.stubFrom('tenant_credit_transactions', error: Exception('db down'));
      final svc = AccountService(supabase: h.client);
      await expectLater(svc.creditTransactions(), throwsException);
    });

    test('invoices: a failed read throws; the summary still degrades',
        () async {
      h.stubFrom('tenant_invoices', error: Exception('db down'));
      final svc = AccountService(supabase: h.client);
      await expectLater(svc.invoices(), throwsException);
      expect(await svc.invoiceSummary(), isA<InvoiceSummary>());
    });
  });

  group('AiAssistantService.listConversations', () {
    test('a failed read throws (not "no conversations yet")', () async {
      h.stubFrom('ai_conversations', error: Exception('db down'));
      final svc = AiAssistantService(supabase: h.client);
      await expectLater(svc.listConversations(), throwsException);
    });
  });
}
