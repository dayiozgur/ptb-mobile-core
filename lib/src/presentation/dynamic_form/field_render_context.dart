import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

/// Bir alanın değeri değiştiğinde çağrılan callback.
///
/// Emit edilen değerin tipi alan tipine göre sözleşmelidir (bkz. `FieldWidget`
/// dokümanı): text ailesi→String, number/currency/percentage→num,
/// date/datetime→ISO-8601 String, checkbox→bool, select/radio→seçenek değeri,
/// multiselect→List, lookup→Map `{entityId, displayValue}`.
typedef FieldValueChanged = void Function(dynamic value);

/// Bir alan widget'ına render için gereken her şeyi taşıyan sözleşme.
///
/// Form container (state sahibi) bu context'i oluşturur ve her alan widget'ına
/// verir. Widget'lar STATE TUTMAZ: `value`'yu render eder, değişiklikleri
/// `onChanged` ile bildirir.
class FieldRenderContext {
  /// Render edilecek alanın tanımı.
  final FormField field;

  /// Alanın mevcut değeri (container'ın sahip olduğu form state'inden).
  final dynamic value;

  /// Değer değiştiğinde çağrılır.
  final FieldValueChanged onChanged;

  /// Doğrulama hata metni (varsa) — container tarafından sağlanır.
  final String? errorText;

  /// Alan etkileşilebilir mi? Readonly / görüntüleme modunda `false`.
  final bool enabled;

  /// Tüm mevcut form değerleri (dependsOn / kaskad bağımlılıklar için).
  final Map<String, dynamic> formValues;

  const FieldRenderContext({
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.formValues = const {},
  });
}

/// Tek bir alan tipini render eden widget'ların temel sınıfı.
///
/// Registry'de tip başına tek (const) örnek tutulur; `build` her render'da
/// yeni bir [FieldRenderContext] alır.
abstract class FieldWidget {
  const FieldWidget();

  /// Yalnızca görüntüleme amaçlı mı (heading / divider gibi, değeri yok)?
  bool get isDisplayOnly => false;

  /// Alanı verilen context ile render et.
  Widget build(BuildContext context, FieldRenderContext ctx);
}
