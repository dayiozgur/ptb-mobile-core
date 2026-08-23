// Uygulama ikonları üretici — her app için RADYAL GRADYAN (marka rengi) +
// BEYAZ protoolbag logosu. Logo maskesi mevcut CRM ikonundan (beyaz-logo +
// gradyan) luminance ile çıkarılır. 15 iOS boyutu yeniden üretilir.
//
// Çalıştır: dart run tool/gen_app_icons.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

// app → [merkez(parlak), kenar(koyu)] radyal gradyan renkleri (marka temelli).
const apps = <String, List<int>>{
  // hex → 0xAARRGGBB olarak merkez ve kenar
  'example_crm': [0xFF3B82F6, 0xFF1E3A8A], // mavi #2563EB ailesi
  'example_ppm': [0xFF14B8A6, 0xFF0F766E], // teal #0D9488
  'example_phr': [0xFF8B5CF6, 0xFF5B21B6], // mor #7C3AED
  'example_pms': [0xFF3B82F6, 0xFF1C4F9E], // mavi #1C6AE9
};

const sizes = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

const root = 'example_crm/ios/Runner/Assets.xcassets/AppIcon.appiconset';

int _lerp(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);

void main() {
  // 1) CRM ikonundan beyaz-logo alfa maskesi çıkar (1024).
  final srcFile = File('$root/Icon-App-1024x1024@1x.png');
  final src = img.decodePng(srcFile.readAsBytesSync())!;
  const n = 1024;
  // logo alfa: parlak (beyaz logo) → opak; koyu (gradyan bg) → şeffaf.
  final logoAlpha = List<double>.filled(n * n, 0);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final p = src.getPixel(x, y);
      final lum = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
      // 0.55 altını bg say, üstünü logo; yumuşak geçiş.
      final a = ((lum - 0.55) / 0.35).clamp(0.0, 1.0);
      logoAlpha[y * n + x] = a;
    }
  }

  for (final entry in apps.entries) {
    final app = entry.key;
    final cCenter = entry.value[0];
    final cEdge = entry.value[1];
    final cr = (cCenter >> 16) & 0xFF, cg = (cCenter >> 8) & 0xFF, cb = cCenter & 0xFF;
    final er = (cEdge >> 16) & 0xFF, eg = (cEdge >> 8) & 0xFF, eb = cEdge & 0xFF;

    // 2) 1024 master: radyal gradyan + beyaz logo.
    final master = img.Image(width: n, height: n, numChannels: 3);
    final cx = n / 2, cy = n * 0.42; // merkez hafif yukarı (crm ile benzer)
    final maxR = math.sqrt(cx * cx + (n - cy) * (n - cy));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) / maxR;
        final t = Curves(d);
        var r = _lerp(cr, er, t), g = _lerp(cg, eg, t), b = _lerp(cb, eb, t);
        final a = logoAlpha[y * n + x];
        if (a > 0) {
          // beyaz logoyu gradyanın üstüne bindir.
          r = _lerp(r, 255, a);
          g = _lerp(g, 255, a);
          b = _lerp(b, 255, a);
        }
        master.setPixelRgb(x, y, r, g, b);
      }
    }

    // 3) Tüm boyutlara resize + yaz.
    final outDir = '$app/ios/Runner/Assets.xcassets/AppIcon.appiconset';
    for (final s in sizes.entries) {
      final resized = s.value == n
          ? master
          : img.copyResize(master,
              width: s.value, height: s.value, interpolation: img.Interpolation.average);
      File('$outDir/${s.key}').writeAsBytesSync(img.encodePng(resized));
    }
    stdout.writeln('$app: 15 ikon üretildi (merkez=#${cCenter.toRadixString(16).substring(2)})');
  }
  stdout.writeln('BİTTİ');
}

// Gradyanı biraz yumuşat (ease).
double Curves(double d) => math.pow(d.clamp(0.0, 1.0), 1.15).toDouble();
