import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// RealtimeRefresher — liste/inbox ekranlarına canlı-yenileme ekleyen sarmalayıcı.
/// Sözleşme: `start` bir kez abone olur (idempotent), tabloyu/filtreyi/benzersiz
/// channelKey'i RealtimeService'e geçirir; `dispose` yalnız abone olunmuşsa
/// unsubscribe eder. Gerçek Supabase kanalı kurulmaz — sl'e sahte RealtimeService
/// enjekte edilir.
class _FakeRealtime extends RealtimeService {
  final SupabaseClient client;
  _FakeRealtime(this.client) : super(supabase: client);

  int subscribeCount = 0;
  final List<String> unsubscribed = [];
  String? lastTable;
  String? lastFilter;
  String? lastChannelKey;

  @override
  RealtimeSubscription subscribe<T>({
    required String table,
    String schema = 'public',
    List<RealtimeEventType> events = const [RealtimeEventType.all],
    String? filter,
    required T Function(Map<String, dynamic>) fromJson,
    void Function(T newRecord)? onInsert,
    void Function(T newRecord, T? oldRecord)? onUpdate,
    void Function(T? oldRecord)? onDelete,
    void Function(RealtimeChange<T> change)? onChange,
    void Function(String error)? onError,
    String? channelKey,
  }) {
    subscribeCount++;
    lastTable = table;
    lastFilter = filter;
    lastChannelKey = channelKey;
    // Abone OLUNMAYAN bir channel nesnesi yeterli (ağ kurulmaz).
    return RealtimeSubscription(
      id: 'sub-$subscribeCount',
      table: table,
      channel: client.channel('fake-$subscribeCount'),
    );
  }

  @override
  Future<void> unsubscribe(String subscriptionId) async {
    unsubscribed.add(subscriptionId);
  }
}

void main() {
  late _FakeRealtime fake;

  setUp(() {
    final client = SupabaseClient('https://example.supabase.co', 'anon-key');
    fake = _FakeRealtime(client);
    if (sl.isRegistered<RealtimeService>()) {
      sl.unregister<RealtimeService>();
    }
    sl.registerSingleton<RealtimeService>(fake);
  });

  tearDown(() {
    if (sl.isRegistered<RealtimeService>()) {
      sl.unregister<RealtimeService>();
    }
  });

  test('start bir kez subscribe eder ve table/filter/channelKey geçirir', () {
    final rr = RealtimeRefresher();
    rr.start(
      table: 'form_submissions',
      onChange: () {},
      filter: 'tenant_id=eq.abc',
    );

    expect(fake.subscribeCount, 1);
    expect(fake.lastTable, 'form_submissions');
    expect(fake.lastFilter, 'tenant_id=eq.abc');
    // Ekran-başı bağımsızlık için benzersiz channelKey verilmeli (null değil).
    expect(fake.lastChannelKey, isNotNull);

    rr.dispose();
  });

  test('çift start idempotenttir — yalnız bir subscribe', () {
    final rr = RealtimeRefresher();
    rr.start(table: 't', onChange: () {});
    rr.start(table: 't', onChange: () {});

    expect(fake.subscribeCount, 1);
    rr.dispose();
  });

  test('dispose, subscribe edilen id ile unsubscribe eder', () {
    final rr = RealtimeRefresher();
    rr.start(table: 't', onChange: () {});
    rr.dispose();

    expect(fake.unsubscribed, ['sub-1']);
  });

  test('start edilmeden dispose güvenlidir (no-op, unsubscribe yok)', () {
    final rr = RealtimeRefresher();
    rr.dispose();

    expect(fake.unsubscribed, isEmpty);
  });

  test('her örnek benzersiz channelKey üretir (aynı tabloyu izleyen ekranlar çakışmaz)', () {
    final rr1 = RealtimeRefresher()..start(table: 't', onChange: () {});
    final k1 = fake.lastChannelKey;
    final rr2 = RealtimeRefresher()..start(table: 't', onChange: () {});
    final k2 = fake.lastChannelKey;

    expect(k1, isNotNull);
    expect(k2, isNotNull);
    expect(k1, isNot(equals(k2)));

    rr1.dispose();
    rr2.dispose();
  });
}
