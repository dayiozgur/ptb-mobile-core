import 'dart:async';

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Web portalın GLOBAL ARAMA deneyiminin mobil karşılığı.
///
/// Tüm varlık türlerinde (form/entity, ticket, tesis, controller, sağlayıcı,
/// kişi, personel) tek kutudan arama yapar. Sunucu tarafındaki
/// `fn_universal_search` SECURITY-DEFINER RPC'sini [SearchService.globalSearch]
/// üzerinden çağırır — tenant sunucuda `get_my_tenant_id()` ile türetilir,
/// istemci tenant GÖNDERMEZ.
///
/// Sonuçlar `source` (kaynak tür) alanına göre gruplanıp etiketlenir. Bir
/// isabete dokununca:
/// - `form`/entity isabetleri → ilgili entity liste ekranı ([ScreenResolver]).
/// - Diğer kaynaklar → temiz bir mobil rota yoksa "yakında" SnackBar'ı.
///
/// KRİTİK: Sonuçlar daima bir [ListView] içinde render edilir; kaydırılabilir
/// alan içine sınırsız-yükseklikli Flex konmaz (geçersiz constraint → boş ekran).
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  String _term = '';
  bool _loading = false;
  List<GlobalSearchHit> _hits = [];

  /// Debounce süresi (~300ms).
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  /// Kaynak tür → Türkçe etiket.
  static const Map<String, String> _sourceLabels = {
    'form': 'Kayıtlar',
    'ticket': 'Talepler',
    'site': 'Tesisler',
    'controller': 'Kontrolörler',
    'provider': 'Sağlayıcılar',
    'contact': 'Kişiler',
    'staff': 'Personel',
  };

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _term = value;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _runSearch(value));
    // Kutu temizlenince sonuçları anında düşür.
    if (value.trim().length < 2 && _hits.isNotEmpty) {
      setState(() => _hits = []);
    }
  }

  Future<void> _runSearch(String value) async {
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      if (mounted) setState(() => _hits = []);
      return;
    }

    setState(() => _loading = true);
    final results = await sl<SearchService>().globalSearch(trimmed);

    // Kutu içeriği bu istekten sonra değiştiyse (yarış) sonucu yok say.
    if (!mounted || _term.trim() != trimmed) return;
    setState(() {
      _hits = results;
      _loading = false;
    });
  }

  /// Kaynak türü için leading ikon.
  IconData _iconFor(String source) {
    switch (source) {
      case 'site':
        return Icons.location_on_outlined;
      case 'controller':
        return Icons.memory_outlined;
      case 'provider':
        return Icons.apartment_outlined;
      case 'staff':
      case 'contact':
        return Icons.person_outline;
      case 'ticket':
        return Icons.receipt_long_outlined;
      case 'form':
        return Icons.description_outlined;
      default:
        return Icons.search;
    }
  }

  String _labelFor(String source) =>
      _sourceLabels[source] ?? (source.isEmpty ? 'Diğer' : source);

  void _onTapHit(GlobalSearchHit hit) {
    // Entity/form isabetleri → entity liste ekranı (v1: ilgili tipin listesi).
    final type = hit.entityType;
    if (hit.source == 'form' && type != null && type.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScreenResolver.resolve(
            MenuItem(
              itemKey: '',
              title: hit.title,
              path: '/entities/$type',
            ),
          ),
        ),
      );
      return;
    }

    // Diğer kaynaklar için temiz bir mobil rota yok — çökmeden bilgilendir.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu sonuç türü mobilde yakında')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Ara',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: AppSearchField(
              controller: _controller,
              autofocus: true,
              placeholder: 'Ara...',
              onChanged: _onChanged,
              onClear: () => _onChanged(''),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _hits.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_hits.isEmpty) {
      final hasQuery = _term.trim().length >= 2;
      return Center(
        child: AppEmptyState(
          icon: hasQuery ? Icons.search_off_outlined : Icons.search,
          title: hasQuery ? 'Sonuç yok' : 'Aramak için yazın',
          message: hasQuery
              ? 'Farklı bir anahtar kelime deneyin.'
              : 'Tesis, kayıt, kişi ve daha fazlasında arayın.',
        ),
      );
    }

    // Kaynak türüne göre grupla (RPC skor sırasını koruyarak).
    final grouped = <String, List<GlobalSearchHit>>{};
    for (final hit in _hits) {
      grouped.putIfAbsent(hit.source, () => []).add(hit);
    }

    // Düz bir satır listesi kur: her grup için bir başlık + isabetler.
    final rows = <Widget>[];
    grouped.forEach((source, hits) {
      rows.add(_SourceHeader(label: _labelFor(source)));
      for (final hit in hits) {
        rows.add(_HitTile(
          hit: hit,
          icon: _iconFor(hit.source),
          onTap: () => _onTapHit(hit),
        ));
      }
    });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}

/// Grup başlığı (kaynak tür etiketi).
class _SourceHeader extends StatelessWidget {
  final String label;

  const _SourceHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption1.copyWith(
          color: AppColors.secondaryLabel(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Tek arama isabeti satırı.
class _HitTile extends StatelessWidget {
  final GlobalSearchHit hit;
  final IconData icon;
  final VoidCallback onTap;

  const _HitTile({
    required this.hit,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = hit.subtitle;
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
      title: Text(
        hit.title.isNotEmpty ? hit.title : (hit.code ?? '—'),
        style: AppTypography.body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: (subtitle != null && subtitle.isNotEmpty)
          ? Text(
              subtitle,
              style: AppTypography.footnote.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.tertiaryLabel(context),
      ),
      onTap: onTap,
    );
  }
}
