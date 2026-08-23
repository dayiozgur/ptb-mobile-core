// Uygulama ikonları üretici v2 — LOGO 3D DETAYINI KORUR.
//
// v1 hatası: logoyu luminance ile düz-beyaz yaptı → 3D gölge kayboldu.
// v2: kaynak ikondaki logo pikselini (beyaz-GRİ gölgeli 3D) OLDUĞU GİBİ korur;
// yalnız ARKA PLANI marka-renginde radyal gradyanla değiştirir.
//
// crm/ppm ORİJİNALLERİ doğru → git-restore edilir (bu script üretmez).
// Yalnız phr (gradyan-bg + 3D logo) ve pms (yeni, crm-logosu + mavi gradyan).
//
// Çalıştır: dart run tool/gen_app_icons.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

// app → {kaynakLogo(1024 png), [gradyan-merkez, gradyan-kenar]}
final jobs = <String, Map<String, dynamic>>{
  // phr: kendi orijinali (3D logo mor-üstünde) → logo korunur, bg gradyan.
  'example_phr': {'src': '/tmp/orig_phr_1024.png', 'grad': [0xFF8B5CF6, 0xFF4C1D95]},
  // pms: crm orijinalinin 3D beyaz logosu → mavi gradyan.
  'example_pms': {'src': '/tmp/orig_crm_1024.png', 'grad': [0xFF2F7BF0, 0xFF11408F]},
};

const sizes = <String, int>{
  'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167, 'Icon-App-1024x1024@1x.png': 1024,
};

int _lerp(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);
double _ease(double d) => math.pow(d.clamp(0.0, 1.0), 1.15).toDouble();

void main() {
  const n = 1024;
  for (final entry in jobs.entries) {
    final app = entry.key;
    final src = img.decodePng(File(entry.value['src'] as String).readAsBytesSync())!;
    final grad = entry.value['grad'] as List<int>;
    final cCenter = grad[0], cEdge = grad[1];
    final cr = (cCenter >> 16) & 0xFF, cg = (cCenter >> 8) & 0xFF, cb = cCenter & 0xFF;
    final er = (cEdge >> 16) & 0xFF, eg = (cEdge >> 8) & 0xFF, eb = cEdge & 0xFF;

    final master = img.Image(width: n, height: n, numChannels: 3);
    final cx = n / 2, cy = n * 0.42;
    final maxR = math.sqrt(cx * cx + (n - cy) * (n - cy));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final p = src.getPixel(x, y);
        final lum255 = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b; // 0..255
        // logo alfa: parlak (beyaz-gri logo) → 1, koyu (bg) → 0. Yumuşak geçiş.
        final a = ((lum255 / 255.0 - 0.5) / 0.28).clamp(0.0, 1.0);
        // arka plan: yeni radyal gradyan
        final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / maxR;
        final t = _ease(d);
        final gr = _lerp(cr, er, t), gg = _lerp(cg, eg, t), gb = _lerp(cb, eb, t);
        // KRİTİK: logo RENGİ DEĞİL, GRİ-TONU (luminance) kullan. Kaynak ikonun
        // kenar anti-alias pikselleri kaynak-BG rengiyle (ör. CRM mavisi)
        // karışıktır → farklı-renk bg'ye taşınınca renk-halo/kirlilik yapıyordu.
        // Gri-ton (R=G=B) hem 3D gölgeyi korur hem renk-kirliliğini giderir.
        final li = lum255.round().clamp(0, 255);
        master.setPixelRgb(
          x, y,
          _lerp(gr, li, a),
          _lerp(gg, li, a),
          _lerp(gb, li, a),
        );
      }
    }

    final outDir = '$app/ios/Runner/Assets.xcassets/AppIcon.appiconset';
    for (final s in sizes.entries) {
      final resized = s.value == n
          ? master
          : img.copyResize(master, width: s.value, height: s.value,
              interpolation: img.Interpolation.average);
      File('$outDir/${s.key}').writeAsBytesSync(img.encodePng(resized));
    }
    stdout.writeln('$app: 15 ikon (logo 3D korundu, bg gradyan)');
  }
  stdout.writeln('BİTTİ');
}
