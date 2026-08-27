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
      _openForm(result);
      return;
    }

    // Onay/düzeltme adımı: okunan alanları (düşük-güven kırmızı işaretli)
    // forma aktarmadan ÖNCE kullanıcı kontrol edip düzeltir (kartvizit paritesi).
    final reviewed = await showModalBottomSheet<ReceiptScanResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReceiptReviewSheet(result: result!),
    );
    if (!mounted || reviewed == null) return; // iptal → forma gitme
    _openForm(reviewed);
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

/// Fiş/fatura OCR sonucunu forma aktarmadan ÖNCE gösteren onay/düzeltme sheet'i
/// (kartvizit `_QuickAddSheet` paritesi). Düşük-güvenle okunan alanlar (fieldConf
/// < eşik) kırmızı işaretli; kullanıcı düzeltir → düzeltilmiş [ReceiptScanResult]
/// döner (iptal → null). Ham OCR metni genişletilebilir bölümde görünür.
class _ReceiptReviewSheet extends StatefulWidget {
  final ReceiptScanResult result;
  const _ReceiptReviewSheet({required this.result});

  @override
  State<_ReceiptReviewSheet> createState() => _ReceiptReviewSheetState();
}

class _ReceiptReviewSheetState extends State<_ReceiptReviewSheet> {
  late final _merchant =
      TextEditingController(text: widget.result.merchant ?? '');
  late final _total = TextEditingController(
      text: widget.result.total?.toStringAsFixed(2) ?? '');
  late final _date = TextEditingController(text: widget.result.date ?? '');
  late final _taxNo =
      TextEditingController(text: widget.result.taxNumber ?? '');

  @override
  void dispose() {
    _merchant.dispose();
    _total.dispose();
    _date.dispose();
    _taxNo.dispose();
    super.dispose();
  }

  bool _low(String key) => (widget.result.fieldConfidence[key] ?? 1.0) < 0.6;

  void _apply() {
    final r = widget.result;
    final t = _total.text.trim().replaceAll(',', '.');
    Navigator.of(context).pop(ReceiptScanResult(
      merchant: _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
      total: t.isEmpty ? null : double.tryParse(t),
      date: _date.text.trim().isEmpty ? null : _date.text.trim(),
      taxNumber: _taxNo.text.trim().isEmpty ? null : _taxNo.text.trim(),
      subTotal: r.subTotal,
      vatLines: r.vatLines,
      time: r.time,
      documentNo: r.documentNo,
      rawText: r.rawText,
      fieldConfidence: r.fieldConfidence,
      warnings: r.warnings,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.receipt_long_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(essT('expense.review_title', 'Okunan Fiş Bilgileri'),
                  style: AppTypography.headline),
            ]),
            const SizedBox(height: 2),
            Text(
                essT('expense.review_hint',
                    'Bilgileri kontrol edip düzeltin. Kırmızı alanlar düşük güvenle okundu.'),
                style: AppTypography.caption1
                    .copyWith(color: AppColors.secondaryLabel(context))),
            const SizedBox(height: AppSpacing.md),
            _field(_merchant, essT('expense.f_merchant', 'İşletme'),
                _low('merchant')),
            const SizedBox(height: AppSpacing.sm),
            _field(_total, essT('expense.f_total', 'Tutar'), _low('total'),
                numeric: true),
            const SizedBox(height: AppSpacing.sm),
            _field(_date, essT('expense.f_date', 'Tarih (yyyy-AA-gg)'),
                _low('date')),
            const SizedBox(height: AppSpacing.sm),
            _field(_taxNo, essT('expense.f_taxno', 'VKN / TCKN'),
                _low('taxNumber')),
            if (r.warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final w in r.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 15, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(w,
                            style: AppTypography.caption1
                                .copyWith(color: AppColors.warning))),
                  ]),
                ),
            ],
            if (r.rawText.trim().isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(essT('expense.raw_text', 'Okunan ham metin'),
                      style: AppTypography.footnote),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface(Theme.of(context).brightness),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Text(r.rawText, style: AppTypography.caption1),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _apply,
              child: Text(essT('expense.to_form', 'Forma Aktar')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, bool low,
      {bool numeric = false}) {
    return TextField(
      controller: c,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: low ? '⚠ $label' : label,
        isDense: true,
        border: const OutlineInputBorder(),
        enabledBorder: low
            ? const OutlineInputBorder(borderSide: BorderSide(color: AppColors.error))
            : const OutlineInputBorder(),
        helperText:
            low ? essT('expense.low_conf', 'Düşük güven — kontrol edin') : null,
        helperStyle: low ? const TextStyle(color: AppColors.error) : null,
      ),
    );
  }
}
