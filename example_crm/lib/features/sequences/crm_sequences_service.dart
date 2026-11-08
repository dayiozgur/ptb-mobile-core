import '../shared/crm_backend.dart';

/// Satış dizisi özeti (`fn_crm_sequences_list` satırı; `active` dahil —
/// çekirdek `CrmSequence` enroll seçicisi için `active`/pasifleri taşımaz).
class SequenceSummary {
  final String id;
  final String name;
  final String? description;
  final bool active;
  final int stepCount;
  final int activeEnrollments;

  const SequenceSummary({
    required this.id,
    this.name = '',
    this.description,
    this.active = true,
    this.stepCount = 0,
    this.activeEnrollments = 0,
  });

  factory SequenceSummary.fromRow(Map<String, dynamic> r) => SequenceSummary(
        id: r['id']?.toString() ?? '',
        name: (r['name'] as String?) ?? '',
        description: r['description'] as String?,
        active: r['active'] != false,
        stepCount: (r['step_count'] as num?)?.toInt() ?? 0,
        activeEnrollments: (r['active_enrollments'] as num?)?.toInt() ?? 0,
      );
}

/// Bir dizi kaydı (`fn_crm_sequence_enrollments` satırı).
class SequenceEnrollment {
  final String id;
  final String contactName;
  final String status;
  final int currentStep;
  final DateTime? nextActionAt;

  const SequenceEnrollment({
    required this.id,
    this.contactName = '',
    this.status = '',
    this.currentStep = 0,
    this.nextActionAt,
  });

  factory SequenceEnrollment.fromRow(Map<String, dynamic> r) =>
      SequenceEnrollment(
        id: r['id']?.toString() ?? '',
        contactName: (r['contact_name'] as String?) ?? '',
        status: (r['status'] as String?) ?? '',
        currentStep: (r['current_step'] as num?)?.toInt() ?? 0,
        nextActionAt: r['next_action_at'] != null
            ? DateTime.tryParse(r['next_action_at'].toString())
            : null,
      );
}

/// **Satış dizileri (salt-okunur)** — web `SequenceService` ile aynı RPC'ler:
/// `fn_crm_sequences_list()` ve `fn_crm_sequence_enrollments(p_sequence_id,
/// p_contact_id)`. Oluştur/düzenle/durdur mobilde YOK.
class CrmSequencesService {
  CrmSequencesService({CrmBackend? backend})
      : _backend = backend ?? SupabaseCrmBackend();

  final CrmBackend _backend;

  /// Tüm diziler (aktif + pasif) — hata fırlatır.
  Future<List<SequenceSummary>> list() async {
    final rows = await _backend.rpcRows('fn_crm_sequences_list');
    return rows
        .map(SequenceSummary.fromRow)
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  /// Bir dizinin kayıtları — hata fırlatır.
  Future<List<SequenceEnrollment>> enrollments(String sequenceId) async {
    final rows = await _backend.rpcRows('fn_crm_sequence_enrollments',
        {'p_sequence_id': sequenceId, 'p_contact_id': null});
    return rows
        .map(SequenceEnrollment.fromRow)
        .where((e) => e.id.isNotEmpty)
        .toList();
  }
}
