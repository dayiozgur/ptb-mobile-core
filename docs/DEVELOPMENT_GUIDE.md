# Protoolbag Mobile Core - Geliştirme Rehberi

Bu döküman, Core kütüphanesine eklenen tüm özellikleri ve kullanım detaylarını içerir.

---

## İçindekiler

1. [Veritabanı Mimarisi](#veritabanı-mimarisi)
2. [Tenant Yönetimi](#tenant-yönetimi)
3. [Organization Yönetimi](#organization-yönetimi)
4. [Site Yönetimi](#site-yönetimi)
5. [Kullanıcı Davet Sistemi](#kullanıcı-davet-sistemi)
6. [Rol ve Yetki Yönetimi](#rol-ve-yetki-yönetimi)
7. [SQL Migrations](#sql-migrations)
8. [Kullanım Örnekleri](#kullanım-örnekleri)

---

## Veritabanı Mimarisi

### Hiyerarşi

```
Platform
    └── Tenant (Şirket/Müşteri)
            └── Organization (Departman/Bölüm)
                    └── Site (Bina/Tesis)
                            └── Unit (Alan/Oda)
                                    └── Controller/Provider/Variable
```

### Temel Tablolar

| Tablo | Açıklama | İlişki |
|-------|----------|--------|
| `tenants` | Müşteri/Şirket | Ana tablo |
| `tenant_users` | Kullanıcı-Tenant üyelikleri | N:N |
| `organizations` | Alt organizasyonlar | Tenant → 1:N |
| `sites` | Fiziksel lokasyonlar | Organization → 1:N |
| `units` | Alanlar/Bölümler | Site → 1:N (self-referencing) |

---

## Tenant Yönetimi

### Model: `Tenant`

```dart
import 'package:protoolbag_core/protoolbag_core.dart';

final tenant = Tenant(
  id: 'uuid',
  name: 'Şirket Adı',
  code: 'sirket-kodu',
  description: 'Açıklama',
  active: true,
  address: 'Adres',
  city: 'İstanbul',
  country: 'Türkiye',
  latitude: 41.0082,
  longitude: 28.9784,
);
```

### Service: `TenantService`

```dart
final tenantService = TenantService(
  supabase: Supabase.instance.client,
  secureStorage: SecureStorage(),
  cacheManager: CacheManager(),
);

// Kullanıcının tenant'larını getir
final tenants = await tenantService.getUserTenants(userId);

// Tenant seç
await tenantService.selectTenant(tenantId);

// Mevcut tenant
final current = tenantService.currentTenant;

// Yeni tenant oluştur
final newTenant = await tenantService.createTenant(
  name: 'Yeni Şirket',
  slug: 'yeni-sirket',
  ownerId: userId,
);

// Kullanıcıyı tenant'a ekle
await tenantService.addUserToTenant(
  tenantId: tenantId,
  userId: newUserId,
  role: TenantRole.member,
);
```

### TenantRole Enum

| Rol | Değer | Seviye | Açıklama |
|-----|-------|--------|----------|
| `owner` | 'owner' | 100 | Tenant sahibi |
| `admin` | 'admin' | 80 | Yönetici |
| `manager` | 'manager' | 60 | Müdür |
| `member` | 'member' | 40 | Üye |
| `viewer` | 'viewer' | 20 | Görüntüleyici |

---

## Organization Yönetimi

### Model: `Organization`

```dart
final org = Organization(
  id: 'uuid',
  name: 'Merkez Ofis',
  code: 'merkez',
  tenantId: 'tenant-uuid',
  description: 'Ana merkez',
  address: 'Levent, İstanbul',
  city: 'İstanbul',
  country: 'Türkiye',
  latitude: 41.0822,
  longitude: 29.0115,
  active: true,
);

// Tam adres
print(org.fullAddress); // "Levent, İstanbul, İstanbul, Türkiye"

// Konum var mı?
print(org.hasLocation); // true
```

### Service: `OrganizationService`

```dart
final orgService = OrganizationService(
  supabase: Supabase.instance.client,
  cacheManager: CacheManager(),
);

// Tenant'ın organizasyonlarını getir
final orgs = await orgService.getOrganizations(tenantId);

// Organizasyon seç
await orgService.selectOrganization(orgId);

// Yeni organizasyon oluştur
final newOrg = await orgService.createOrganization(
  tenantId: tenantId,
  name: 'Batı Bölge',
  code: 'bati-bolge',
  description: 'Batı bölge ofisi',
  city: 'İzmir',
);

// Organizasyon güncelle
await orgService.updateOrganization(
  organizationId: orgId,
  name: 'Yeni İsim',
  active: true,
);

// Organizasyon ara
final results = await orgService.searchOrganizations(tenantId, 'merkez');

// Stream dinle
orgService.organizationStream.listen((org) {
  print('Seçili organizasyon: ${org?.name}');
});
```

---

## Site Yönetimi

### Model: `Site`

```dart
final site = Site(
  id: 'uuid',
  name: 'Merkez Bina',
  code: 'merkez-bina',
  organizationId: 'org-uuid',
  markerId: 'marker-uuid',
  address: 'Maslak, İstanbul',
  grossAreaSqm: 5000,
  netAreaSqm: 4200,
  floorCount: 10,
  yearBuilt: 2015,
  energyCertificateClass: EnergyCertificateClass.b,
  generalOpenTime: '08:00',
  generalCloseTime: '18:00',
  workingTimeActive: true,
);

// Bina yaşı
print(site.buildingAge); // 11 (2026'da)

// Bugün açık mı?
print(site.isOpenToday); // true/false
```

### Service: `SiteService`

```dart
final siteService = SiteService(
  supabase: Supabase.instance.client,
  cacheManager: CacheManager(),
);

// Organization'ın sitelerini getir
final sites = await siteService.getSites(organizationId);

// Tenant'ın tüm sitelerini getir
final allSites = await siteService.getSitesByTenant(tenantId);

// Site seç
await siteService.selectSite(siteId);

// Yeni site oluştur
final newSite = await siteService.createSite(
  organizationId: orgId,
  name: 'Yeni Bina',
  markerId: markerId,
  tenantId: tenantId,
  address: 'Kadıköy, İstanbul',
  grossAreaSqm: 2000,
  floorCount: 5,
);

// Yakındaki siteleri bul
final nearby = await siteService.getNearbySites(
  latitude: 41.0082,
  longitude: 28.9784,
  radiusKm: 5,
);
```

---

## Kullanıcı Davet Sistemi

### Service: `InvitationService`

```dart
final invitationService = InvitationService(
  supabase: Supabase.instance.client,
);

// Davet gönder
final invitation = await invitationService.createInvitation(
  email: 'newuser@example.com',
  tenantId: tenantId,
  invitedBy: currentUserId,
  role: TenantRole.member,
  message: 'Ekibimize katılın!',
  expirationDays: 7,
);

// Toplu davet
final invitations = await invitationService.createBulkInvitations(
  emails: ['user1@example.com', 'user2@example.com'],
  tenantId: tenantId,
  invitedBy: currentUserId,
  role: TenantRole.member,
);

// Daveti kabul et
final success = await invitationService.acceptInvitation(token, userId);

// Daveti reddet
await invitationService.rejectInvitation(token, reason: 'Şu an uygun değilim');
```

---

## Rol ve Yetki Yönetimi

### Service: `PermissionService`

```dart
final permissionService = PermissionService(
  supabase: Supabase.instance.client,
  cacheManager: CacheManager(),
);

// İzin kontrolü
final canCreate = await permissionService.hasPermission(
  userId: userId,
  tenantId: tenantId,
  permission: 'sites.create',
);

// Admin mi?
final isAdmin = await permissionService.isAdmin(userId, tenantId);

// Rol ata
await permissionService.assignRole(
  userId: userId,
  tenantId: tenantId,
  roleCode: 'manager',
);

// Özel rol oluştur
final newRole = await permissionService.createRole(
  tenantId: tenantId,
  code: 'field-engineer',
  name: 'Saha Mühendisi',
  level: 45,
  permissions: ['sites.view', 'units.*'],
);
```

### SystemRoles

| Rol | Kod | Seviye | İzinler |
|-----|-----|--------|---------|
| Owner | 'owner' | 100 | Tümü |
| Admin | 'admin' | 80 | Faturalama hariç |
| Manager | 'manager' | 60 | Operasyonel |
| Member | 'member' | 40 | Temel |
| Viewer | 'viewer' | 20 | Görüntüleme |

---

## SQL Migrations

### Migration 1: tenant_users
**Dosya:** `database/migrations/001_tenant_users.sql`

### Migration 2: invitations_and_roles
**Dosya:** `database/migrations/002_invitations_and_roles.sql`

### Çalıştırma

```sql
-- Önce tabloları oluştur, sonra:
SELECT migrate_existing_profile_tenants();
```

**NOT:** Migration fonksiyonu sadece `auth.users` tablosunda mevcut olan profilleri migrate eder.

---

## Versiyon Geçmişi

| Versiyon | Tarih | Değişiklikler |
|----------|-------|---------------|
| 1.1.0 | 2026-01-26 | Organization, Site, Invitation, Permission |
| 1.0.0 | 2026-01-25 | Auth, Tenant, temel bileşenler |
