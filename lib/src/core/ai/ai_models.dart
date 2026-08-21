/// AI Asistanı veri modelleri.
///
/// Web portalındaki `ai-assistant` Edge Function'ının JSON sözleşmesini
/// yansıtır. Tüm `fromJson` fabrikaları eksik/null alanlara toleranslıdır
/// (backend kısmi gövde döndürürse çökme olmaz).
library;

/// LLM token kullanım özeti.
class AiUsage {
  final int inputTokens;
  final int outputTokens;

  const AiUsage({this.inputTokens = 0, this.outputTokens = 0});

  factory AiUsage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AiUsage();
    return AiUsage(
      inputTokens: _asInt(json['input_tokens']),
      outputTokens: _asInt(json['output_tokens']),
    );
  }

  int get totalTokens => inputTokens + outputTokens;
}

/// Kullanıcı onayı bekleyen (staged) yazma eylemi.
///
/// Backend, veriyi değiştirecek bir işlemi doğrudan uygulamak yerine
/// `pending_actions` altında sunar; kullanıcı Onayla/İptal ile karar verir.
class AiPendingAction {
  /// Onay çağrısında `request_id` olarak kullanılan benzersiz kimlik.
  final String id;

  /// Eylem türü anahtarı (ör. `create_ticket`).
  final String actionKey;

  /// Kullanıcıya gösterilecek eylem adı.
  final String name;

  /// İnsan-okunur özet (ne yapılacağını anlatır).
  final String summary;

  /// Eyleme ait parametreler (ham JSON).
  final Map<String, dynamic> params;

  const AiPendingAction({
    required this.id,
    required this.actionKey,
    required this.name,
    required this.summary,
    this.params = const {},
  });

  factory AiPendingAction.fromJson(Map<String, dynamic> json) {
    return AiPendingAction(
      id: (json['id'] ?? json['request_id'] ?? '').toString(),
      actionKey: (json['action_key'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      params: json['params'] is Map
          ? Map<String, dynamic>.from(json['params'] as Map)
          : const {},
    );
  }
}

/// `ai-assistant` sohbet yanıtı.
class AiAnswer {
  final String? conversationId;
  final String answer;
  final String? model;
  final bool ragUsed;
  final List<String> toolsUsed;
  final List<AiPendingAction> pendingActions;
  final AiUsage usage;

  /// İstemci tarafı hata işareti (yanıt bir hatadan üretildiyse true).
  final bool isError;

  const AiAnswer({
    this.conversationId,
    this.answer = '',
    this.model,
    this.ragUsed = false,
    this.toolsUsed = const [],
    this.pendingActions = const [],
    this.usage = const AiUsage(),
    this.isError = false,
  });

  factory AiAnswer.fromJson(Map<String, dynamic> json) {
    return AiAnswer(
      conversationId: json['conversation_id']?.toString(),
      answer: (json['answer'] ?? '').toString(),
      model: json['model']?.toString(),
      ragUsed: json['rag_used'] == true,
      toolsUsed: _asStringList(json['tools_used']),
      pendingActions: _asActionList(json['pending_actions']),
      usage: AiUsage.fromJson(
        json['usage'] is Map
            ? Map<String, dynamic>.from(json['usage'] as Map)
            : null,
      ),
    );
  }

  /// Hata durumundan kullanıcıya gösterilecek bir yanıt üretir.
  factory AiAnswer.error(String message, {String? conversationId}) {
    return AiAnswer(
      conversationId: conversationId,
      answer: message,
      isError: true,
    );
  }

  bool get hasPendingActions => pendingActions.isNotEmpty;
}

/// Staged bir eylemin onaylanması/iptali sonucu.
class AiActionResult {
  final bool success;
  final String? message;
  final String? conversationId;

  /// EF'in döndürdüğü ham sonuç gövdesi.
  final Map<String, dynamic> data;

  const AiActionResult({
    this.success = false,
    this.message,
    this.conversationId,
    this.data = const {},
  });

  factory AiActionResult.fromJson(Map<String, dynamic> json) {
    // Sözleşme esnek: `success` yoksa `error` yokluğundan çıkarım yap.
    final hasError = json['error'] != null;
    return AiActionResult(
      success: json['success'] == true || (!hasError && json.isNotEmpty),
      message: (json['message'] ?? json['answer'] ?? json['error'])?.toString(),
      conversationId: json['conversation_id']?.toString(),
      data: json,
    );
  }

  factory AiActionResult.error(String message) {
    return AiActionResult(success: false, message: message);
  }
}

// ============================================
// HELPERS
// ============================================

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

List<AiPendingAction> _asActionList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => AiPendingAction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  return const [];
}
