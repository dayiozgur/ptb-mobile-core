import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Hesap → Krediler görüntüleyici (salt-okuma). Web kredi sayfasının mobil
/// karşılığı: bakiye kartı (kullanılabilir / toplam / kullanılan) + kredi
/// hareketleri listesi. **Satın alma YOK** (mobilde yasak).
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  CreditBalance? _balance;
  List<CreditTransaction> _transactions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        accountService.creditBalance(),
        accountService.creditTransactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = results[0] as CreditBalance?;
        _transactions = results[1] as List<CreditTransaction>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Krediler yüklenemedi';
        _loading = false;
      });
    }
  }

  String _fmtNum(num n) {
    final s = n.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  String _kindLabel(String? kind) {
    switch (kind) {
      case 'purchase':
        return 'Satın alma';
      case 'bonus':
        return 'Bonus';
      case 'refund':
        return 'İade';
      case 'quota_upgrade':
        return 'Kota yükseltme';
      case null:
      case '':
        return 'Hareket';
      default:
        return kind
            .split('_')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Krediler',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(onRefresh: _load, child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null) {
      return AppErrorView(message: _error!, onRetry: _load);
    }

    final b = _balance;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _buildBalanceCard(context, b),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Hareketler',
          style: AppTypography.subhead.copyWith(
            color: AppColors.secondaryLabel(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_transactions.isEmpty)
          const AppEmptyState(
            icon: Icons.history_outlined,
            title: 'Kredi hareketi yok',
          )
        else
          AppCard(
            child: Column(
              children: [
                for (int i = 0; i < _transactions.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: AppColors.separator(context)),
                  _buildTxRow(context, _transactions[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context, CreditBalance? b) {
    final available = b?.availableCredits ?? 0;
    final total = b?.totalCredits ?? 0;
    final used = b?.usedCredits ?? 0;
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Kullanılabilir Bakiye',
            style: AppTypography.caption1
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtNum(available),
            style: AppTypography.title1.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _stat(context, 'Toplam', _fmtNum(total))),
              Container(
                width: 1,
                height: 32,
                color: AppColors.separator(context),
              ),
              Expanded(child: _stat(context, 'Kullanılan', _fmtNum(used))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption1
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
      ],
    );
  }

  Widget _buildTxRow(BuildContext context, CreditTransaction tx) {
    final positive = tx.amount >= 0;
    final amountColor =
        positive ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final sign = positive ? '+' : '−';
    final abs = tx.amount.abs();
    return AppListTile(
      title: _kindLabel(tx.kind),
      subtitle: (tx.description != null && tx.description!.isNotEmpty)
          ? '${tx.description}\n${_fmtDate(tx.createdAt)}'
          : _fmtDate(tx.createdAt),
      showDivider: false,
      trailing: Text(
        '$sign${_fmtNum(abs)}',
        style: AppTypography.body
            .copyWith(color: amountColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}
