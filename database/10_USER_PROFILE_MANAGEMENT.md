# Kullanici ve Profil Yonetimi Analizi

Bu dokuman, profiles tablosu uzerinden yapilan kullanici yonetimi ve bu sistemin ana hiyerarsi (Platform, Tenant, Organization, Site, Unit) ile iliskilerini analiz eder.

---

## 1. Genel Bakis

Sistemde kullanici yonetimi cok katmanli bir yapiyla gerceklestirilir:

```
+=====================================================================+
|                     KULLANICI YONETIMI KATMANLARI                    |
+=====================================================================+
|                                                                     |
|  +-------------------+     +-------------------+                    |
|  |     profiles      |<--->|   realm_users     |                    |
|  | (Uygulama Profili)|     | (Auth/Keycloak)   |                    |
|  +-------------------+     +-------------------+                    |
|           |                        |                                |
|           v                        v                                |
|  +-------------------+     +-------------------+                    |
|  |      staffs       |     |   contractors/    |                    |
|  | (Calisan Kaydi)   |     |  sub_contractors  |                    |
|  +-------------------+     +-------------------+                    |
|           |                        |                                |
|           v                        v                                |
|  +-------------------------------------------------------------- +  |
|  |                      ANA HIYERARSI                            |  |
|  |  Tenant -> Organization -> Site -> Unit                       |  |
|  +---------------------------------------------------------------+  |
|                                                                     |
+=====================================================================+
```

---

## 2. Profiles Tablosu (Ana Kullanici Profili)

### 2.1 Tablo Yapisi

```sql
CREATE TABLE public.profiles (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),

    -- Kimlik Bilgileri
    username character varying UNIQUE,
    email character varying NOT NULL UNIQUE,
    full_name character varying,
    first_name character varying,
    last_name character varying,
    phone character varying,
    bio character varying,
    avatar_url text,

    -- Yetki ve Durum
    role CHECK ('ROLE_ADMIN', 'ROLE_MANAGER', 'ROLE_USER') DEFAULT 'ROLE_USER',
    active boolean DEFAULT true,
    two_factor_enabled boolean DEFAULT false,
    last_login timestamp,

    -- Profil Ozellikleri
    name character varying,
    description character varying,
    type character varying,
    type_attribute character varying,
    is_default boolean,

    -- Hiyerarsi Iliskisi
    tenant_id uuid,                    -- REFERENCES tenants(id)

    -- Audit
    created_by uuid,
    updated_by uuid,
    created_by_role character varying,
    row_id integer NOT NULL,
);
```

### 2.2 Rol Tipleri

| Rol | Aciklama | Yetkiler |
|-----|----------|----------|
| `ROLE_ADMIN` | Yonetici | Tam erisim |
| `ROLE_MANAGER` | Mudur | Sinirli yonetim |
| `ROLE_USER` | Kullanici | Temel erisim |

### 2.3 Hiyerarsi Iliskisi

| profiles -> | Iliski | Aciklama |
|-------------|--------|----------|
| `tenant_id` | tenants | Profil bu tenant'a ait |

**EKSIK:** Organization, Site veya Unit baglantisi yok. Profiller sadece Tenant seviyesinde tanimlanir.

---

## 3. Realm Users Tablosu (Auth Entegrasyonu)

### 3.1 Tablo Yapisi

```sql
CREATE TABLE public.realm_users (
    id uuid NOT NULL,

    -- Kimlik Bilgileri
    username character varying,
    email character varying,
    first_name character varying,
    last_name character varying,
    password character varying,
    old_password character varying,
    image_path character varying,

    -- Auth Durumu
    is_enabled boolean,
    is_temporary boolean,
    email_validated boolean,
    is_verified_email boolean,
    phone_validated boolean,

    -- Keycloak Bilgileri
    realm character varying,
    realm_user_id uuid,
    client character varying,
    role character varying,
    locale character varying,
    theme_type character varying,
    user_id uuid,
    key character varying,
    value character varying,

    -- HIYERARSI ILISKILERI
    tenant uuid,                       -- REFERENCES tenants(id)
    profile uuid,                      -- REFERENCES profiles(id)
    consumer uuid,                     -- REFERENCES organizations(id) [ONEMLI!]
    contractor uuid,                   -- REFERENCES contractors(id)
    sub_contractor uuid,               -- REFERENCES sub_contractors(id)

    -- Audit
    active boolean,
    created_by uuid,
    created_at timestamp,
    updated_by uuid,
    updated_at timestamp,
    row_id integer NOT NULL,
);
```

