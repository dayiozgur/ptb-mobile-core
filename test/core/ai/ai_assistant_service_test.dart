import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_fakes.dart';

void main() {
  late SupabaseHarness h;
  late AiAssistantService service;

  setUp(() {
    h = SupabaseHarness();
    service = AiAssistantService(supabase: h.client);
  });

  group('send (ai-assistant Edge Function)', () {
    test('happy path: parses AiAnswer and sends the expected body', () async {
      h.stubFunction('ai-assistant', data: {
        'conversation_id': 'conv-1',
        'answer': 'Merhaba!',
        'model': 'claude',
        'rag_used': true,
      });

      final answer = await service.send('Selam', conversationId: 'conv-1',
          platformCode: 'PHR');

      expect(answer.isError, isFalse);
      expect(answer.answer, 'Merhaba!');
      expect(answer.conversationId, 'conv-1');
      expect(answer.ragUsed, isTrue);

      final body = h.capturedFunctionBody('ai-assistant')!;
      expect(body['message'], 'Selam');
      expect(body['conversation_id'], 'conv-1');
      expect(body['use_rag'], true);
      expect(body['platform_code'], 'PHR');
    });

    test('conversation_id omitted from body when not provided', () async {
      h.stubFunction('ai-assistant', data: {'answer': 'ok'});

      await service.send('Hi', platformCode: 'PHR');

      final body = h.capturedFunctionBody('ai-assistant')!;
      expect(body.containsKey('conversation_id'), isFalse);
    });

    test('ERR_NO_LLM_KEY code in 200 body maps to a friendly error answer',
        () async {
      h.stubFunction('ai-assistant', data: {'code': 'ERR_NO_LLM_KEY'});

      final answer = await service.send('Hi', platformCode: 'PHR');

      expect(answer.isError, isTrue);
      expect(answer.answer, contains('AI şu an kullanılamıyor'));
    });

    test('unexpected (non-map) body → generic error answer', () async {
      h.stubFunction('ai-assistant', data: 'plain string');

      final answer = await service.send('Hi', platformCode: 'PHR');

      expect(answer.isError, isTrue);
      expect(answer.answer, contains('AI asistanına ulaşılamadı'));
    });

    test('FunctionException 503 → friendly no-LLM-key error (not a throw)',
        () async {
      h.stubFunction('ai-assistant',
          error: const FunctionException(status: 503, details: {'code': 'X'}));

      final answer = await service.send('Hi', platformCode: 'PHR');

      expect(answer.isError, isTrue);
      expect(answer.answer, contains('AI şu an kullanılamıyor'));
    });

    test('FunctionException other status → diagnostic error carrying the code',
        () async {
      h.stubFunction('ai-assistant',
          error: const FunctionException(
              status: 500, details: {'code': 'ERR_X', 'error': 'boom'}));

      final answer = await service.send('Hi', platformCode: 'PHR');

      expect(answer.isError, isTrue);
      expect(answer.answer, contains('ERR_X'));
      expect(answer.answer, contains('HTTP 500'));
    });
  });
}
