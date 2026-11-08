import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_fixflow/config/environment.dart';

void main() {
  test('varsayılanlar: uygulama adı + marka', () {
    dotenv.testLoad(fileInput: '');
    expect(Environment.appName, 'Protoolbag FixFlow');
    expect(Environment.slogan, 'Saha & arıza yönetimi');
    expect(Environment.brandColor.toARGB32(), 0xFF0D9488);
    expect(Environment.isDebugMode, isFalse);
  });

  test('zorunlu değişkenler eksikse validate hata verir', () {
    dotenv.testLoad(fileInput: '');
    expect(Environment.validate, throwsException);
  });

  test('zorunlu değişkenler varsa validate geçer', () {
    dotenv.testLoad(
      fileInput: 'SUPABASE_URL=https://example.invalid\n'
          'SUPABASE_ANON_KEY=test-anon-key\n'
          'APP_NAME=FixFlow Test\n',
    );
    expect(Environment.validate, returnsNormally);
    expect(Environment.appName, 'FixFlow Test');
  });
}