### 3.2 Hiyerarsi Iliskisi Matrisi

| realm_users -> | Iliski | Aciklama |
|----------------|--------|----------|
| `tenant` | tenants | Kullanici bu tenant'a ait |
| `profile` | profiles | Uygulama profili |
| `consumer` | organizations | Kullanicinin ait oldugu organization |
| `contractor` | contractors | Yuklenici kullanicisi ise |
| `sub_contractor` | sub_contractors | Alt yuklenici kullanicisi ise |

**ONEMLI:** `consumer` alani aslinda `organization_id` gorevi gorur. Kullaniciyi belirli bir Organization'a baglar.

### 3.3 Kullanici Tipleri

Realm_users tablosundaki iliskilere gore kullanici tipleri:

| Tip | Tanimlama | Aciklama |
|-----|-----------|----------|
| Tenant Kullanicisi | tenant != null, consumer = null | Tenant genelinde erisim |
| Organization Kullanicisi | consumer != null | Belirli organization'a sinirli |
| Contractor Kullanicisi | contractor != null | Yuklenici personeli |
| SubContractor Kullanicisi | sub_contractor != null | Alt yuklenici personeli |

---

## 4. Staffs Tablosu (Calisan Kayitlari)

### 4.1 Tablo Yapisi

```sql
CREATE TABLE public.staffs (
    id uuid NOT NULL,

    -- Temel Bilgiler
    code character varying,
    name character varying,
    description character varying,
    first_name character varying,
    last_name character varying,
    email character varying,
    phone character varying,
    fax character varying,

    -- Adres Bilgileri
    address character varying,
    town character varying,
    directions character varying,
    website character varying,
    city_id uuid,
    country_id uuid,

    -- HIYERARSI ILISKILERI
    tenant_id uuid,                    -- REFERENCES tenants(id)
    organization_id uuid,              -- REFERENCES organizations(id)
    profile_id uuid,                   -- REFERENCES profiles(id)

    -- ACTOR ILISKILERI
    contractor_id uuid,                -- REFERENCES contractors(id)
    sub_contractor_id uuid,            -- REFERENCES sub_contractors(id)
    staff_type_id uuid,                -- REFERENCES staff_types(id)

    -- Diger
    user_id uuid,
    rating_id uuid UNIQUE,
    route_location_id uuid UNIQUE,

    -- Audit
    active boolean,
    created_by uuid,
    created_at timestamp,
    updated_by uuid,
    updated_at timestamp,
    row_id integer NOT NULL,
);
```

### 4.2 Hiyerarsi Iliskisi Matrisi

| staffs -> | Iliski | Aciklama |
|-----------|--------|----------|
| `tenant_id` | tenants | Staff bu tenant'a ait |
| `organization_id` | organizations | Staff bu organization altinda |
| `profile_id` | profiles | Kullanici profili baglantisi |
| `contractor_id` | contractors | Yuklenici personeli ise |
| `sub_contractor_id` | sub_contractors | Alt yuklenici personeli ise |

**ONEMLI:** Staffs, hem Organization hem de Contractor/SubContractor'a baglanabilir. Bu, bir calisanin hem dahili (organization) hem de harici (contractor) olabilecegini gosterir.

---

## 5. Contractors ve SubContractors

### 5.1 Contractors Tablosu

```sql
CREATE TABLE public.contractors (
    id uuid NOT NULL,
    code character varying,
    name character varying,
    description character varying,
    email character varying NOT NULL,
    phone character varying NOT NULL,
    color character varying,
    image_path character varying,
    avatar_code character varying,
    foundation_date character varying,
    client character varying,

    -- Iliskiler
    financial_id uuid UNIQUE,
    location_id uuid UNIQUE,
    marker_id uuid,
    rating_id uuid UNIQUE,

    -- Audit
    active boolean,
    created_by uuid,
    created_at timestamp,
    ...
);
```

**NOT:** Contractors tablosunda dogrudan `tenant_id` YOKTUR. Tenant iliskisi `tenant_contractors` bridge tablosu uzerinden kurulur.

### 5.2 Tenant-Contractor Iliskisi (N:N)

