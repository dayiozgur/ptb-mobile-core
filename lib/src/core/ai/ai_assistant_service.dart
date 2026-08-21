import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../platform/platform_context.dart';
import '../utils/logger.dart';
import 'ai_models.dart';

/// Web portalındaki AI asistanının mobil istemcisi.
///
/// `ai-assistant` Edge Function'ı AYNI Supabase projesindedir; `supabase_flutter`
/// `functions.invoke` çağrısı JWT'yi otomatik ekler → tenant/RLS kapsamı web ile
/// birebir aynıdır. Streaming YOK; düz JSON yanıt.
///
/// Ctor stili [notification_service.dart] ile aynıdır (named `supabase`).
class AiAssistantService {
  final SupabaseClient _supabase;

  static const String _functionName = 'ai-assistant';

  /// Sağlayıcı yapılandırılmadığında EF'in döndürdüğü kod.
  static const String _noLlmKeyCode = 'ERR_NO_LLM_KEY';

  AiAssistantService({required SupabaseClient supabase}) : _supabase = supabase;

  /// AI asistanına bir mesaj gönderir ve yanıtı döndürür.
  ///
  /// [conversationId] verilirse sohbet sürekliliği korunur. [platformCode]
  /// verilmezse `PlatformContext.activePlatformCode` üzerinden çözülür.
  ///
  /// Hata durumunda çökmez; kullanıcıya gösterilebilir Türkçe bir mesaj taşıyan
  /// `AiAnswer.error(...)` döndürür (isError = true).
  Future<AiAnswer> send(
    String message, {
    String? conversationId,
    bool useRag = true,
    String? platformCode,
  }) async {
    final resolvedPlatform = platformCode ?? _resolvePlatformCode();

    try {
      final response = await _supabase.functions.invoke(
        _functionName,
        body: {
          'message': message,
          if (conversationId != null) 'conversation_id': conversationId,
          'use_rag': useRag,
          if (resolvedPlatform != null) 'platform_code': resolvedPlatform,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        // EF 200 içinde hata kodu döndürebilir.
        if (data['code'] == _noLlmKeyCode) {
          return AiAnswer.error(_noLlmKeyMessage, conversationId: conversationId);
        }
        return AiAnswer.fromJson(data);
      }
      if (data is Map) {
        return AiAnswer.fromJson(Map<String, dynamic>.from(data));
      }

      Logger.warning('ai-assistant beklenmeyen gövde döndürdü: $data');
      return AiAnswer.error(_genericErrorMessage, conversationId: conversationId);
    } on FunctionException catch (e) {
      // functions.invoke, 2xx OLMAYAN her yanıtı FunctionException olarak FIRLATIR.
      // EF gövdesi application/json olduğundan `e.details` çözülmüş bir Map'tir:
      // { error, code } alanlarını buradan okuyup GERÇEK nedeni görünür kıl.
      final detail = _detailsFromFunctionError(e);
      if (detail.code == _noLlmKeyCode || e.status == 503) {
        Logger.warning('ai-assistant: LLM sağlayıcı yapılandırılmamış (503)');
        return AiAnswer.error(_noLlmKeyMessage, conversationId: conversationId);
      }
      Logger.error(
        'ai-assistant çağrısı başarısız — status ${e.status}'
        '${detail.code != null ? ', code ${detail.code}' : ''}'
        '${detail.message != null ? ', ${detail.message}' : ''}',
      );
      return AiAnswer.error(
        _diagnosticMessage(status: e.status, code: detail.code, serverMessage: detail.message),
        conversationId: conversationId,
      );
    } catch (e) {
      Logger.error('ai-assistant çağrısı başarısız (beklenmeyen)', e);
      return AiAnswer.error(_genericErrorMessage, conversationId: conversationId);
    }
  }

  /// Onay bekleyen (staged) bir yazma eylemini onaylar veya iptal eder.
  ///
  /// [decision] `'confirm'` veya `'cancel'` olmalıdır.
  Future<AiActionResult> confirmAction(
    String requestId,
    String decision, {
    String? conversationId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        _functionName,
        body: {
          'mode': 'confirm_action',
          'request_id': requestId,
          'decision': decision,
          if (conversationId != null) 'conversation_id': conversationId,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AiActionResult.fromJson(data);
      }
      if (data is Map) {
        return AiActionResult.fromJson(Map<String, dynamic>.from(data));
      }

      Logger.warning('confirm_action beklenmeyen gövde döndürdü: $data');
      return AiActionResult.error(_genericErrorMessage);
    } on FunctionException catch (e) {
      Logger.error('confirm_action başarısız (status ${e.status})');
      return AiActionResult.error(_genericErrorMessage);
    } catch (e) {
      Logger.error('confirm_action başarısız', e);
      return AiActionResult.error(_genericErrorMessage);
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  String? _resolvePlatformCode() {
    try {
      return sl<PlatformContext>().activePlatformCode;
    } catch (_) {
      // PlatformContext kayıtlı değilse (ör. test) sessizce atla.
      return null;
    }
  }

  /// FunctionException gövdesinden EF'in `code` ve `error` alanlarını çıkarır.
  ///
  /// EF tüm hataları `application/json` `{ error, code }` gövdesiyle döndürür ve
  /// `functions.invoke` bunu çözerek `e.details`'e (Map) koyar. Bazı ağ geçidi
  /// hatalarında düz metin de gelebileceğinden String duruma da toleranslıdır.
  ({String? code, String? message}) _detailsFromFunctionError(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final code = details['code'];
      final err = details['error'] ?? details['message'];
      return (
        code: code is String ? code : null,
        message: err is String ? err : null,
      );
    }
    if (details is String && details.isNotEmpty) {
      return (code: null, message: details);
    }
    return (code: null, message: null);
  }

  /// Kullanıcıya gösterilebilir ama TANILANABILIR bir hata mesajı üretir:
  /// EF'in gerçek kodu/mesajı ve HTTP durumu görünür kalır (jenerik yutma yerine).
  String _diagnosticMessage({required int status, String? code, String? serverMessage}) {
    final parts = <String>[
      if (code != null && code.isNotEmpty) code,
      if (serverMessage != null && serverMessage.isNotEmpty) serverMessage,
      'HTTP $status',
    ];
    return 'AI asistanına ulaşılamadı (${parts.join(' · ')}). Lütfen tekrar deneyin.';
  }

  static const String _noLlmKeyMessage =
      'AI şu an kullanılamıyor. Lütfen daha sonra tekrar deneyin.';

  static const String _genericErrorMessage =
      'AI asistanına ulaşılamadı. Lütfen tekrar deneyin.';
}
