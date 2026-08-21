import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../../core/ai/ai_assistant_service.dart';
import '../../../core/ai/ai_models.dart';

/// AI Asistanı sohbet ekranı.
///
/// Web portalındaki `ai-assistant` Edge Function'ına bağlanır (JWT otomatik →
/// tenant/RLS kapsamı web ile aynı). Kullanıcı/asistan balonları, alt giriş
/// satırı, "yazıyor" göstergesi ve onay-bekleyen yazma eylemleri için
/// Onayla/İptal kartları içerir.
///
/// LAYOUT KURALI: Kaydırma görünümü içine sınırsız-yükseklikli Flex konmaz.
/// Mesaj listesi bir [ListView]; giriş satırı sınırlı [Column] içinde yer alır.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];

  String? _conversationId;
  bool _sending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================
  // ACTIONS
  // ============================================

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage.user(text));
      _sending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final answer = await sl<AiAssistantService>().send(
      text,
      conversationId: _conversationId,
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      if (answer.conversationId != null) {
        _conversationId = answer.conversationId;
      }
      _messages.add(_ChatMessage.assistant(answer));
    });
    _scrollToBottom();
  }

  Future<void> _decide(
    _ChatMessage message,
    AiPendingAction action,
    String decision,
  ) async {
    setState(() {
      message.resolvedActions.add(action.id);
      _sending = true;
    });

    final result = await sl<AiAssistantService>().confirmAction(
      action.id,
      decision,
      conversationId: _conversationId,
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      final label = decision == 'confirm' ? 'onaylandı' : 'iptal edildi';
      final detail = result.message?.trim();
      final text = (detail != null && detail.isNotEmpty)
          ? detail
          : '${action.name} $label.';
      _messages.add(_ChatMessage.system(text));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'AI Asistan',
      child: Column(
        children: [
          Expanded(child: _buildMessageList(context)),
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    if (_messages.isEmpty && !_sending) {
      return _buildEmptyState(context);
    }

    final itemCount = _messages.length + (_sending ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (_sending && index == _messages.length) {
          return _buildTypingIndicator(context);
        }
        return _buildMessage(context, _messages[index]);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'AI Asistan',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Bir şey sorun…',
              style: TextStyle(color: AppColors.secondaryLabel(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(BuildContext context, _ChatMessage message) {
    if (message.role == _Role.system) {
      return _buildSystemNote(context, message.text);
    }

    final isUser = message.role == _Role.user;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isUser
        ? AppColors.primary
        : AppColors.cardBackground(context);
    final fg = isUser ? Colors.white : AppColors.primaryLabel(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: AppCard(
                variant: isUser
                    ? AppCardVariant.filled
                    : AppCardVariant.outlined,
                backgroundColor: bg,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: message.isError ? AppColors.error : fg,
                  ),
                ),
              ),
            ),
          ),
          if (message.pendingActions.isNotEmpty)
            ...message.pendingActions.map(
              (action) => _buildActionCard(context, message, action),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    _ChatMessage message,
    AiPendingAction action,
  ) {
    final resolved = message.resolvedActions.contains(action.id);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        variant: AppCardVariant.outlined,
        borderColor: AppColors.warning,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, size: 18, color: AppColors.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    action.name.isNotEmpty ? action.name : 'Onay gerekli',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (action.summary.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                action.summary,
                style: TextStyle(color: AppColors.secondaryLabel(context)),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: resolved || _sending
                      ? null
                      : () => _decide(message, action, 'cancel'),
                  child: const Text('İptal'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: resolved || _sending
                      ? null
                      : () => _decide(message, action, 'confirm'),
                  child: const Text('Onayla'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemNote(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.secondaryLabel(context),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AppCard(
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Yazıyor…',
                style: TextStyle(color: AppColors.secondaryLabel(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          border: Border(
            top: BorderSide(color: AppColors.separator(context)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Bir şey sorun…',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: Icon(Icons.send, color: AppColors.primary),
              tooltip: 'Gönder',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// LOCAL CHAT MESSAGE MODEL
// ============================================

enum _Role { user, assistant, system }

class _ChatMessage {
  final _Role role;
  final String text;
  final bool isError;
  final List<AiPendingAction> pendingActions;

  /// Bu mesajdaki, kullanıcının karar verdiği (Onayla/İptal) eylem id'leri.
  final Set<String> resolvedActions = {};

  _ChatMessage._({
    required this.role,
    required this.text,
    this.isError = false,
    this.pendingActions = const [],
  });

  factory _ChatMessage.user(String text) =>
      _ChatMessage._(role: _Role.user, text: text);

  factory _ChatMessage.assistant(AiAnswer answer) => _ChatMessage._(
        role: _Role.assistant,
        text: answer.answer.isNotEmpty
            ? answer.answer
            : (answer.isError
                ? 'AI şu an kullanılamıyor.'
                : 'Yanıt alınamadı.'),
        isError: answer.isError,
        pendingActions: answer.pendingActions,
      );

  factory _ChatMessage.system(String text) =>
      _ChatMessage._(role: _Role.system, text: text);
}
