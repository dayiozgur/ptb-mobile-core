import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Admin — Hata bildirimi (bug report) görüntüleyici (salt-okuma) servis.
///
/// Web portal `BugReportService.loadReports()` okuma-yolunu aynalar (aynı
/// Supabase projesi, `bug_reports` tablosu). Yazma YOK — v1 salt-okuma liste.
///
/// NOT: `bug_reports` tablosunda ayrı bir `severity` kolonu YOKTUR; şiddet/
/// öncelik `priority` kolonu ile ifade edilir (web de böyle yapar). Raporlayan
/// kişi `profiles!bug_reports_reporter_id_fkey` embed'i ile açık constraint-hint
/// üzerinden çözülür (reporter_id + assignee_id iki profil FK'si belirsizliğe
/// yol açtığından hint zorunludur).
///
/// Tenant/platform kapsamı **RLS** ile sağlanır; en yeni önce sıralanır.
class AdminBugReportService {
  final SupabaseClient _supabase;

  static const String _table = 'bug_reports';

  AdminBugReportService({required SupabaseClient supabase})
      : _supabase = supabase;

  /// Hata bildirimlerini (en yeni önce) getirir. RLS-scoped.
  Future<List<BugReportRow>> listBugReports({int limit = 50}) async {
    try {
      final rows = await _supabase
          .from(_table)
          .select(
            '*, reporter:profiles!bug_reports_reporter_id_fkey'
            '(full_name, username, email)',
          )
          .order('created_at', ascending: false)
          .limit(limit);

      final result = (rows as List)
          .map((e) => BugReportRow.fromJson(e as Map<String, dynamic>))
          .toList();

      Logger.debug('AdminBugReportService.listBugReports → ${result.length}');
      return result;
    } catch (e, st) {
      Logger.error('AdminBugReportService.listBugReports hata', e, st);
      rethrow;
    }
  }
}

/// Hata bildirimi satırı görüntü-modeli (salt-okuma).
class BugReportRow {
  final String id;
  final String? title;
  final String? description;

  /// `open | in_progress | resolved | closed`.
  final String? status;

  /// `low | medium | high | critical` — şiddet/öncelik (severity yerine).
  final String? priority;

  /// `bug | feature | improvement | question` gibi (serbest).
  final String? type;
  final String? category;
  final String? ticketNumber;
  final DateTime? createdAt;

  /// Raporlayan görünen adı (embed profiles).
  final String? reporterName;

  const BugReportRow({
    required this.id,
    this.title,
    this.description,
    this.status,
    this.priority,
    this.type,
    this.category,
    this.ticketNumber,
    this.createdAt,
    this.reporterName,
  });

  static String? _reporterName(dynamic embed) {
    Map<String, dynamic>? m;
    if (embed is Map<String, dynamic>) {
      m = embed;
    } else if (embed is List && embed.isNotEmpty && embed.first is Map) {
      m = (embed.first as Map).cast<String, dynamic>();
    }
    if (m == null) return null;
    final full = (m['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final username = (m['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;
    final email = (m['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return email;
    return null;
  }

  factory BugReportRow.fromJson(Map<String, dynamic> json) {
    return BugReportRow(
      id: json['id'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String?,
      priority: json['priority'] as String?,
      type: json['type'] as String?,
      category: json['category'] as String?,
      ticketNumber: json['ticket_number'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      reporterName: _reporterName(json['reporter']),
    );
  }
}
