import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Bir entity kaydının **yorum/tartışma thread'i** — listeler + yeni yorum ekler.
/// [CommentsService] sürücüsü; CRM/PPM/tüm entity-engine tiplerinde ortak.
///
/// `entity_detail_screen`'de `config.enableComments` kapılı mount edilir.
class CommentsThread extends StatefulWidget {
  final String entityType;
  final String entityId;

  const CommentsThread({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  @override
  State<CommentsThread> createState() => _CommentsThreadState();
}

class _CommentsThreadState extends State<CommentsThread> {
  CommentsService get _svc => sl<CommentsService>();
  final _ctrl = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  List<EntityComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _svc.list(widget.entityType, widget.entityId);
    if (mounted) {
      setState(() {
        _comments = list;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final added = await _svc.add(widget.entityType, widget.entityId, text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (added != null) {
        _comments = [..._comments, added];
        _ctrl.clear();
      }
    });
    if (added == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yorum eklenemedi.')));
    }
  }

  String _time(DateTime? d) {
    if (d == null) return '';
    final t = AppClock.toTenant(d);
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forum_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('Yorumlar',
                    style: AppTypography.withColor(
                        AppTypography.subhead, AppColors.textPrimary(b))),
                const Spacer(),
                if (!_loading)
                  Text('${_comments.length}',
                      style: AppTypography.withColor(AppTypography.footnote,
                          AppColors.textSecondary(b))),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: AppLoadingIndicator()),
              )
            else if (_comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text('Henüz yorum yok.',
                    style: AppTypography.withColor(AppTypography.footnote,
                        AppColors.textSecondary(b))),
              )
            else
              ..._comments.map((c) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(c.authorName,
                                style: AppTypography.withColor(
                                    AppTypography.caption1,
                                    AppColors.textPrimary(b))),
                            const SizedBox(width: 6),
                            Text(_time(c.createdAt),
                                style: AppTypography.withColor(
                                    AppTypography.caption2,
                                    AppColors.textSecondary(b))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(c.content,
                            style: AppTypography.withColor(
                                AppTypography.footnote,
                                AppColors.textPrimary(b))),
                      ],
                    ),
                  )),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Yorum ekle…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
