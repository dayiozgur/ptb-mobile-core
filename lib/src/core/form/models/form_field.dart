// Dinamik Form Alanı (Form Field) modelleri
//
// Low-code builder tarafından tasarlanan form alanlarını temsil eder.
// `form_fields` tablosundaki bir satıra ve onun jsonb alt-yapılarına karşılık gelir.

/// Bir form alanının doğrulama kuralları (validation_rules jsonb).
///
/// Tüm alanlar opsiyoneldir; alan tipine göre yalnızca ilgili olanlar dolar.
class FieldValidation {
  /// Sayısal minimum değer
  final num? min;

  /// Sayısal maksimum değer
  final num? max;

  /// Minimum karakter uzunluğu
  final int? minLength;

  /// Maksimum karakter uzunluğu
  final int? maxLength;

  /// Regex deseni
  final String? regex;

  /// Regex ihlali mesajı
  final String? regexMessage;

  /// Minimum eleman sayısı (çoklu seçim vb.)
  final int? minItems;

  /// Maksimum eleman sayısı
  final int? maxItems;

  /// Minimum tarih (ISO string)
  final String? minDate;

  /// Maksimum tarih (ISO string)
  final String? maxDate;

  /// İzin verilen MIME tipleri (dosya alanları)
  final List<String>? allowedMimeTypes;

  /// Maksimum dosya boyutu (bytes)
  final num? maxFileSize;

  /// Özel kural (serbest form)
  final dynamic custom;

  const FieldValidation({
    this.min,
    this.max,
    this.minLength,
    this.maxLength,
    this.regex,
    this.regexMessage,
    this.minItems,
    this.maxItems,
    this.minDate,
    this.maxDate,
    this.allowedMimeTypes,
    this.maxFileSize,
    this.custom,
  });

  factory FieldValidation.fromJson(Map<String, dynamic> json) {
    return FieldValidation(
      min: json['min'] as num?,
      max: json['max'] as num?,
      minLength: (json['minLength'] as num?)?.toInt(),
      maxLength: (json['maxLength'] as num?)?.toInt(),
      regex: json['regex'] as String?,
      regexMessage: json['regexMessage'] as String?,
      minItems: (json['minItems'] as num?)?.toInt(),
      maxItems: (json['maxItems'] as num?)?.toInt(),
      minDate: json['minDate'] as String?,
      maxDate: json['maxDate'] as String?,
      allowedMimeTypes: json['allowedMimeTypes'] != null
          ? List<String>.from(json['allowedMimeTypes'] as List)
          : null,
      maxFileSize: json['maxFileSize'] as num?,
      custom: json['custom'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min': min,
      'max': max,
      'minLength': minLength,
      'maxLength': maxLength,
      'regex': regex,
      'regexMessage': regexMessage,
      'minItems': minItems,
      'maxItems': maxItems,
      'minDate': minDate,
      'maxDate': maxDate,
      'allowedMimeTypes': allowedMimeTypes,
      'maxFileSize': maxFileSize,
      'custom': custom,
    };
  }
}

/// Statik seçenek listesindeki tek bir seçenek.
class FieldOption {
  /// Kaydedilen değer
  final dynamic value;

  /// Görünen etiket
  final String label;

  /// Opsiyonel ikon
  final String? icon;

  /// Devre dışı mı?
  final bool disabled;

  const FieldOption({
    required this.value,
    required this.label,
    this.icon,
    this.disabled = false,
  });

  factory FieldOption.fromJson(Map<String, dynamic> json) {
    return FieldOption(
      value: json['value'],
      label: json['label'] as String? ?? json['value']?.toString() ?? '',
      icon: json['icon'] as String?,
      disabled: json['disabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
      'icon': icon,
      'disabled': disabled,
    };
  }
}

/// Bir lookup alanının başka bir alana bağımlılığı (cascading select).
class FieldDependsOn {
  /// Bağımlı olunan kaynak alanın kodu
  final String fieldCode;

  /// Lookup tablosunda filtrelenecek kolon
  final String filterColumn;

  const FieldDependsOn({
    required this.fieldCode,
    required this.filterColumn,
  });

  factory FieldDependsOn.fromJson(Map<String, dynamic> json) {
    return FieldDependsOn(
      fieldCode: json['fieldCode'] as String? ?? '',
      filterColumn: json['filterColumn'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fieldCode': fieldCode,
      'filterColumn': filterColumn,
    };
  }
}

/// Bir form alanının seçenek yapılandırması (options jsonb).
///
/// [type] 'static' ise [items] doludur; 'lookup' ise [table] üzerinden
/// dinamik sorgu yapılır; 'characteristic' ise [characteristicId] kullanılır.
class FieldOptions {
  /// Seçenek kaynağı tipi: 'static' | 'lookup' | 'characteristic'
  final String type;

  /// Statik seçenekler (type == 'static')
  final List<FieldOption> items;

  /// Lookup tablosu (type == 'lookup')
  final String? table;

  /// Değer kolonu (varsayılan 'id')
  final String? valueField;

  /// Etiket kolonu (varsayılan 'name')
  final String? labelField;

  /// Statik ek filtreler
  final Map<String, dynamic>? filters;

  /// Arama yapılacak kolonlar
  final List<String>? searchFields;

  /// Sıralama kolonu
  final String? orderBy;

  /// Başka bir alana kaskad bağımlılık
  final FieldDependsOn? dependsOn;

  /// Karakteristik listesi kimliği (type == 'characteristic')
  final String? characteristicId;

  /// Liste kategorisi
  final String? listCategory;

