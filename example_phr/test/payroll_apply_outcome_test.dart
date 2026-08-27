import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_phr/features/admin/screens/admin_payroll_runs_screen.dart';

/// `applyAdjustments` (fn_payroll_apply_adjustments) dönüşünün kullanıcı
/// mesajına çevrilmesi — bordro-run detayındaki "Düzeltmeleri uygula"
/// aksiyonunun sonuç sözleşmesi. Saf fonksiyon; çeviri runtime'ı gerekmez.
void main() {
  const success = '{n} düzeltme uygulandı';
  const error = 'Düzeltmeler uygulanamadı';

  test('null (servis hatası) → ok=false + hata metni', () {
    final o = payrollApplyOutcome(null,
        successTemplate: success, errorText: error);
    expect(o.ok, isFalse);
    expect(o.message, error);
  });

  test('adet → ok=true + {n} adetle değiştirilir', () {
    final o = payrollApplyOutcome(4,
        successTemplate: success, errorText: error);
    expect(o.ok, isTrue);
    expect(o.message, '4 düzeltme uygulandı');
  });

  test('sıfır adet → ok=true (0 düzeltme uygulandı)', () {
    final o = payrollApplyOutcome(0,
        successTemplate: success, errorText: error);
    expect(o.ok, isTrue);
    expect(o.message, '0 düzeltme uygulandı');
  });
}
