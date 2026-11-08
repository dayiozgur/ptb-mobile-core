import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import 'fixflow_status_service.dart';
import 'fixflow_ticket_service.dart';
import 'fixflow_work_request_service.dart';

/// FixFlow servis erişimi — `service_locator.dart`'a dokunmadan, ilk
/// kullanımda `sl<SupabaseClient>()` ile tembel kurulur. Testler [override]
/// ile sahte servis verir; [reset] ile temizler.
class FixflowServices {
  FixflowServices._();

  static FixflowStatusService? _status;
  static FixflowTicketService? _tickets;
  static FixflowWorkRequestService? _workRequests;

  static SupabaseClient get _client => sl<SupabaseClient>();

  static FixflowStatusService get status =>
      _status ??= FixflowStatusService(supabase: _client);

  static FixflowTicketService get tickets =>
      _tickets ??= FixflowTicketService(supabase: _client);

  static FixflowWorkRequestService get workRequests =>
      _workRequests ??= FixflowWorkRequestService(supabase: _client);

  /// Test/özel kurulum için servisleri değiştir (verilmeyenler korunur).
  static void override({
    FixflowStatusService? status,
    FixflowTicketService? tickets,
    FixflowWorkRequestService? workRequests,
  }) {
    if (status != null) _status = status;
    if (tickets != null) _tickets = tickets;
    if (workRequests != null) _workRequests = workRequests;
  }

  /// Tüm örnekleri bırak (oturum/tenant değişimi, testler).
  static void reset() {
    _status = null;
    _tickets = null;
    _workRequests = null;
  }
}