```sql
CREATE TABLE public.tenant_contractors (
    id uuid NOT NULL,
    contractor_id uuid,                -- REFERENCES contractors(id)
    tenant_id uuid,                    -- REFERENCES tenants(id)
    ...
);
```

### 5.3 Organization-Contractor Iliskisi (N:N)

```sql
CREATE TABLE public.contractor_organizations (
    contractor_id uuid NOT NULL,
    organizations_id uuid NOT NULL,
    PRIMARY KEY (contractor_id, organizations_id)
);
```

---

## 6. Teams ve Team Members

### 6.1 Teams Tablosu

```sql
CREATE TABLE public.teams (
    id uuid NOT NULL,
    code character varying,
    name character varying,
    description character varying,
    independent boolean,
    rating_id uuid UNIQUE,
    route_locations_id uuid UNIQUE,
    ...
);
```

**NOT:** Teams tablosunda dogrudan `tenant_id` YOKTUR. Tenant iliskisi `tenant_teams` bridge tablosu uzerinden kurulur.

### 6.2 Team-Staff Iliskisi (N:N)

```sql
CREATE TABLE public.team_staffs (
    team_id uuid NOT NULL,
    staff_id uuid NOT NULL,
    active boolean,
    ...
);
```

---

## 7. Menu ve Sayfa Erisim Yonetimi

### 7.1 Menu Yapisi

```
menus (Ana Menuler)
    |
    +-- sub_menus (Alt Menuler)
            |
            +-- pages (Sayfalar)
```

### 7.2 Profile-Menu Iliskisi

```sql
-- Profil icin aktif menuler
CREATE TABLE public.menu_ids (
    id uuid NOT NULL,
    menu_id uuid,
    profile_id uuid,                   -- REFERENCES profiles(id)
    ...
);

-- Profil icin aktif alt menuler
CREATE TABLE public.sub_menu_ids (
    id uuid NOT NULL,
    sub_menu_id uuid,
    profile_id uuid,                   -- REFERENCES profiles(id)
    ...
);

-- Profil icin aktif sayfalar
CREATE TABLE public.page_ids (
    id uuid NOT NULL,
    page_id uuid,
    profile_id uuid,                   -- REFERENCES profiles(id)
    ...
);
```

### 7.3 Erisim Kontrol Akisi

```
Kullanici Girisi
    |
    v
Profile belirlenir
    |
    v
menu_ids, sub_menu_ids, page_ids sorgulanir
    |
    v
Kullanicinin erisebilecegi menuler/sayfalar listelenir
```

---

## 8. Notifications (Bildirimler)

### 8.1 Tablo Yapisi

```sql
CREATE TABLE public.notifications (
    id uuid NOT NULL,
    title character varying,
    description text,
    notification_type CHECK ('ALERT', 'REMINDER', 'INFO'),
    priority smallint CHECK (0-11),
    entity_type CHECK ('INVOICE', 'PRODUCTION', 'PRODUCT', ...),
    entity_id uuid,

    -- Durum
    sent boolean,
    read boolean,
    acknowledged boolean,
    acknowledged_at timestamp,
    date_time timestamp,
    meta text,

    -- Iliskiler
    profile_id uuid,                   -- REFERENCES profiles(id)
    acknowledged_by uuid,              -- REFERENCES profiles(id)
    platform_id uuid,                  -- REFERENCES platforms(id)
    ...
);
```

### 8.2 Bildirim Akisi

```
Olay (Alarm, Fatura, vs.)
    |
    v
notifications INSERT
    |-- profile_id: Hedef kullanici
    |-- platform_id: Hangi platformdan
    |-- entity_type/entity_id: Ilgili kayit
    |
    v
Kullanici bildirimi okur/onaylar
    |
    +-- read = true
    +-- acknowledged = true
    +-- acknowledged_by = <profile_id>
```

---

## 9. Hiyerarsik Iliski Haritasi

### 9.1 Kullanici -> Hiyerarsi Yolu

