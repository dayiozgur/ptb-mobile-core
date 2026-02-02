# Multi-Tenant Isolation Guide

Bu dokuman, Protoolbag projelerinde multi-tenant izolasyon implementasyonu icin kapsamli bir kilavuz saglar.

## Icerik

1. [Genel Bakis](#1-genel-bakis)
2. [Hiyerarsi Yapisi](#2-hiyerarsi-yapisi)
3. [Veritabani Semasi](#3-veritabani-semasi)
4. [Servis Implementasyonu](#4-servis-implementasyonu)
5. [Context Yonetimi](#5-context-yonetimi)
6. [Guvenlik Kontrol Listesi](#6-guvenlik-kontrol-listesi)
7. [Migration Rehberi](#7-migration-rehberi)
8. [Test Stratejisi](#8-test-stratejisi)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Genel Bakis

### 1.1 Multi-Tenant Nedir?

Multi-tenant mimari, tek bir uygulama orneginin birden fazla musteri (tenant) tarafindan paylasildigi bir yapidir. Her tenant'in verileri birbirinden izole edilmistir.

### 1.2 Izolasyon Katmanlari

```
Tenant (Zorunlu)
  └─ Organization (Opsiyonel)
       └─ Site (Opsiyonel)
            └─ Unit (Opsiyonel)
                 └─ Controller
                      └─ Variable
                           └─ Logs / Alarms / Realtimes
```

| Katman | Zorunluluk | Aciklama |
|--------|------------|----------|
| **Tenant** | Zorunlu | En ust izolasyon katmani. Tum veriler tenant bazinda ayrilir. |
| **Organization** | Opsiyonel | Tenant icindeki organizasyonlar. Farkli departmanlar veya sirketler. |
| **Site** | Opsiyonel | Fiziksel lokasyonlar. Fabrikalar, ofisler, subeler. |
| **Unit** | Opsiyonel | Site icindeki birimler. Katlar, alanlar, zonlar. |

### 1.3 Temel Prensipler

1. **Defense in Depth**: Birden fazla izolasyon katmani kullan
2. **Fail-Safe Defaults**: Varsayilan olarak en kisitli erisim
3. **Explicit Over Implicit**: Izolasyon her zaman acikca belirtilmeli
4. **Consistent Filtering**: Tum sorgularda ayni filtreleme kaliplari

---

## 2. Hiyerarsi Yapisi

### 2.1 Entity Iliskileri

```
tenants
  │
  ├── organizations (tenant_id FK)
  │     │
  │     └── sites (organization_id FK, tenant_id FK)
  │           │
  │           ├── units (site_id FK, organization_id FK, tenant_id FK)
  │           │
  │           └── controllers (site_id FK, tenant_id FK, provider_id FK)
  │                 │
  │                 ├── variables (controller_id FK)
  │                 │
  │                 ├── alarms (controller_id FK, tenant_id FK, organization_id FK, site_id FK, provider_id FK)
  │                 │
  │                 ├── alarm_histories (controller_id FK, tenant_id FK, organization_id FK, site_id FK, provider_id FK)
  │                 │
  │                 └── logs (controller_id FK, tenant_id FK, organization_id FK, site_id FK, provider_id FK)
```

### 2.2 Izolasyon Kolonlari

Her tablo icin gerekli izolasyon kolonlari:

| Tablo | tenant_id | organization_id | site_id | provider_id |
|-------|-----------|-----------------|---------|-------------|
| organizations | ✅ | - | - | - |
| sites | ✅ | ✅ | - | - |
| units | ✅ | ✅ | ✅ | - |
| controllers | ✅ | - | ✅ | ✅ |
| alarms | ✅ | ✅ | ✅ | ✅ |
| alarm_histories | ✅ | ✅ | ✅ | ✅ |
| logs | ✅ | ✅ | ✅ | ✅ |
| realtimes | ✅ | - | - | - |
| variables | ✅ | - | - | - |

---

## 3. Veritabani Semasi

### 3.1 Kolon Tanimlari

```sql
-- Izolasyon kolonlari icin standart tanim
ALTER TABLE your_table
ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id),
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id),
ADD COLUMN IF NOT EXISTS site_id uuid REFERENCES sites(id),
ADD COLUMN IF NOT EXISTS provider_id uuid REFERENCES providers(id);

-- Index'ler (performans icin kritik)
CREATE INDEX IF NOT EXISTS idx_your_table_tenant_id ON your_table(tenant_id);
CREATE INDEX IF NOT EXISTS idx_your_table_organization_id ON your_table(organization_id);
CREATE INDEX IF NOT EXISTS idx_your_table_site_id ON your_table(site_id);

-- Composite index'ler (sik kullanilan sorgu kaliplari icin)
CREATE INDEX IF NOT EXISTS idx_your_table_tenant_org ON your_table(tenant_id, organization_id);
CREATE INDEX IF NOT EXISTS idx_your_table_tenant_site ON your_table(tenant_id, site_id);
```

### 3.2 Otomatik Senkronizasyon Trigger'i

Izolasyon kolonlarini controller hiyerarsisinden otomatik dolduran trigger:

```sql
CREATE OR REPLACE FUNCTION sync_isolation_columns()
RETURNS TRIGGER AS $$
BEGIN
  -- Controller'dan hiyerarsi bilgilerini al
  IF NEW.controller_id IS NOT NULL THEN
    SELECT
      c.tenant_id,
      c.provider_id,
      c.site_id,
      s.organization_id
    INTO
      NEW.tenant_id,
      NEW.provider_id,
      NEW.site_id,
      NEW.organization_id
    FROM controllers c
    LEFT JOIN sites s ON s.id = c.site_id
    WHERE c.id = NEW.controller_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger'i tabloya uygula
CREATE TRIGGER trg_your_table_sync_isolation
  BEFORE INSERT OR UPDATE ON your_table
  FOR EACH ROW
  WHEN (NEW.controller_id IS NOT NULL)
  EXECUTE FUNCTION sync_isolation_columns();
```

### 3.3 Row Level Security (RLS)

```sql
-- RLS aktif et
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;

-- Tenant izolasyon politikasi
CREATE POLICY tenant_isolation ON your_table
  FOR ALL
  USING (
    tenant_id = COALESCE(
      current_setting('app.current_tenant_id', true)::uuid,
      (SELECT tenant_id FROM profiles WHERE id = auth.uid())
    )
  );

-- Service account bypass (backend islemleri icin)
CREATE POLICY service_bypass ON your_table
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
```

---

## 4. Servis Implementasyonu

### 4.1 Servis Sinif Yapisi

```dart
/// Multi-Tenant destekli servis ornegi
class YourService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  // Multi-Tenant Izolasyon Context
  String? _currentTenantId;
  String? _currentOrganizationId;
  String? _currentSiteId;

  // ============================================
  // MULTI-TENANT ISOLATION CONTEXT
  // ============================================

  /// Tenant context ayarla - zorunlu izolasyon katmani
  void setTenant(String tenantId) {
    _currentTenantId = tenantId;
  }

  /// Tenant context temizle
  void clearTenant() {
    _currentTenantId = null;
  }

  /// Organization context ayarla - opsiyonel izolasyon katmani
  void setOrganization(String organizationId) {
    _currentOrganizationId = organizationId;
  }

  /// Organization context temizle
  void clearOrganization() {
    _currentOrganizationId = null;
  }

  /// Site context ayarla - opsiyonel izolasyon katmani
  void setSite(String siteId) {
    _currentSiteId = siteId;
  }

  /// Site context temizle
  void clearSite() {
    _currentSiteId = null;
  }

  /// Tum izolasyon context'lerini temizle
  void clearAllContexts() {
    _currentTenantId = null;
    _currentOrganizationId = null;
    _currentSiteId = null;
  }

  // Getter'lar
  String? get currentTenantId => _currentTenantId;
  String? get currentOrganizationId => _currentOrganizationId;
  String? get currentSiteId => _currentSiteId;
}
```

### 4.2 Sorgu Filtreleme Patterni

```dart
/// Veri cekme metodu ornegi
Future<List<YourModel>> getData({
  String? additionalFilter,
  int limit = 50,
}) async {
  try {
    var query = _supabase
        .from('your_table')
        .select();

    // ===========================================
    // KRITIK: Multi-Tenant Izolasyon Filtreleri
    // ===========================================
    // Bu filtreler MUTLAKA uygulanmalidir!

    if (_currentTenantId != null) {
      query = query.eq('tenant_id', _currentTenantId!);
    }

    if (_currentOrganizationId != null) {
      query = query.eq('organization_id', _currentOrganizationId!);
    }

    if (_currentSiteId != null) {
      query = query.eq('site_id', _currentSiteId!);
    }

    // ===========================================
    // Ek Filtreler (parametre olarak gecilenler)
    // ===========================================

    if (additionalFilter != null) {
      query = query.eq('some_field', additionalFilter);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((e) => YourModel.fromJson(e))
        .toList();
  } catch (e, stackTrace) {
    Logger.error('Failed to get data', e, stackTrace);
    return [];
  }
}
```

### 4.3 Cache Key Yonetimi

```dart
/// Cache key'e izolasyon context'lerini dahil et
String _buildCacheKey(String prefix, String? additionalKey) {
  final parts = <String>[prefix];

  if (_currentTenantId != null) {
    parts.add('t:$_currentTenantId');
  }

  if (_currentOrganizationId != null) {
    parts.add('o:$_currentOrganizationId');
  }

  if (_currentSiteId != null) {
    parts.add('s:$_currentSiteId');
  }

  if (additionalKey != null) {
    parts.add(additionalKey);
  }

  return parts.join('_');
}

// Kullanim
final cacheKey = _buildCacheKey('alarms', 'active');
// Sonuc: alarms_t:tenant-uuid_o:org-uuid_s:site-uuid_active
```

---

## 5. Context Yonetimi

### 5.1 CoreInitializer Entegrasyonu

```dart
/// CoreInitializer'da context yonetimi
class CoreInitializer {
  /// Tenant context'ini tum servislere aktar
  static void _propagateTenantToServices(String tenantId) {
    try {
      sl<ControllerService>().setTenant(tenantId);
      sl<AlarmService>().setTenant(tenantId);
      sl<IoTLogService>().setTenant(tenantId);
      // ... diger servisler
      Logger.debug('Tenant propagated: $tenantId');
    } catch (e) {
      Logger.warning('Failed to propagate tenant: $e');
    }
  }

  /// Organization context'ini tum servislere aktar
  static void propagateOrganizationToServices(String organizationId) {
    try {
      sl<AlarmService>().setOrganization(organizationId);
      sl<IoTLogService>().setOrganization(organizationId);
      Logger.debug('Organization propagated: $organizationId');
    } catch (e) {
      Logger.warning('Failed to propagate organization: $e');
    }
  }

  /// Site context'ini tum servislere aktar
  static void propagateSiteToServices(String siteId) {
    try {
      sl<AlarmService>().setSite(siteId);
      sl<IoTLogService>().setSite(siteId);
      Logger.debug('Site propagated: $siteId');
    } catch (e) {
      Logger.warning('Failed to propagate site: $e');
    }
  }

  /// Alt seviye context'leri temizle (tenant haric)
  static void clearSubTenantContexts() {
    try {
      sl<AlarmService>().clearOrganization();
      sl<AlarmService>().clearSite();
      sl<IoTLogService>().clearOrganization();
      sl<IoTLogService>().clearSite();
      Logger.debug('Sub-tenant contexts cleared');
    } catch (e) {
      Logger.warning('Failed to clear sub-tenant contexts: $e');
    }
  }
}
```

### 5.2 UI'dan Context Degisikligi

```dart
/// Organization secildiginde
void onOrganizationSelected(Organization org) {
  // Context'i guncelle
  CoreInitializer.propagateOrganizationToServices(org.id);

  // Site context'ini temizle (organization degisti)
  CoreInitializer.clearSiteFromServices();

  // UI'i guncelle
  setState(() {
    _selectedOrganization = org;
    _selectedSite = null;
  });

  // Verileri yeniden yukle
  _refreshData();
}

/// Site secildiginde
void onSiteSelected(Site site) {
  // Context'i guncelle
  CoreInitializer.propagateSiteToServices(site.id);

  // UI'i guncelle
  setState(() {
    _selectedSite = site;
  });

  // Verileri yeniden yukle
  _refreshData();
}

/// Tum filtreler kaldirildiginda
void onClearFilters() {
  // Alt seviye context'leri temizle
  CoreInitializer.clearSubTenantContexts();

  // UI'i guncelle
  setState(() {
    _selectedOrganization = null;
    _selectedSite = null;
  });

  // Verileri yeniden yukle
  _refreshData();
}
```

---

## 6. Guvenlik Kontrol Listesi

### 6.1 Yeni Servis Eklerken

- [ ] Servis sinifinda `_currentTenantId`, `_currentOrganizationId`, `_currentSiteId` tanimla
- [ ] `setTenant()`, `clearTenant()` metodlarini ekle
- [ ] `setOrganization()`, `clearOrganization()` metodlarini ekle
- [ ] `setSite()`, `clearSite()` metodlarini ekle
- [ ] Tum veri cekme metodlarinda tenant filtresi uygula
- [ ] Tum veri cekme metodlarinda organization filtresi uygula (opsiyonel)
- [ ] Tum veri cekme metodlarinda site filtresi uygula (opsiyonel)
- [ ] Cache key'lere tenant/org/site bilgilerini ekle
- [ ] CoreInitializer'a servis propagation'i ekle

### 6.2 Yeni Tablo Eklerken

- [ ] `tenant_id` kolonu ekle (FK: tenants.id)
- [ ] `organization_id` kolonu ekle (FK: organizations.id)
- [ ] `site_id` kolonu ekle (FK: sites.id)
- [ ] Gerekli index'leri olustur
- [ ] Senkronizasyon trigger'i ekle
- [ ] RLS politikasi tanimla
- [ ] Mevcut verileri backfill et

### 6.3 Kod Review Kontrol Listesi

- [ ] Tum `SELECT` sorgularinda tenant filtresi var mi?
- [ ] Count metodlarinda tenant filtresi var mi?
- [ ] Aggregate sorgularinda tenant filtresi var mi?
- [ ] JOIN sorgularinda her iki tarafta da tenant filtresi var mi?
- [ ] Cache key'ler tenant bilgisi iceriyor mu?
- [ ] Stream'ler tenant context'e duyarli mi?

---

## 7. Migration Rehberi

### 7.1 Mevcut Tabloya Izolasyon Ekleme

```sql
-- Step 1: Kolonlari ekle
ALTER TABLE your_table
ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id),
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES organizations(id),
ADD COLUMN IF NOT EXISTS site_id uuid REFERENCES sites(id);

-- Step 2: Index'leri olustur
CREATE INDEX IF NOT EXISTS idx_your_table_tenant_id ON your_table(tenant_id);
CREATE INDEX IF NOT EXISTS idx_your_table_tenant_org ON your_table(tenant_id, organization_id);

-- Step 3: Mevcut verileri backfill et
UPDATE your_table t
SET
  tenant_id = c.tenant_id,
  site_id = c.site_id,
  organization_id = s.organization_id
FROM controllers c
LEFT JOIN sites s ON s.id = c.site_id
WHERE t.controller_id = c.id
AND (t.tenant_id IS NULL OR t.organization_id IS NULL);

-- Step 4: Trigger ekle
CREATE TRIGGER trg_your_table_sync_isolation
  BEFORE INSERT OR UPDATE ON your_table
  FOR EACH ROW
  WHEN (NEW.controller_id IS NOT NULL)
  EXECUTE FUNCTION sync_isolation_columns();

-- Step 5: RLS aktif et
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON your_table
  FOR ALL USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
```

### 7.2 Veri Butunlugunu Dogrulama

```sql
-- Izolasyon verilerinin eksik oldugu kayitlari bul
SELECT
  'alarms' as table_name,
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE tenant_id IS NULL) as missing_tenant,
  COUNT(*) FILTER (WHERE organization_id IS NULL) as missing_org,
  COUNT(*) FILTER (WHERE site_id IS NULL) as missing_site
FROM alarms

UNION ALL

SELECT
  'logs' as table_name,
  COUNT(*),
  COUNT(*) FILTER (WHERE tenant_id IS NULL),
  COUNT(*) FILTER (WHERE organization_id IS NULL),
  COUNT(*) FILTER (WHERE site_id IS NULL)
FROM logs

UNION ALL

SELECT
  'alarm_histories' as table_name,
  COUNT(*),
  COUNT(*) FILTER (WHERE tenant_id IS NULL),
  COUNT(*) FILTER (WHERE organization_id IS NULL),
  COUNT(*) FILTER (WHERE site_id IS NULL)
FROM alarm_histories;
```

---

## 8. Test Stratejisi

### 8.1 Unit Test Ornekleri

```dart
group('AlarmService Multi-Tenant Isolation', () {
  late AlarmService alarmService;

  setUp(() {
    alarmService = AlarmService(
      supabase: mockSupabase,
      cacheManager: mockCacheManager,
    );
  });

  test('should only return alarms for current tenant', () async {
    // Arrange
    alarmService.setTenant('tenant-1');

    // Act
    final alarms = await alarmService.getActiveAlarms();

    // Assert
    expect(alarms.every((a) => a.tenantId == 'tenant-1'), isTrue);
  });

  test('should filter by organization when set', () async {
    // Arrange
    alarmService.setTenant('tenant-1');
    alarmService.setOrganization('org-1');

    // Act
    final alarms = await alarmService.getActiveAlarms();

    // Assert
    expect(alarms.every((a) => a.organizationId == 'org-1'), isTrue);
  });

  test('should not return data without tenant context', () async {
    // Arrange - no tenant set

    // Act
    final alarms = await alarmService.getActiveAlarms();

    // Assert
    // Sonuc ya bos liste ya da sadece NULL tenant_id olan veriler olmali
  });
});
```

### 8.2 Integration Test Ornekleri

```dart
testWidgets('Organization filter should update displayed alarms', (tester) async {
  // Arrange
  await tester.pumpWidget(MyApp());

  // Act - Organization sec
  await tester.tap(find.byKey(Key('org-selector')));
  await tester.tap(find.text('Organization 1'));
  await tester.pumpAndSettle();

  // Assert - Sadece Organization 1 alarmlari gozukmeli
  expect(find.text('Alarm from Org 1'), findsOneWidget);
  expect(find.text('Alarm from Org 2'), findsNothing);
});
```

---

## 9. Troubleshooting

### 9.1 Yaygin Hatalar

#### Hata: "Cross-tenant data leak"

**Belirti**: Bir tenant'in verileri baska tenant'a gorunuyor.

**Cozum**:
1. Servis metodunda tenant filtresi var mi kontrol et
2. RLS politikasi aktif mi kontrol et
3. Cache key'de tenant bilgisi var mi kontrol et

```dart
// YANLIS
var query = _supabase.from('alarms').select();

// DOGRU
var query = _supabase.from('alarms').select();
if (_currentTenantId != null) {
  query = query.eq('tenant_id', _currentTenantId!);
}
```

#### Hata: "Empty results after organization change"

**Belirti**: Organization degistikten sonra veriler gozukmuyor.

**Cozum**:
1. Cache'i temizle
2. Context propagation'in calistigini dogrula
3. Veritabaninda organization_id dolu mu kontrol et

```dart
// Organization degistiginde
void onOrganizationChanged(String orgId) {
  // 1. Context'i guncelle
  alarmService.setOrganization(orgId);

  // 2. Cache'i temizle
  await cacheManager.clear();

  // 3. Veriyi yeniden cek
  await alarmService.getActiveAlarms(forceRefresh: true);
}
```

#### Hata: "Missing isolation columns in new records"

**Belirti**: Yeni eklenen kayitlarda tenant_id/organization_id NULL.

**Cozum**:
1. Trigger'in calistigini dogrula
2. Controller_id'nin dolu oldugunu kontrol et
3. Controller'in hiyerarsi bilgilerinin dogru oldugunu kontrol et

```sql
-- Trigger'i test et
INSERT INTO alarms (id, controller_id, description)
VALUES ('test-id', 'existing-controller-id', 'Test alarm');

-- Sonucu kontrol et
SELECT id, tenant_id, organization_id, site_id
FROM alarms WHERE id = 'test-id';
```

### 9.2 Performans Optimizasyonu

#### Yaygin Index'ler

```sql
-- Tenant bazli sorgular icin
CREATE INDEX idx_table_tenant ON table(tenant_id);

-- Tenant + Organization sorgulari icin
CREATE INDEX idx_table_tenant_org ON table(tenant_id, organization_id);

-- Tenant + Site sorgulari icin
CREATE INDEX idx_table_tenant_site ON table(tenant_id, site_id);

-- Zaman bazli sorgular icin
CREATE INDEX idx_table_tenant_created ON table(tenant_id, created_at DESC);
```

#### Partial Index (Aktif kayitlar icin)

```sql
CREATE INDEX idx_alarms_tenant_active
ON alarms(tenant_id)
WHERE active = true;
```

---

## Referanslar

- [Supabase Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL RLS Documentation](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Multi-Tenant Architecture Patterns](https://docs.microsoft.com/en-us/azure/architecture/guide/multitenant/overview)

---

## Degisiklik Gecmisi

| Tarih | Versiyon | Degisiklik |
|-------|----------|------------|
| 2025-02-02 | 1.0.0 | Ilk surum |

---

## Katkida Bulunanlar

- Protoolbag Core Ekibi

