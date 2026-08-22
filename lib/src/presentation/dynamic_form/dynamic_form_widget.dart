import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import 'field_render_context.dart';
import 'field_registry.dart';

/// Bir [FormTemplate]'ten dinamik form üreten container widget.
///
/// State sahibi budur: alan değerlerini (`_values`) ve hata metinlerini
/// (`_errors`) tutar, kural motorunu (`template.rules`) çalıştırır ve her alanı
/// registry'den çözdüğü [FieldWidget] ile render eder. Alan widget'ları state
/// tutmaz; değeri render eder, değişikliği `onChanged` ile bildirir.
///
/// - [initialValues]: düzenleme/görüntüleme için `code → değer` haritası.
/// - [viewMode]: `true` ise salt-okunur, submit butonu gizli.
/// - [submitting]: parent-güdümlü submit spinner'ı.
/// - [onSubmit]: doğrulama geçerse GÖRÜNÜR alanların değerleriyle çağrılır.
class DynamicFormWidget extends StatefulWidget {
  /// Render edilecek form şablonu.
  final FormTemplate template;

  /// Başlangıç değerleri (`code → değer`).
  final Map<String, dynamic>? initialValues;

  /// Salt-okunur görüntüleme modu (submit yok).
  final bool viewMode;

  /// Submit sırasında parent tarafından yönetilen yükleniyor durumu.
  final bool submitting;

  /// Doğrulama geçerse görünür alanların değerleriyle çağrılır.
  final void Function(Map<String, dynamic> values)? onSubmit;

  /// Submit butonu etiketi için i18n anahtarı (varsayılan `common.save`).
  final String submitLabelKey;

  const DynamicFormWidget({
    super.key,
    required this.template,
    this.initialValues,
    this.viewMode = false,
    this.submitting = false,
    this.onSubmit,
    this.submitLabelKey = 'common.save',
  });

  @override
  State<DynamicFormWidget> createState() => _DynamicFormWidgetState();
}

class _DynamicFormWidgetState extends State<DynamicFormWidget> {
  /// Alan değerleri (`code → değer`).
  final Map<String, dynamic> _values = <String, dynamic>{};

  /// Alan hata metinleri (`code → mesaj?`).
  final Map<String, String?> _errors = <String, String?>{};

  /// Kural motorunca gizlenen alan kodları.
  Set<String> _hidden = <String>{};

