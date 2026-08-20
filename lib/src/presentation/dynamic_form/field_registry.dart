import 'field_render_context.dart';
import 'fields/choice_fields.dart';
import 'fields/date_fields.dart';
import 'fields/display_fields.dart';
import 'fields/location_field.dart';
import 'fields/lookup_field.dart';
import 'fields/media_fields.dart';
import 'fields/numeric_fields.dart';
import 'fields/range_fields.dart';
import 'fields/rating_field.dart';
import 'fields/signature_field.dart';
import 'fields/text_fields.dart';
import 'fields/time_field.dart';
import 'fields/unsupported_field.dart';

/// Alan tipi → [FieldWidget] eşlemesi.
///
/// Form container `resolveFieldWidget(field.fieldType)` ile bir widget alır ve
/// her render'da yeni bir [FieldRenderContext] geçirerek `build` çağırır.
final Map<String, FieldWidget> kFieldRegistry = <String, FieldWidget>{
  // Metin ailesi
  'text': const TextFieldWidget(),
  'textarea': const TextareaFieldWidget(),
  'email': const EmailFieldWidget(),
  'phone': const PhoneFieldWidget(),
  // Sayısal aile
  'number': const NumberFieldWidget(),
  'currency': const CurrencyFieldWidget(),
  'percentage': const PercentageFieldWidget(),
  // Tarih
  'date': const DateFieldWidget(),
  'datetime': const DateTimeFieldWidget(),
  // Seçim
  'select': const SelectFieldWidget(),
  'radio': const RadioFieldWidget(),
  'checkbox': const CheckboxFieldWidget(),
  'multiselect': const MultiselectFieldWidget(),
  // Dinamik referans
  'lookup': const LookupFieldWidget(),
  // Tarih/saat/aralık
  'daterange': const DateRangeFieldWidget(),
  'time_picker': const TimeFieldWidget(),
  'slider_range': const SliderRangeFieldWidget(),
  // Değerlendirme
  'rating': const RatingFieldWidget(),
  // Konum (geolocator)
  'location': const LocationFieldWidget(),
  'gps_capture': const LocationFieldWidget(),
  // Medya (image_picker / file_picker / signature)
  'image': const ImageFieldWidget(),
  'file': const FileFieldWidget(),
  'signature': const SignatureFieldWidget(),
  // Görüntüleme (değersiz)
  'heading': const HeadingFieldWidget(),
  'divider': const DividerFieldWidget(),
};

/// Verilen alan tipi için widget'ı çöz; tanınmayan tipler için
/// [UnsupportedFieldWidget] döner (file, image, signature, barcode, … gibi
/// mobilde henüz desteklenmeyen ~16 egzotik tip dahil).
FieldWidget resolveFieldWidget(String fieldType) =>
    kFieldRegistry[fieldType] ?? const UnsupportedFieldWidget();