```
+==================================================================================+
|                           KULLANICI HIYERARSI ILISKILERI                         |
+==================================================================================+
|                                                                                  |
|  PROFILES                                                                        |
|      |                                                                           |
|      +-- tenant_id --> TENANT                                                    |
|      |                                                                           |
|      +-- (realm_users.profile) <-- REALM_USERS                                   |
|              |                                                                   |
|              +-- tenant --> TENANT                                               |
|              +-- consumer --> ORGANIZATION                                       |
|              +-- contractor --> CONTRACTORS --> tenant_contractors --> TENANT    |
|              +-- sub_contractor --> SUB_CONTRACTORS                              |
|                                                                                  |
|  STAFFS                                                                          |
|      |                                                                           |
|      +-- tenant_id --> TENANT                                                    |
|      +-- organization_id --> ORGANIZATION --> tenant_id --> TENANT               |
|      +-- profile_id --> PROFILES                                                 |
|      +-- contractor_id --> CONTRACTORS                                           |
|      +-- sub_contractor_id --> SUB_CONTRACTORS                                   |
|      |                                                                           |
|      +-- (team_staffs.staff_id) <-- TEAMS --> tenant_teams --> TENANT            |
|                                                                                  |
+==================================================================================+
```

### 9.2 Kullanici Tiplerine Gore Erisim

| Kullanici Tipi | Tenant Erisimi | Organization Erisimi | Site/Unit Erisimi |
|----------------|----------------|---------------------|-------------------|
| Tenant Admin | Tum tenant | Tum organizasyonlar | Tum siteler/unitler |
| Org Kullanici | Kendi tenant'i | Kendi organization'i | Org'a ait site/unitler |
| Contractor | Atandigi tenant'lar | Atandigi org'lar | Atandigi site/unitler |
| Staff | Kendi tenant'i | Kendi org'u | Atandigi unitler |

---

## 10. Is Akisi Iliskileri

### 10.1 Staffs -> Work Requests

```sql
-- Work requests'te staff atamasi
work_requests.staff_id --> staffs(id)

-- Workflow'da staff atamasi
workflow_staffs.staff_id --> staffs(id)

-- Project'te staff atamasi
project_staffs.staff_id --> staffs(id)
```

### 10.2 Teams -> Workflows

```sql
-- Workflow'a takim atamasi (unit bazli)
workflow_teams.team_id --> teams(id)
workflow_teams.unit_id --> units(id)  -- Unit bazli atama!

-- Project'e takim atamasi
project_teams.team_id --> teams(id)
```

### 10.3 Contractors -> Work Requests

```sql
-- Work requests'te contractor atamasi
work_requests.contractor_id --> contractors(id)

-- Workflow'da contractor atamasi
workflow_contractors.contractor_id --> contractors(id)

-- Project'te contractor atamasi
project_contractors.contractor_id --> contractors(id)
```

---

## 11. Eksiklikler ve Oneriler

### 11.1 Kritik Eksiklikler

| # | Eksiklik | Tablo | Etki | Oneri |
|---|----------|-------|------|-------|
| 1 | Organization baglantisi | profiles | Profil sadece tenant seviyesinde | `organization_id` ekle |
| 2 | Site/Unit baglantisi | profiles, staffs | Saha bazli erisim kontrolu yok | `site_id`, `unit_id` ekle |
| 3 | Contractor tenant_id | contractors | Tenant iliskisi bridge uzerinden | Opsiyonel `primary_tenant_id` ekle |
| 4 | Team tenant_id | teams | Tenant iliskisi bridge uzerinden | Opsiyonel `tenant_id` ekle |

### 11.2 Guvenlik Eksiklikleri

| # | Eksiklik | Oneri |
|---|----------|-------|
| 1 | RLS yok | Profile/Staff icin Row Level Security ekle |
| 2 | Hiyerarsi dogrulama | Staff organization-tenant tutarliligi trigger |
| 3 | Silinmis kullanici | Soft delete standardizasyonu |

### 11.3 Onerilen Iyilestirmeler

#### 11.3.1 Profiles'a Organization Baglantisi

```sql
ALTER TABLE profiles ADD COLUMN organization_id uuid REFERENCES organizations(id);
ALTER TABLE profiles ADD COLUMN default_site_id uuid REFERENCES sites(id);

-- Dogrulama trigger
CREATE OR REPLACE FUNCTION validate_profile_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.organization_id IS NOT NULL AND NEW.tenant_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM organizations
            WHERE id = NEW.organization_id AND tenant_id = NEW.tenant_id
        ) THEN
            RAISE EXCEPTION 'Organization does not belong to tenant';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

#### 11.3.2 Kullanici Hiyerarsi View'i

```sql
CREATE VIEW user_hierarchy AS
SELECT
    p.id as profile_id,
    p.username,
    p.email,
    p.role,
    p.tenant_id,
    t.name as tenant_name,
    ru.consumer as organization_id,
    o.name as organization_name,
    s.id as staff_id,
    s.organization_id as staff_org_id,
    s.contractor_id,
    c.name as contractor_name,
    s.sub_contractor_id,
    sc.name as sub_contractor_name