  /// Kural motorunca dinamik zorunlu/opsiyonel yapılan alanlar.
  Map<String, bool> _dynamicRequired = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _seedValues();
    _applyRules();
  }

  @override
  void didUpdateWidget(covariant DynamicFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template != widget.template ||
        oldWidget.initialValues != widget.initialValues) {
      _values.clear();
      _errors.clear();
      _seedValues();
      _applyRules();
    }
  }

  // ---------------------------------------------------------------------------
  // State tohumlama
  // ---------------------------------------------------------------------------

  /// initialValues + coerce edilmiş field.defaultValue ile _values'ı tohumlar.
  void _seedValues() {
    final initial = widget.initialValues;
    if (initial != null) {
      _values.addAll(initial);
    }
    for (final field in widget.template.allFields) {
      final widgetImpl = resolveFieldWidget(field.fieldType);
      if (widgetImpl.isDisplayOnly) continue;
      if (_values.containsKey(field.code) && _values[field.code] != null) {
        continue;
      }
      final coerced = _coerceDefault(field);
      if (coerced != null) {
        _values[field.code] = coerced;
      }
    }
  }

  /// defaultValue string'ini alan tipine göre coerce eder.
  dynamic _coerceDefault(FormField field) {
    final raw = field.defaultValue;
    if (raw == null || raw.isEmpty) return null;
    switch (field.fieldType) {
      case 'number':
      case 'currency':
      case 'percentage':
        return num.tryParse(raw);
      case 'checkbox':
        final lower = raw.toLowerCase();
        return lower == 'true' || lower == '1' || lower == 'yes';
      case 'multiselect':
        // Virgülle ayrılmış varsayılanları listeye çevir.
        return raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      case 'date':
      case 'datetime':
        // Sembolik "now"/"today" → bugünün ISO tarihi (web builder bunları
        // ön-dolu bekler; ham "now" DateTime.tryParse ile çözülemez → boş açılırdı).
        final lower = raw.toLowerCase();
        if (lower == 'now' || lower == 'today') {
          return DateTime.now().toIso8601String();
        }
        return raw;
      default:
        return raw;
    }
  }

  // ---------------------------------------------------------------------------
  // Alan değişimi
  // ---------------------------------------------------------------------------

  void _onFieldChanged(FormField field, dynamic value) {
    setState(() {
      _values[field.code] = value;
      // Değişen alanın hatasını temizle.
      _errors[field.code] = null;
      // Kaskad/kural yeniden değerlendir.
      _applyRules();
    });
  }

  // ---------------------------------------------------------------------------
  // Kural motoru
  // ---------------------------------------------------------------------------

  /// Tüm kuralları değerlendirip görünürlük/dinamik-zorunluluk haritalarını
  /// yeniden hesaplar ve `value` kurallarını _values'a uygular.
  ///
  /// build() içinde ÇAĞRILMAZ (state mutasyonu içerir); initState ve
  /// _onFieldChanged içinden çağrılır.
  void _applyRules() {
    final hidden = <String>{};
    final dynamicRequired = <String, bool>{};

    for (final rule in widget.template.rules) {
      final target = rule.targetFieldCode;
      if (target == null || target.isEmpty) continue;

      final met = _evaluateCondition(rule);

      switch (rule.ruleType) {
        case 'visibility':
          final desiredVisible = _asBool(rule.action['visible'], true);
          // Koşul sağlanınca istenen görünürlük; sağlanmayınca tersi.
          final visible = met ? desiredVisible : !desiredVisible;
          if (!visible) hidden.add(target);
          break;
        case 'required':
          if (met) {
            dynamicRequired[target] = _asBool(rule.action['required'], true);
          }
          break;
        case 'value':
          if (met && rule.action.containsKey('setValue')) {
            _values[target] = rule.action['setValue'];
          }
          break;
        case 'options_filter':
          // Kapsam dışı — alanı olduğu gibi bırak, çökme.
          break;
        default:
          break;
      }
    }

    _hidden = hidden;
    _dynamicRequired = dynamicRequired;
  }

  /// Bir kuralın koşulunu _values'a karşı değerlendirir.
  ///
  /// Basit koşul `{operator, value}` → kuralın SOURCE alanını test eder.
  /// Bileşik koşul `{type:'and'|'or', conditions:[{field,operator,value}]}` →
  /// listelenen her alanı test eder.
  bool _evaluateCondition(FormFieldRule rule) {
    final condition = rule.condition;
    if (condition.isEmpty) return true;

    final type = condition['type'];
    if (type == 'and' || type == 'or') {
      final rawConditions = condition['conditions'];
      if (rawConditions is! List || rawConditions.isEmpty) return true;
      final results = rawConditions.whereType<Map>().map((c) {
        final field = c['field'] as String?;
        final actual = field != null ? _values[field] : null;
        return _testOperator(
          c['operator'] as String?,
          actual,
          c['value'],
        );
      });
      return type == 'and' ? results.every((r) => r) : results.any((r) => r);
    }

    // Basit koşul: kaynağı test et.
    final actual =
        rule.sourceFieldCode != null ? _values[rule.sourceFieldCode] : null;
    return _testOperator(
      condition['operator'] as String?,
      actual,
      condition['value'],
    );
  }

  /// Tek bir operatörü değerlendirir.
  bool _testOperator(String? operator, dynamic actual, dynamic expected) {
    switch (operator) {
      case 'eq':
        return _eq(actual, expected);
      case 'neq':
        return !_eq(actual, expected);
      case 'in':
        return expected is List && expected.any((e) => _eq(actual, e));
      case 'not_in':
        return !(expected is List && expected.any((e) => _eq(actual, e)));
      case 'gt':
        return _compareNum(actual, expected) > 0;
      case 'gte':
        return _compareNum(actual, expected) >= 0;
      case 'lt':
        return _compareNum(actual, expected) < 0;
      case 'lte':
        return _compareNum(actual, expected) <= 0;
      case 'contains':
        if (actual is List) return actual.any((e) => _eq(e, expected));
        return actual != null &&
            expected != null &&
            actual.toString().contains(expected.toString());
      case 'is_empty':
        return _isEmpty(actual);
      case 'is_not_empty':
        return !_isEmpty(actual);
      default:
        return false;
    }
  }

  bool _eq(dynamic a, dynamic b) {
    if (a == null || b == null) return a == b;
    if (a is num && b is num) return a == b;
    // Tip-toleranslı: '5' == 5, true == 'true' vb.
    return a == b || a.toString() == b.toString();
  }

  /// -1/0/1; num'a çevrilemezse karşılaştırma başarısız sayılır (0 dışı yön).
  int _compareNum(dynamic a, dynamic b) {
    final na = _toNum(a);
    final nb = _toNum(b);
    if (na == null || nb == null) return -2; // hiçbir eşitsizliği geçmez
    return na.compareTo(nb);
  }

  num? _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  bool _asBool(dynamic v, bool fallback) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  bool _isEmpty(dynamic v) {
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is List) return v.isEmpty;
    if (v is Map) return v.isEmpty;
    return false;
  }

  // ---------------------------------------------------------------------------
  // Doğrulama
  // ---------------------------------------------------------------------------

  /// Görünür, display-olmayan alanları doğrular; hata varsa _errors doldurur.
  /// True → geçerli.
  bool _validate() {
    final errors = <String, String?>{};

    for (final field in widget.template.allFields) {
      final widgetImpl = resolveFieldWidget(field.fieldType);
      if (widgetImpl.isDisplayOnly) continue;
      if (_hidden.contains(field.code)) continue;

      final value = _values[field.code];
      final error = _validateField(field, value);
      if (error != null) errors[field.code] = error;
    }

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  String? _validateField(FormField field, dynamic value) {
    final required =
        field.isRequired || (_dynamicRequired[field.code] ?? false);
    // Checkbox: zorunlu ise İŞARETLİ (true) olmalı. Generic _isEmpty(false)=false
    // olduğundan, işaretlenmemiş (false) zorunlu onay kutusu aksi halde hiç
    // zorlanmıyordu (ör. "Doğrulama Yapıldı", "Elektrik kontrol edildi").
    if (field.fieldType == 'checkbox') {
      if (required && value != true) {
        return _t('validation.required', 'Bu alan zorunludur');
      }
      return null;
    }
    if (required && _isEmpty(value)) {
      return _t('validation.required', 'Bu alan zorunludur');
    }
    // Boşsa (ve zorunlu değilse) diğer kuralları atla.
    if (_isEmpty(value)) return null;

    final v = field.validation;

    // Sayısal min/max
    final numValue = _toNum(value);
    if (numValue != null) {
      if (v.min != null && numValue < v.min!) {
        return _t('validation.min', 'En az ${v.min} olmalı');
      }
      if (v.max != null && numValue > v.max!) {
        return _t('validation.max', 'En fazla ${v.max} olmalı');
      }
    }

    // String uzunluk + regex
    if (value is String) {
      if (v.minLength != null && value.length < v.minLength!) {
        return _t('validation.min_length', 'En az ${v.minLength} karakter');
      }
      if (v.maxLength != null && value.length > v.maxLength!) {
        return _t('validation.max_length', 'En fazla ${v.maxLength} karakter');
      }
      if (v.regex != null && v.regex!.isNotEmpty) {
        bool matches;
        try {
          matches = RegExp(v.regex!).hasMatch(value);
        } catch (_) {
          matches = true; // geçersiz regex → doğrulamayı geçir
        }
        if (!matches) {
          return v.regexMessage ??
              _t('validation.pattern', 'Geçersiz format');
        }
      }
    }

    // Liste min/max eleman
    if (value is List) {
      if (v.minItems != null && value.length < v.minItems!) {
        return _t('validation.min_items', 'En az ${v.minItems} seçim');
      }
      if (v.maxItems != null && value.length > v.maxItems!) {
        return _t('validation.max_items', 'En fazla ${v.maxItems} seçim');
      }
    }

    // Tarih min/max (ISO-8601 string)
    if (value is String) {
      final date = DateTime.tryParse(value);
      if (date != null) {
        final minDate =
            v.minDate != null ? DateTime.tryParse(v.minDate!) : null;
        final maxDate =
            v.maxDate != null ? DateTime.tryParse(v.maxDate!) : null;
        if (minDate != null && date.isBefore(minDate)) {
          return _t('validation.min_date', 'Tarih çok erken');
        }
        if (maxDate != null && date.isAfter(maxDate)) {
          return _t('validation.max_date', 'Tarih çok geç');
        }
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  void _handleSubmit() {
    if (widget.submitting) return;
    if (_validate()) {
      widget.onSubmit?.call(_visibleValues());
    }
  }

  /// Görünür, display-olmayan alanların değerlerini toplar (gizli alanlar hariç).
  Map<String, dynamic> _visibleValues() {
    final out = <String, dynamic>{};
    for (final field in widget.template.allFields) {
      final widgetImpl = resolveFieldWidget(field.fieldType);
      if (widgetImpl.isDisplayOnly) continue;
      if (_hidden.contains(field.code)) continue;
      if (_values.containsKey(field.code)) {
        out[field.code] = _values[field.code];
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // i18n yardımcısı
  // ---------------------------------------------------------------------------

  String _t(String key, String fallback) {
    final translated = sl<LocalizationService>().translate(key);
    return translated == key ? fallback : translated;
  }

  // ---------------------------------------------------------------------------
  // Render
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sections = widget.template.sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final section in sections) _buildSection(context, section),
        if (!widget.viewMode && widget.onSubmit != null) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _t(widget.submitLabelKey, 'Kaydet'),
            isLoading: widget.submitting,
            onPressed: widget.submitting ? null : _handleSubmit,
          ),
        ],
      ],
    );
  }

  Widget _buildSection(BuildContext context, FormSection section) {
    final visibleFields = section.fields
        .where((f) => !_hidden.contains(f.code))
        .toList();
    if (visibleFields.isEmpty) return const SizedBox.shrink();

    // Her section beyaz bir yüzeye (card) oturur — aksi halde alanlar gri sayfa
    // zemininde kutu/yüzey olmadan "kayboluyordu". View + edit için evrensel.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (section.title.trim().isNotEmpty) ...[
                AppSectionHeader(
                  title: section.title,
                  subtitle: (section.description != null &&
                          section.description!.trim().isNotEmpty)
                      ? section.description
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              _buildFieldGrid(context, visibleFields),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldGrid(BuildContext context, List<FormField> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        // Dar telefonda temiz döşenmeyen span'ler için tam-genişlik yığma.
        final narrow = maxWidth < 480;
        const spacing = AppSpacing.md;

        double widthFor(FormField field) {
          final widgetImpl = resolveFieldWidget(field.fieldType);
          final span = field.gridSpan.clamp(1, 12);
          if (narrow || widgetImpl.isDisplayOnly || span >= 12) {
            return maxWidth;
          }
          // Boşluğu düş; taşmayı önlemek için hafif pay bırak.
          final raw = maxWidth * (span / 12) - spacing;
          return raw.clamp(0, maxWidth).toDouble();
        }

        return Wrap(
          spacing: spacing,
          runSpacing: AppSpacing.formFieldSpacing,
          children: [
            for (final field in fields)
              SizedBox(
                width: widthFor(field),
                child: _buildField(context, field),
              ),
          ],
        );
      },
    );
  }

  Widget _buildField(BuildContext context, FormField field) {
    final widgetImpl = resolveFieldWidget(field.fieldType);
    // viewMode (detay): basit alanları grey input-kutusu yerine temiz
    // "etiket + değer" olarak göster (input-benzeri gri yüzey kaybolur).
    // Karmaşık/görsel tipler (imza, dosya, resim, konum, rating, qr, barkod,
    // zengin-metin) ve display-only tipler kendi widget'ıyla render edilir.
    if (widget.viewMode &&
        !widgetImpl.isDisplayOnly &&
        _readOnlySimpleTypes.contains(field.fieldType)) {
      return _buildReadOnlyField(context, field);
    }
    return widgetImpl.build(
      context,
      FieldRenderContext(
        field: field,
        value: _values[field.code],
        onChanged: (v) => _onFieldChanged(field, v),
        errorText: _errors[field.code],
        enabled: !widget.viewMode && !field.isReadonly,
        formValues: _values,
      ),
    );
  }

  static const _readOnlySimpleTypes = {
    'text', 'textarea', 'email', 'phone', 'number', 'currency',
    'percentage', 'date', 'datetime', 'select', 'radio', 'multiselect',
    'checkbox', 'lookup', 'url',
  };

  /// Salt-okunur alan gösterimi — etiket (küçük/ikincil) + değer (gövde),
  /// altında ince ayraç. Beyaz kart üstünde temiz okunur; gri input yok.
  Widget _buildReadOnlyField(BuildContext context, FormField field) {
    final display = _readOnlyDisplayValue(field, _values[field.code]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: AppTypography.caption1.copyWith(
              color: AppColors.secondaryLabel(context),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            display.isEmpty ? '—' : display,
            style: AppTypography.body.copyWith(
              color: AppColors.primaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }

  String _readOnlyDisplayValue(FormField field, dynamic value) {
    if (value == null) return '';
    switch (field.fieldType) {
      case 'checkbox':
        return value == true ? 'Evet' : 'Hayır';
      case 'select':
      case 'radio':
        return _optionLabel(field, value) ?? value.toString();
      case 'multiselect':
        if (value is List) {
          return value
              .map((v) => _optionLabel(field, v) ?? v.toString())
              .join(', ');
        }
        return value.toString();
      case 'lookup':
        if (value is Map) {
          final d = value['displayValue'] ?? value['label'] ?? value['name'];
          if (d != null && d.toString().trim().isNotEmpty) return d.toString();
        }
        return value.toString();
      case 'date':
      case 'datetime':
        final d = DateTime.tryParse(value.toString());
        if (d == null) return value.toString();
        return field.fieldType == 'datetime'
            ? AppClock.dateTime(d)
            : AppClock.date(d);
      default:
        return value.toString();
    }
  }

  String? _optionLabel(FormField field, dynamic value) {
    for (final o in field.options.items) {
      if (o.value == value || o.value?.toString() == value?.toString()) {
        return o.label;
      }
    }
    return null;
  }
}
