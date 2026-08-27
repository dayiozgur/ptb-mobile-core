import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess/ess_common.dart';

/// **Fiş/Fatura Tara → Masraf** — kamera/galeriden fiş/fatura oku (on-device
/// OCR, bulut YOK), Türk fiş alanlarını çıkar, `hr_expense` masraf formunu
/// ön-doldur. Onay/düzeltme gerçek formda yapılır; aritmetik uyarılar form
/// üstünde banner olarak gösterilir (doğruluk için kullanıcı kontrolü şart).
class ScanExpenseScreen extends StatefulWidget {
  const ScanExpenseScreen({super.key});

  @override
  State<ScanExpenseScreen> createState() => _ScanExpenseScreenState();

  /// OCR sonucunu `hr_expense` form alanlarına eşler (title/amount/
  /// expense_date/description). Saf — test edilebilir.
  static Map<String, dynamic> expenseSeed(ReceiptScanResult r) {
    final desc = <String>[];
    if (r.documentNo != null) desc.add('Fiş/Belge No: ${r.documentNo}');
    if (r.taxNumber != null) desc.add('VKN/TCKN: ${r.taxNumber}');
    for (final v in r.vatLines) {
      final rate = v.rate != null ? '%${v.rate}' : 'KDV';
      final amt = v.amount != null ? v.amount!.toStringAsFixed(2) : '';
      desc.add('KDV $rate: $amt');
    }
    if (r.time != null) desc.add('Saat: ${r.time}');
    return <String, dynamic>{
      'title': (r.merchant ?? '').trim().isNotEmpty ? r.merchant : 'Masraf',
      if (r.total != null) 'amount': r.total,
      if (r.date != null) 'expense_date': r.date,
      'description': desc.join(' • '),
    };
  }

  /// Düşük-güvenle okunan alanlar için insan-okunur uyarılar (form üstünde
  /// banner). `fieldConfidence` (0..1) parser'da hesaplanıyordu ama UI'da hiç
  /// gösterilmiyordu — kullanıcı hangi alanı kontrol edeceğini bilsin. Saf.
  static List<String> lowConfidenceNotices(ReceiptScanResult r,
      {double threshold = 0.6}) {
    const labels = <String, String>{
      'total': 'Tutar',
      'subTotal': 'Ara toplam',
      'date': 'Tarih',
      'taxNumber': 'VKN/TCKN',
      'merchant': 'İşletme',
      'documentNo': 'Belge No',
    };
    final out = <String>[];
    r.fieldConfidence.forEach((key, value) {
      if (value < threshold) {
        final label = labels[key] ?? key;
        out.add('$label düşük güvenle okundu — kontrol edin.');
      }
    });
    return out;
  }
}

class _ScanExpenseScreenState extends State<ScanExpenseScreen> {
  bool _busy = false;

  Future<void> _scan(DocumentScanSource source) async {
    setState(() => _busy = true);
    ReceiptScanResult? result;
    try {
      result = await DocumentScanner().scan(source: source);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${essT('expense.scan_error', 'Tarama hatası')}: $e'),
        ));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) return; // iptal

    if (result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(essT('expense.scan_empty',
            'Fiş okunamadı — bilgileri elle girebilirsiniz')),
      ));
    }
    _openForm(result);
  }

  void _openForm(ReceiptScanResult r) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EntityFormScreen(
        typeCode: 'hr_expense',
        seedValues: ScanExpenseScreen.expenseSeed(r),
        // Aritmetik uyarılar + düşük-güven alan uyarıları birlikte (kullanıcı
        // OCR sonucunu güvenle kontrol etsin — kartvizit "kontrol et" paritesi).
        notices: [...r.warnings, ...ScanExpenseScreen.lowConfidenceNotices(r)],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('expense.scan_title', 'Fiş/Fatura Tara'),
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      child: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          AppCard(
            child: Padding(
              padding: AppSpacing.cardInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          color: AppColors.primary, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        essT('expense.scan_hint_title', 'Fişi çerçeveye alın'),
                        style: AppTypography.headline,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    essT('expense.scan_hint',
                        'Tutar, KDV ve tarih otomatik okunur. Cihazda işlenir — '
                        'görüntü sunucuya gönderilmez. Okunanları formda kontrol edin.'),
                    style: AppTypography.footnote.copyWith(
                        color: AppColors.secondaryLabel(context)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: essT('expense.scan_camera', 'Kamera ile Tara'),
            icon: Icons.photo_camera_outlined,
            variant: AppButtonVariant.primary,
            isLoading: _busy,
            onPressed: _busy ? null : () => _scan(DocumentScanSource.camera),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: essT('expense.scan_gallery', 'Galeriden Seç'),
            icon: Icons.photo_library_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : () => _scan(DocumentScanSource.gallery),
          ),
        ],
      ),
    );
  }
}