FROM profiles p
LEFT JOIN tenants t ON t.id = p.tenant_id
LEFT JOIN realm_users ru ON ru.profile = p.id
LEFT JOIN organizations o ON o.id = ru.consumer
LEFT JOIN staffs s ON s.profile_id = p.id
LEFT JOIN contractors c ON c.id = s.contractor_id
LEFT JOIN sub_contractors sc ON sc.id = s.sub_contractor_id;
```

#### 11.3.3 Erisim Kontrol Fonksiyonu

```sql
CREATE OR REPLACE FUNCTION user_can_access_unit(
    p_profile_id uuid,
    p_unit_id uuid
) RETURNS boolean AS $$
DECLARE
    v_tenant_id uuid;
    v_org_id uuid;
BEGIN
    -- Kullanicinin tenant ve organization'ini al
    SELECT p.tenant_id, ru.consumer INTO v_tenant_id, v_org_id
    FROM profiles p
    LEFT JOIN realm_users ru ON ru.profile = p.id
    WHERE p.id = p_profile_id;

    -- Unit'in hiyerarsisini kontrol et
    RETURN EXISTS (
        SELECT 1 FROM units u
        JOIN sites s ON s.id = u.site_id
        JOIN organizations o ON o.id = s.organization_id
        WHERE u.id = p_unit_id
          AND o.tenant_id = v_tenant_id
          AND (v_org_id IS NULL OR o.id = v_org_id)
    );
END;
$$ LANGUAGE plpgsql;
```

---

## 12. Sonuc

### 12.1 Guclu Yanlar

- Esnek kullanici tipleri (Tenant, Org, Contractor, Staff)
- Menu/sayfa bazli erisim kontrolu
- Keycloak/Auth entegrasyonu (realm_users)
- Takim yapisi ve staff atamalari

### 12.2 Zayif Yanlar

- Profiles sadece Tenant seviyesinde (Organization/Site/Unit yok)
- Contractors ve Teams icin dogrudan tenant_id yok
- Site/Unit bazli erisim kontrolu eksik
- RLS politikalari yok

### 12.3 Aksiyon Onerileri

| Oncelik | Aksiyon |
|---------|---------|
| YUKSEK | Profiles'a organization_id ekle |
| YUKSEK | User hierarchy view olustur |
| ORTA | Contractors/Teams'e tenant_id ekle |
| ORTA | Site/Unit erisim fonksiyonlari |
| DUSUK | RLS politikalari |

---

## 13. Iliski Diyagrami

```
                         +------------------+
                         |     tenants      |
                         +------------------+
                                 |
         +-----------------------+-----------------------+
         |                       |                       |
         v                       v                       v
+------------------+    +------------------+    +------------------+
| tenant_contractors|   | tenant_teams     |    |   organizations  |
| (N:N bridge)     |    | (N:N bridge)     |    +------------------+
+------------------+    +------------------+            |
         |                       |                      |
         v                       v                      v
+------------------+    +------------------+    +------------------+
|   contractors    |    |     teams        |    |     staffs       |
+------------------+    +------------------+    +------------------+
         |                       |                      |
         |                       v                      |
         |              +------------------+            |
         |              |   team_staffs    |<-----------+
         |              | (N:N bridge)     |
         |              +------------------+
         |                                              |
         +-----------------+----------------------------+
                           |
                           v
                  +------------------+
                  |   realm_users    |
                  +------------------+
                           |
                           v
                  +------------------+
                  |    profiles      |
                  +------------------+
                           |
       +-------------------+-------------------+
       |                   |                   |
       v                   v                   v
+------------+      +------------+      +------------+
| menu_ids   |      |sub_menu_ids|      | page_ids   |
+------------+      +------------+      +------------+
       |                   |                   |
       v                   v                   v
+------------+      +------------+      +------------+
|   menus    |      | sub_menus  |----->|   pages    |
+------------+      +------------+      +------------+
```