  const FieldOptions({
    this.type = 'static',
    this.items = const [],
    this.table,
    this.valueField,
    this.labelField,
    this.filters,
    this.searchFields,
    this.orderBy,
    this.dependsOn,
    this.characteristicId,
    this.listCategory,
  });

  factory FieldOptions.fromJson(Map<String, dynamic> json) {
    return FieldOptions(
      type: json['type'] as String? ?? 'static',
      items: json['items'] != null
          ? (json['items'] as List)
              .map((e) => FieldOption.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      table: json['table'] as String?,
      valueField: json['valueField'] as String?,
      labelField: json['labelField'] as String?,
      filters: json['filters'] as Map<String, dynamic>?,
      searchFields: json['searchFields'] != null
          ? List<String>.from(json['searchFields'] as List)
          : null,
      orderBy: json['orderBy'] as String?,
      dependsOn: json['dependsOn'] != null
          ? FieldDependsOn.fromJson(json['dependsOn'] as Map<String, dynamic>)
          : null,
      characteristicId: json['characteristicId'] as String?,
      listCategory: json['listCategory'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'items': items.map((e) => e.toJson()).toList(),
      'table': table,
      'valueField': valueField,
      'labelField': labelField,
      'filters': filters,
      'searchFields': searchFields,
      'orderBy': orderBy,
      'dependsOn': dependsOn?.toJson(),
      'characteristicId': characteristicId,
      'listCategory': listCategory,
    };
  }

  /// Statik seçenek mi?
  bool get isStatic => type == 'static';

  /// Lookup (dinamik tablo) mı?
  bool get isLookup => type == 'lookup';

  /// Karakteristik listesi mi?
  bool get isCharacteristic => type == 'characteristic';
}

/// Dinamik Form Alanı (Form Field).
///
/// Bir form şablonundaki tek bir girdiyi temsil eder. Alan tipi [fieldType]
/// ile belirlenir (30 tip destekli — text, select, lookup, signature vb.).
class FormField {
  /// Benzersiz ID
  final String id;

  /// Bağlı olduğu bölüm (form_sections) ID
  final String formSectionId;

  /// Şablon içinde benzersiz alan kodu (değer anahtarı)
  final String code;

  /// Görünen etiket
  final String label;

  /// Placeholder metni
  final String? placeholder;

  /// Alan tipi (text, number, select, lookup, ...)
  final String fieldType;

  /// Zorunlu mu?
  final bool isRequired;

  /// Salt-okunur mu?
  final bool isReadonly;

  /// Varsayılan değer
  final String? defaultValue;

  /// Doğrulama kuralları
  final FieldValidation validation;

  /// Seçenek yapılandırması
  final FieldOptions options;

  /// Grid genişliği (1-12)
  final int gridSpan;

  /// Sıralama
  final int sortOrder;

  /// İzin verilen roller (null = herkes)
  final List<String>? allowedRoles;

  /// Yardım metni
  final String? helpText;

  const FormField({
    required this.id,
    required this.formSectionId,
    required this.code,
    required this.label,
    this.placeholder,
    this.fieldType = 'text',
    this.isRequired = false,
    this.isReadonly = false,
    this.defaultValue,
    this.validation = const FieldValidation(),
    this.options = const FieldOptions(),
    this.gridSpan = 12,
    this.sortOrder = 0,
    this.allowedRoles,
    this.helpText,
  });

  /// `validation_rules` yalnız obje ise ayrıştırılır (dizi/null → boş).
  static FieldValidation _parseValidation(dynamic raw) {
    if (raw is Map) {
      return FieldValidation.fromJson(Map<String, dynamic>.from(raw));
    }
    return const FieldValidation();
  }

  /// `options` iki şekilde gelebilir: obje `{type,items,...}` VEYA ham dizi
  /// `[{label,value},...]` (web bazı select alanlarını doğrudan dizi saklar —
  /// ör. CRM deal `forecast_category`). Her ikisi de güvenli ayrıştırılır;
  /// aksi halde `List<dynamic> is not a subtype of Map` cast hatası oluşuyordu.
  static FieldOptions _parseOptions(dynamic raw) {
    if (raw is Map) {
      return FieldOptions.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is List) {
      return FieldOptions(
        type: 'static',
        items: raw
            .whereType<Map>()
            .map((e) => FieldOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    return const FieldOptions();
  }

  factory FormField.fromJson(Map<String, dynamic> json) {
    return FormField(
      id: json['id'] as String,
      formSectionId: json['form_section_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      placeholder: json['placeholder'] as String?,
      fieldType: json['field_type'] as String? ?? 'text',
      isRequired: json['is_required'] as bool? ?? false,
      isReadonly: json['is_readonly'] as bool? ?? false,
      defaultValue: json['default_value'] as String?,
      validation: _parseValidation(json['validation_rules']),
      options: _parseOptions(json['options']),
      gridSpan: (json['grid_span'] as num?)?.toInt() ?? 12,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      allowedRoles: json['allowed_roles'] != null
          ? List<String>.from(json['allowed_roles'] as List)
          : null,
      helpText: json['help_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'form_section_id': formSectionId,
      'code': code,
      'label': label,
      'placeholder': placeholder,
      'field_type': fieldType,
      'is_required': isRequired,
      'is_readonly': isReadonly,
      'default_value': defaultValue,
      'validation_rules': validation.toJson(),
      'options': options.toJson(),
      'grid_span': gridSpan,
      'sort_order': sortOrder,
      'allowed_roles': allowedRoles,
      'help_text': helpText,
    };
  }

  @override
  String toString() => 'FormField($code, $fieldType)';
}
