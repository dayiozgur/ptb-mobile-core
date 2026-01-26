# Tamamlayici Tablolar Analizi

Bu dokuman, ana hiyerarsik yapi (Platform -> Tenant -> Organization -> Site -> Unit -> Controller -> Variable), Workflow sistemi ve Kullanici Yonetimi dokumanlari disinda kalan tablolarin analizini icerir.

---

## 1. Envanter ve Varlik Yonetimi (Inventory & Asset)

### 1.1 Ana Tablolar

#### inventories
Envanter tanimlari - varlik gruplarini yonetir.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| organization_id | uuid | FK -> organizations |
| unit_id | uuid | FK -> units |
| inventory_type_id | uuid | FK -> inventory_types |
| contractor_id | uuid | FK -> contractors |
| staff_id | uuid | FK -> staffs |
| team_id | uuid | FK -> teams |
| project_work_request_id | uuid | FK -> projects |
| task_work_request_id | uuid | FK -> tasks |
| workflow_work_request_id | uuid | FK -> workflows |
| code, name, description | varchar | Tanimlayici alanlar |

**Hiyerarsi Baglantilari:**
- Tenant -> Organization -> Unit yoluyla hiyerarsiye baglanir
- Work request sistemiyle entegre (project, task, workflow)
- Contractor, Staff, Team atamalari destekler

#### inventory_items
Envanterdeki fiziksel ogeler.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| inventory_id | uuid | FK -> inventories |
| item_id | uuid | FK -> items |
| production_id | uuid | FK -> productions |
| quantity | double | Miktar |
| reserved_quantity | double | Rezerve miktar |
| barcode, qrcode, serial | varchar | Tanimlayicilar |
| stock_status | enum | IN_STOCK, OUT_OF_STOCK, LOW_STOCK, RESERVED, ON_ORDER, DISCONTINUED, DAMAGED, UNDER_MAINTENANCE |

#### inventory_item_movements
Envanter hareketleri - stok giriş/çıkış takibi.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| item_id | uuid | FK -> items |
| from_inventory_id | uuid | FK -> inventories (kaynak) |
| to_inventory_id | uuid | FK -> inventories (hedef) |
| from_location_id | uuid | FK -> locations |
| to_location_id | uuid | FK -> locations |
| unit_id | uuid | FK -> units |
| staff_id | uuid | FK -> staffs |
| approved_by_id | uuid | FK -> staffs (onaylayan) |
| movement_type | enum | IN, OUT, TRANSFER, ADJUSTMENT, RETURN, SCRAP, FOUND, LOST, RESERVE, UNRESERVE, CONSUME, PRODUCTION |
| approval_status | enum | PENDING, APPROVED, REJECTED, CANCELLED, DRAFT |
| quantity, unit_cost, total_cost | double | Maliyet bilgileri |

#### inventory_types
Envanter tipi tanimlari.

```
inventories (tenant_id, organization_id, unit_id)
    |
    +-- inventory_items (inventory_id, item_id)
    |       |
    |       +-- items (brand_id, device_model_id, current_unit_id)
    |
    +-- inventory_item_movements (transfer tracking)
```

### 1.2 Varlik (Item) Tablolari

#### items
Fiziksel varliklar - cihazlar, ekipmanlar, urunler.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| type | varchar | Varlik tipi discriminator |
| tenant_id | uuid | FK -> tenants |
| brand_id | uuid | FK -> brands (NOT NULL) |
| device_model_id | uuid | FK -> device_models |
| device_type_id | uuid | FK -> device_types |
| vendor_id | uuid | FK -> vendors |
| catalog_id | uuid | FK -> catalogs |
| production_id | uuid | FK -> productions |
| current_unit_id | uuid | FK -> units (mevcut konum) |
| code, name, description | varchar | Tanimlayici alanlar |
| barcode, serial_number | varchar | Fiziksel tanimlayicilar |
| unit_price, currency | double, varchar | Fiyat bilgisi |
| min_stock_level, max_stock_level, reorder_level | double | Stok seviyeleri |
| installation_date, last_maintenance_at, next_maintenance_at | timestamp | Bakim takibi |
| warranty_months | int | Garanti suresi |
| is_used, used_by, used_date | boolean, uuid, timestamp | Kullanim durumu |
| manufactured_at, expires_at | timestamp | Uretim/son kullanim |
| is_verified, published | boolean | Dogrulama durumu |

**ONEMLI: items.current_unit_id ile Unit hiyerarsisine baglanir - varlik konum takibi.**

#### item_location_history
Varlik konum degisikligi gecmisi.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| item_id | uuid | FK -> items |
| from_unit_id | uuid | FK -> units (eski konum) |
| to_unit_id | uuid | FK -> units (yeni konum) |
| movement_type_id | uuid | FK -> categories |
| status | enum | PENDING, IN_TRANSIT, COMPLETED, CANCELLED |
| moved_by | uuid | Tasiyici |
| approved_by, approved_at | uuid, timestamp | Onay bilgisi |
| requires_approval | boolean | Onay gerekli mi |
| movement_reason, notes | text | Aciklamalar |

#### item_characteristics
Varlik ozellikleri - dinamik ozellik sistemi.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| item_id | uuid | FK -> items |
| characteristic_id | uuid | FK -> characteristics |
| value | text | Ozellik degeri |

### 1.3 Iliskili Tablolar

| Tablo | Aciklama | Hiyerarsi Baglantisi |
|-------|----------|---------------------|
| brands | Marka tanimlari | Bagimsiz lookup |
| catalogs | Katalog tanimlari | tenant_id |
| vendors | Tedarikci tanimlari | Bagimsiz |
| characteristics | Dinamik ozellik tanimlari | Bagimsiz |
| characteristic_values | Ozellik degerleri | tenant_id |

---

## 2. Alarm ve Izleme Sistemi (Alarm & Monitoring)

### 2.1 Cekirdek Alarm Tablolari

#### alarms
Aktif alarmlar - canli alarm durumu.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| controller_id | uuid | FK -> controllers |
| variable_id | uuid | FK -> variables |
| realtime_id | uuid | FK -> realtimes (UNIQUE) |
| priority_id | uuid | FK -> priorities |
| txn_id | uuid | FK -> txns |
| code, name, description | varchar | Alarm bilgileri |
| status | varchar | Alarm durumu |
| category | int | Kategori |
| start_time, end_time | timestamp | Zaman araligı |
| is_logic, inhibited | boolean | Mantik/engellenme |
| local_acknowledge_time/user | timestamp, varchar | Lokal onay |
| remote_acknowledge_time/user | timestamp, uuid | Uzak onay |
| reset_time/user | timestamp, varchar | Sifirlama |

**Hiyerarsi Baglantisi:** Controller -> Variable -> Realtime yoluyla IoT katmanina baglanir.

#### alarm_histories
Alarm gecmisi - tum alarm kayitlari (denormalized).

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants (denormalized) |
| organization_id | uuid | FK -> organizations (denormalized) |
| site_id | uuid | FK -> sites (denormalized) |
| controller_id | uuid | FK -> controllers |
| provider_id | uuid | FK -> providers |
| variable_id | uuid | FK -> variables |
| realtime_id | uuid | FK -> realtimes |
| priority_id | uuid | FK -> priorities |
| contractor_id | uuid | FK -> contractors |
| canceled_controller_id | uuid | FK -> controllers |
| txn_id | uuid | FK -> txns |
| ... (alarm detaylari) | | alarms ile ayni alanlar |

**ONEMLI:** alarm_histories tablosu performans icin denormalize edilmis - tenant_id, organization_id, site_id dogrudan bu tabloda tutulur.

### 2.2 Alarm Analitik Tablolari (ML/AI)

#### alarm_analytics_sessions
Alarm analiz oturumlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| ... | | Oturum bilgileri |

#### alarm_patterns
Tespit edilen alarm desenleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| session_id | uuid | FK -> alarm_analytics_sessions |
| pattern_type | varchar | Desen tipi |
| pattern_name, pattern_description | varchar, text | Desen bilgileri |
| confidence_score | double | Guven skoru |
| frequency_score | double | Frekans skoru |
| severity_impact | varchar | Ciddiyet etkisi |
| affected_controllers | array | Etkilenen kontrolorler |
| affected_variables | array | Etkilenen degiskenler |
| time_window | jsonb | Zaman penceresi |
| statistical_data | jsonb | Istatistiksel veriler |
| ml_features | jsonb | ML ozellikleri |

#### alarm_predictions
Tahminsel alarm analizleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| session_id | uuid | FK -> alarm_analytics_sessions |
| controller_id | uuid | FK -> controllers |
| variable_id | uuid | FK -> variables |
| predicted_alarm_time | timestamp | Tahmini alarm zamani |
| prediction_confidence | double | Tahmin guveni |
| prediction_type | varchar | Tahmin tipi |
| risk_level | varchar | Risk seviyesi |
| predicted_duration_hours | double | Tahmini sure |
| prevention_window_hours | double | Onleme penceresi |
| maintenance_recommendation | jsonb | Bakim onerileri |
| model_version | varchar | Model versiyonu |
| feature_importance | jsonb | Ozellik onemliligi |

#### alarm_correlations
Alarm korelasyonlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| session_id | uuid | FK -> alarm_analytics_sessions |
| ... | | Korelasyon metrikleri |
| statistical_significance | double | Istatistiksel anlamlilik |
| business_impact_score | double | Is etkisi skoru |

#### alarm_statistics
Alarm istatistikleri - zaman serisi ozet verileri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| date_key | date | Tarih |
| hour_key | int | Saat |
| controller_id, variable_id | uuid | Iliskili varliklar |
| total_alarms | int | Toplam alarm |
| avg/min/max_duration_minutes | double | Sure istatistikleri |
| critical_alarms, resolved_alarms | int | Kritik/cozulen |
| mttr_minutes | double | Ortalama onarim suresi |
| mtbf_hours | double | Ariza arasi ortalama sure |
| performance_score | double | Performans skoru |

### 2.3 Alarm Operasyon Tablolari

#### alarm_operation_actions
Alarm operasyon aksiyonlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| alarm_id | uuid | FK -> alarms |
| operation_action_id | uuid | FK -> operation_actions |
| process_time | timestamp | Islem zamani |

#### operation_methods / operation_actions
Operasyon metod ve aksiyonlari.

```
alarm_analytics_sessions
    |
    +-- alarm_patterns
    +-- alarm_predictions
    +-- alarm_correlations

alarms
    |
    +-- alarm_histories (archive)
    +-- alarm_operation_actions
    +-- alarm_statistics (aggregated)
```

---

## 3. Enerji ve Karbon Yonetimi

### 3.1 Enerji Tablolari

#### energy_configurations
Enerji yapilandirmalari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| co2kwh | double | kWh basina CO2 |
| cost | double | Birim maliyet |
| currency | varchar | Para birimi |

#### energy_consumptions
Enerji tuketim kayitlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| fixed_asset_id | uuid | FK -> items |
| weather_data_id | uuid | FK -> weather_datas |
| consumption_value | double | Tuketim degeri |
| consumption_unit | varchar | Birim |
| timestamp | timestamp | Zaman damgasi |
| measurement_period | varchar | Olcum periyodu |

#### energy_groups
Enerji gruplari - controller gruplamasi.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| reference_entity, reference_id | varchar | Referans entity |
| is_enable | boolean | Aktif mi |

#### energy_group_controllers
Gruba ait kontrolorler.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| energy_group_id | uuid | FK -> energy_groups |
| controller_id | uuid | FK -> controllers |
| measurement_id | uuid | FK -> measurements |

#### energy_variables
Enerji degiskenleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| variable_id | uuid | FK -> variables |
| measurement_id | uuid | FK -> measurements |

#### new_energy_readings (TimescaleDB Hypertable)
Yeni enerji okumalari - zaman serisi verisi.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| time | timestamp | Zaman (partition key) |
| controller_id | uuid | FK -> controllers |
| variable_id | uuid | FK -> variables |
| variable_code | varchar | Degisken kodu |
| value | double | Deger |
| unit | varchar | Birim |
| device_name, device_type | varchar | Cihaz bilgileri |
| site_name, area_name | varchar | Konum bilgileri |
| reading_type | varchar | Okuma tipi |
| phase | int | Faz |
| data_quality | int | Veri kalitesi (0-100) |
| is_estimated | boolean | Tahmini mi |

#### new_energy_consumption_summaries
Enerji tuketim ozetleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| controller_id, time, period_type | composite PK | |
| first_reading, last_reading | double | Ilk/son okuma |
| consumption | double | Tuketim |
| average_power, max_power, min_power | double | Guc istatistikleri |
| anomaly_detected | boolean | Anomali tespit |

#### new_energy_device_configs
Enerji cihaz yapilandirmalari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| controller_id | uuid | FK -> controllers (UNIQUE) |
| primary_energy_variable_id | uuid | FK -> variables |
| device_name, device_type | varchar | Cihaz bilgileri |
| calculation_method | varchar | Hesaplama yontemi |
| reset_detection | boolean | Sifirlama tespiti |
| max_daily_consumption | double | Maks gunluk tuketim |
| dashboard_visible | boolean | Dashboard'da gorunsun mu |

### 3.2 Karbon ve Emisyon Tablolari

#### carbon_emissions
Karbon emisyon kayitlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| emission_factor_id | uuid | FK -> emission_factors |
| energy_consumption_id | uuid | FK -> energy_consumptions |
| fixed_asset_id | uuid | FK -> items |
| source_type | enum | ELECTRICITY, NATURAL_GAS, HEATING_OIL, DIESEL, GASOLINE, BIOMASS, COAL, PROPANE, REFRIGERATION, TRANSPORTATION, WASTE, WATER |
| value | double | Emisyon degeri |
| timestamp | timestamp | Zaman |

#### emission_factors
Emisyon faktoru tanimlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| area_id | uuid | FK -> areas |
| source_type | enum | Kaynak tipi |
| value | double | Faktor degeri |
| unit | varchar | Birim |
| year | int | Yil |

#### emission_reports
Emisyon raporlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| unit_id | uuid | FK -> units |
| weather_data_id | uuid | FK -> weather_datas |
| period_type | enum | DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY, CUSTOM |
| period_start, period_end | date | Periyot |
| total_emissions, target_emissions | double | Emisyonlar |
| variance_percentage | double | Sapma yuzdesi |
| status | enum | ACTIVE, INACTIVE, PENDING, COMPLETED, CANCELLED, DRAFT |

#### emission_targets
Emisyon hedefleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| unit_id | uuid | FK -> units |
| baseline_emissions | double | Baz emisyon |
| target_emissions | double | Hedef emisyon |
| target_reduction_percentage | double | Hedef azalma % |
| start_date, end_date | date | Gecerlilik |
| year | int | Yil |
| status | enum | Durum |

---

## 4. Takvim ve Yapilacaklar (Calendar & Todo)

### 4.1 Takvim Tablolari

#### calendar_events
Takvim etkinlikleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| created_by | uuid | Olusturan |
| title | varchar | Baslik |
| description | text | Aciklama |
| location | varchar | Konum |
| event_type | enum | MEETING, REMINDER, DEADLINE, PERSONAL, OTHER |
| start_time, end_time | timestamp | Zaman araligi |
| all_day | boolean | Tum gun |
| is_recurring | boolean | Tekrarlayan mi |
| recurrence_pattern | jsonb | Tekrar deseni |
| parent_event_id | uuid | FK -> calendar_events (self-ref) |
| recurrence_exception_dates | array | Istisna tarihleri |
| linked_todo_id | uuid | FK -> todo_items |
| status | enum | SCHEDULED, COMPLETED, CANCELLED |

**Hiyerarsi Baglantisi:** Tenant bazli, todo_items ile entegre.

#### event_attendees
Etkinlik katilimcilari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| event_id | uuid | FK -> calendar_events |
| attendee_id | uuid | FK -> staffs |
| rsvp_status | enum | PENDING, ACCEPTED, DECLINED, TENTATIVE |
| is_organizer | boolean | Organizator mu |
| is_required | boolean | Zorunlu mu |
| invited_by | varchar | Davet eden |

### 4.2 Todo Tablolari

#### todo_items
Yapilacak isler.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| created_by | uuid | Olusturan |
| assigned_to | uuid | FK -> staffs |
| title | varchar | Baslik |
| description | text | Aciklama |
| priority | enum | LOW, MEDIUM, HIGH, URGENT |
| status | enum | NOT_STARTED, IN_PROGRESS, COMPLETED, CANCELLED |
| due_date | timestamp | Bitis tarihi |
| completed_at | timestamp | Tamamlanma |
| linked_event_id | uuid | FK -> calendar_events |

#### todo_shares
Todo paylasimlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| todo_id | uuid | FK -> todo_items |
| shared_with_user | uuid | FK -> staffs |
| shared_with_team | uuid | FK -> teams |
| shared_with_department | uuid | FK -> departments |
| can_edit, can_delete | boolean | Izinler |
| shared_by | varchar | Paylasan |

#### todo_calendar_notifications
Takvim/todo bildirimleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| user_id | varchar | Kullanici |
| todo_id | uuid | FK -> todo_items |
| event_id | uuid | FK -> calendar_events |
| notification_type | enum | TODO_DUE_SOON, TODO_OVERDUE, TODO_ASSIGNED, TODO_SHARED, TODO_UPDATED, EVENT_REMINDER, EVENT_INVITATION, EVENT_UPDATED, EVENT_CANCELLED, EVENT_RSVP_RESPONSE |
| title | varchar | Baslik |
| message | text | Mesaj |
| is_read | boolean | Okundu mu |
| scheduled_for | timestamp | Planli zaman |

#### todo_item_audit_logs
Todo degisiklik kayitlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| todo_id | uuid | |
| tenant_id | uuid | |
| operation | enum | INSERT, UPDATE, DELETE |
| old_data, new_data | jsonb | Eski/yeni veri |
| changed_fields | array | Degisen alanlar |
| changed_by | varchar | Degistiren |
| ip_address | inet | IP adresi |
| user_agent | text | Kullanici ajani |

---

## 5. Perakende ve Magaza Yonetimi (Retail/Store)

### 5.1 Magaza Tablolari

#### retail_chains
Perakende zincirleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant | uuid | FK -> tenants |
| ... | | Zincir bilgileri |

#### stores
Magazalar.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| retail_chain_id | uuid | FK -> retail_chains |
| tenant | uuid | FK -> tenants |
| external_id | varchar | Dis sistem ID |
| name, code, description | varchar | Tanimlayicilar |
| address | text | Adres |
| city_id | int | FK -> cities |
| district_id | int | FK -> districts |
| state_id | int | FK -> states |
| country_id | varchar | FK -> countries |
| postal_code | varchar | Posta kodu |
| latitude, longitude | numeric | Koordinatlar |
| phone, email | varchar | Iletisim |
| status | enum | active, inactive, temporarily_closed, under_renovation |
| opening_date, closing_date | date | Acilis/kapanis |
| store_type | varchar | Magaza tipi |
| store_size_sqm | int | Alan (m2) |
| parking_available, accessible_entrance | boolean | Olanaklar |
| last_updated_from_api | timestamp | API guncelleme |
| api_data_hash | varchar | API veri hash |

#### store_contacts
Magaza iletisim bilgileri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| store_id | uuid | FK -> stores |
| contact_type | enum | phone, fax, email, whatsapp, social_media |
| contact_value | varchar | Deger |
| is_primary | boolean | Birincil mi |
| display_order | int | Siralama |

#### store_operating_hours
Magaza calisma saatleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| store_id | uuid | FK -> stores |
| day_of_week | int | Gun (0-6) |
| day_name | varchar | Gun adi |
| open_time, close_time | time | Acilis/kapanis |
| is_24_hours | boolean | 7/24 mi |
| is_closed | boolean | Kapali mi |
| is_holiday_hours | boolean | Tatil saatleri mi |
| effective_from, effective_to | date | Gecerlilik |

#### store_services
Magaza hizmetleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| store_id | uuid | FK -> stores |
| service_name, service_code | varchar | Hizmet |
| description | text | Aciklama |
| is_available | boolean | Mevcut mu |
| category | varchar | Kategori |

#### data_sync_logs
Veri senkronizasyon kayitlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| retail_chain_id | uuid | FK -> retail_chains |
| tenant | uuid | |
| sync_type | enum | manual, automatic, scheduled |
| sync_status | enum | started, completed, failed, partial |
| records_processed/inserted/updated/failed | int | Kayit sayilari |
| error_message, error_details | text, jsonb | Hata bilgileri |
| started_at, completed_at | timestamp | Zaman |
| duration_seconds | int | Sure |

---

## 6. Finansal Tablolar

### 6.1 Fatura Tablolari

#### invoices
Faturalar.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| unit_id | uuid | FK -> units |
| vendor_id | uuid | FK -> vendors |
| approving_id | uuid | FK -> realm_users |
| characteristics_id | uuid | FK -> characteristics |
| invoice_number | varchar | Fatura no |
| invoice_date | timestamp | Fatura tarihi |
| due_date | timestamp | Vade |
| ettn | varchar | e-Fatura no |
| details_amount, discount_amount, sub_total_amount | double | Tutarlar |
| vat_amount, vat_rate | double | KDV |
| total_amount, total_price | double | Toplam |
| *_currency | varchar | Para birimleri (USD, EUR, TRY) |
| approved | boolean | Onaylandi mi |
| approve_date | timestamp | Onay tarihi |
| payment_status | enum | PENDING, PAID, CANCELLED, CONFIRMED, REJECTED |
| period_start_date, period_end_date | timestamp | Fatura donemi |

**Hiyerarsi Baglantisi:** Tenant -> Unit yoluyla hiyerarsiye baglanir.

#### invoice_details
Fatura satirlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| invoice_id | uuid | FK -> invoices |
| tenant_id | uuid | FK -> tenants |
| characteristic_id | uuid | FK -> characteristics |
| item_no, description | varchar | Kalem bilgileri |
| quantity, unit_price | double | Miktar/birim fiyat |
| amount, discount_amount | double | Tutar/indirim |
| gross_amount, net_amount | double | Brut/net |
| vat_amount, vat_rate | double | KDV |

### 6.2 Diger Finansal Tablolar

#### financials
Finansal bilgiler (contractor/sub_contractor icin).

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| account_name, account_number | varchar | Hesap bilgileri |
| account_type | varchar | Hesap tipi |
| bank_name, bank_address, bank_city, bank_country, bank_state | varchar | Banka bilgileri |
| iban, swift | varchar | IBAN/SWIFT |
| tax_number, tax_office | varchar | Vergi bilgileri |

#### customers
Musteriler (CRM).

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| person_id | uuid | FK -> persons |
| assigned_to_staff_id | uuid | FK -> staffs |
| staff_organization_id | uuid | FK -> staff_organizations |
| is_potential | boolean | Potansiyel mi |
| value | double | Deger |
| note | varchar | Not |

#### deals
Firsatlar/anlasmakar.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| customer_id | uuid | FK -> customers |
| assigned_to_staff_id | uuid | FK -> staffs |
| name | varchar | Isim |
| value | double | Deger |
| status | enum | DRAFT, PENDING, APPROVED, REJECTED, CANCELLED, COMPLETED |
| type | smallint | Tip (0-35) |

---

## 7. Uretim ve Bakim (Production & Maintenance)

### 7.1 Uretim Tablolari

#### productions
Uretim kayitlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant | uuid | FK -> tenants |
| blueprint_id | uuid | FK -> blueprints |
| code, name, description | varchar | Tanimlayicilar |
| quantity | double | Miktar |
| production_method | enum | AUTOMATIC, MANUAL |
| status | enum | CHECKING, WAITING, STARTED, IN_PROGRESS, PAUSED, DONE, PUBLISHED |
| remote_id | uuid | Uzak sistem ID |

#### production_orders
Uretim emirleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| blueprint_id | uuid | |
| confirmation_id | uuid | FK -> confirmations (UNIQUE) |
| inventory_id | uuid | FK -> inventories |
| work_request_id | uuid | FK -> work_requests |
| external_identifier | varchar | Dis sistem ID |
| quantity | double | Miktar |
| status | enum | CREATED, PRODUCTION |

#### production_characteristics
Uretim ozellikleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| production_id | uuid | FK -> productions |
| characteristic_id | uuid | FK -> characteristics |
| value | text | Deger |

### 7.2 Bakim Tablolari

#### maintenance_records
Bakim kayitlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants |
| item_id | uuid | FK -> items |
| unit_id | uuid | FK -> units |
| contractor_id | uuid | FK -> contractors |
| sub_contractor_id | uuid | FK -> sub_contractors |
| assigned_staff_id | uuid | FK -> staffs |
| description | text | Aciklama |
| maintenance_at | timestamp | Bakim zamani |
| status | enum | PENDING, APPROVED, REJECTED, COMPLETED |

---

## 8. Raporlama ve KPI

### 8.1 Rapor Tablolari

#### report_types
Rapor tipleri.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| code, name, description | varchar | Tanimlayicilar |

#### report_templates
Rapor sablonlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| tenant_id | uuid | FK -> tenants (NOT NULL) |
| site | uuid | FK -> sites |
| provider | uuid | FK -> providers |
| controller | uuid | FK -> controllers |
| report_type_id | uuid | FK -> report_types |
| frequency, period | varchar | Frekans/periyot |
| high/low_threshold | int | Esik degerleri |
| is_kpi_group | boolean | KPI grubu mu |

**Hiyerarsi Baglantisi:** Tenant bazli, Site/Provider/Controller ile iliskilendirilebilir.

#### report_template_controllers / report_template_realtimes / report_template_variables
Rapor sablonu iliskileri (N:N).

#### report_fields
Rapor alanlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| report_type_id | uuid | FK -> report_types |
| code, name, description | varchar | Tanimlayicilar |

### 8.2 KPI Tablolari

#### kpi_groups
KPI gruplari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| reference_entity, reference_id | varchar | Referans entity |
| code, name, description | varchar | Tanimlayicilar |

#### kpi_group_controllers
KPI grup kontrolorleri (N:N).

#### kpi_reports
KPI raporlari.

| Kolon | Tip | Aciklama |
|-------|-----|----------|
| id | uuid | Primary Key |
| reference_entity, reference_id | varchar | Referans entity |
| high/low_threshold | int | Esik degerleri |
| max_high/low_threshold_percentage | int | Maks sapma yuzdesi |

### 8.3 Log Tablolari

#### log_reports
Log raporlari.

#### log_report_controllers
Log raporu kontrolorleri (N:N).

---

## 9. Destekleyici/Lookup Tablolari

### 9.1 Coğrafi Tablolar

| Tablo | Aciklama | Hiyerarsi |
|-------|----------|-----------|
| countries | Ulkeler | - |
| states | Eyaletler/Iller | country_id |
| cities | Sehirler | state_id |
| districts | Ilceler | city_id, state_id |
| locations | Genel konum bilgileri | - |
| location_histories | Konum gecmisi | - |
| areas | Alanlar | contractor_id |

### 9.2 Cihaz ve IoT Tablolari

| Tablo | Aciklama | Hiyerarsi |
|-------|----------|-----------|
| device_types | Cihaz tipleri (self-ref) | parent_type_id |
| device_models | Cihaz modelleri | brand_id, device_type_id, organization_id |
| device_properties | Cihaz ozellikleri | device_model_id |
| device_variables | Cihaz degiskenleri | device_property_id, variable_id |
| devices | Cihazlar | brand_id, device_model_id, device_type_id |
| supervisor_types | Supervisor tipleri | - |
| supervisors | Supervisor'lar | site_id |
| supervisor_controllers | Supervisor-Controller N:N | - |
| protocol_types | Protokol tipleri | - |

### 9.3 Sistem ve Yapilandirma

| Tablo | Aciklama | Kullanim |
|-------|----------|----------|
| languages | Diller | Lokalizasyon |
| lang_values | Dil degerleri | Ceviri |
| keywords | Anahtar kelimeler | Lokalizasyon |
| categories | Kategoriler (self-ref) | Genel kategorizasyon |
| preference_types | Tercih tipleri | Kullanici tercihleri |
| preferences | Tercihler | profile_id |
| query_limits | Sorgu limitleri | Performans |
| ftp_users | FTP kullanicilari | tenant_id |
| http_logs | HTTP loglari | Audit |

### 9.4 Islem (Transaction) Tablolari

| Tablo | Aciklama | Kullanim |
|-------|----------|----------|
| txn_types | Islem tipleri | - |
| txns | Islemler | controller_id, provider_id, txn_type_id |
| confirmations | Onaylar | Uretim onaylari |
| ratings | Degerlendirmeler | tenant_id |
| tickets | Destek talepleri | tenant_id |

### 9.5 Diger Tablolar

| Tablo | Aciklama | Kullanim |
|-------|----------|----------|
| markers | Isaret/etiketler | Provider/Controller icin |
| measurements | Olcumler | provider_id, devicemodel_id |
| priorities | Oncelikler | Alarm/is oncelikleri |
| cancelled_controllers | Iptal edilen kontrolorler | Arsiv |
| departments | Departmanlar | Organizasyon yapisi |
| weather_datas | Hava durumu verileri | Enerji/emisyon analizi |
| persons | Kisiler | CRM |

---

## 10. Hiyerarsi Baglanti Ozeti

### 10.1 Tenant Bazli Tablolar

Bu tablolar dogrudan tenant_id ile hiyerarsiye baglanir:

```
TENANT
  |
  +-- inventories, inventory_types, inventory_item_movements
  +-- items, catalogs
  +-- alarm_histories (denormalized)
  +-- energy_consumptions, carbon_emissions
  +-- emission_factors, emission_reports, emission_targets
  +-- calendar_events, todo_items
  +-- retail_chains, stores
  +-- invoices, invoice_details
  +-- financials, customers, deals
  +-- productions, production_orders
  +-- report_templates
  +-- ratings, tickets, ftp_users
```

### 10.2 Unit Bazli Tablolar

Bu tablolar unit_id ile daha derin hiyerarsi baglantisi kurar:

```
UNIT
  |
  +-- inventories (unit_id)
  +-- inventory_item_movements (unit_id)
  +-- item_location_history (from_unit_id, to_unit_id)
  +-- items (current_unit_id)
  +-- emission_reports, emission_targets (unit_id)
  +-- invoices (unit_id)
  +-- maintenance_records (unit_id)
  +-- unit_schedules (unit_id)
  +-- unit_characteristics (unit_id)
```

### 10.3 Controller/Variable Bazli Tablolar

Bu tablolar IoT katmanina baglanir:

```
CONTROLLER
  |
  +-- alarms (controller_id)
  +-- alarm_histories (controller_id)
  +-- alarm_predictions (controller_id)
  +-- alarm_statistics (controller_id)
  +-- energy_group_controllers (controller_id)
  +-- new_energy_readings (controller_id)
  +-- new_energy_consumption_summaries (controller_id)
  +-- new_energy_device_configs (controller_id)
  +-- txns (controller_id)
  +-- kpi_group_controllers (controller_id)
  +-- report_template_controllers (controller_id)
  +-- log_report_controllers (controller_id)

VARIABLE
  |
  +-- alarms (variable_id)
  +-- alarm_histories (variable_id)
  +-- alarm_predictions (variable_id)
  +-- alarm_statistics (variable_id)
  +-- energy_variables (variable_id)
  +-- new_energy_readings (variable_id)
  +-- new_energy_device_configs (primary_energy_variable_id)
  +-- device_variables (variable_id)
  +-- report_template_variables (variable_id)
```

---

## 11. Tespit Edilen Eksiklikler

### 11.1 Hiyerarsi Baglanti Eksiklikleri

| Tablo | Eksik Alan | Aciklama | Oneri |
|-------|------------|----------|-------|
| stores | organization_id | Site/Unit hiyerarsisine baglanamaz | organization_id, site_id ekle |
| calendar_events | organization_id, unit_id | Sadece tenant bazli | Hiyerarsi baglantisi ekle |
| todo_items | organization_id, unit_id | Sadece tenant bazli | Hiyerarsi baglantisi ekle |
| productions | organization_id, unit_id | Sadece tenant bazli | Hiyerarsi baglantisi ekle |
| energy_groups | tenant_id | Tenant baglantisi yok | tenant_id ekle |
| kpi_groups | tenant_id | Tenant baglantisi yok | tenant_id ekle |
| kpi_reports | tenant_id | Tenant baglantisi yok | tenant_id ekle |

### 11.2 Veri Butunlugu Eksiklikleri

| Tablo | Sorun | Oneri |
|-------|-------|-------|
| inventory_item_movements | Varsayilan gen_random_uuid() FK'lar | NULL olabilmeli |
| new_energy_device_configs | controller_id UNIQUE | Birden fazla config gerekebilir |
| items | brand_id NOT NULL | Marka zorunlu olmayabilir |

### 11.3 Index Onerileri

```sql
-- Sik sorgulanan alanlara index
CREATE INDEX idx_alarm_histories_tenant_date ON alarm_histories(tenant_id, created_at);
CREATE INDEX idx_stores_retail_chain ON stores(retail_chain_id);
CREATE INDEX idx_items_current_unit ON items(current_unit_id);
CREATE INDEX idx_todo_items_tenant_status ON todo_items(tenant_id, status);
CREATE INDEX idx_calendar_events_tenant_time ON calendar_events(tenant_id, start_time);
CREATE INDEX idx_inventory_items_stock_status ON inventory_items(stock_status);
```

---

## 12. ASCII Diagram - Tamamlayici Tablolar

```
+===========================================================================+
|                     TAMAMLAYICI TABLOLAR HARITASI                          |
+===========================================================================+

TENANT
   |
   +-- ENVANTER/VARLIK ---------------+-- ALARM/IZLEME -----------------+
   |   inventories                    |   alarms <-> alarm_histories   |
   |   +-- inventory_items            |   +-- alarm_patterns           |
   |   +-- inventory_item_movements   |   +-- alarm_predictions        |
   |   items <-> item_location_history|   +-- alarm_statistics         |
   |                                  |   alarm_operation_actions      |
   +----------------------------------+----------------------------------+
   |
   +-- ENERJI/KARBON -----------------+-- TAKVIM/TODO ------------------+
   |   energy_consumptions            |   calendar_events              |
   |   +-- energy_groups              |   +-- event_attendees          |
   |   +-- energy_variables           |   todo_items                   |
   |   carbon_emissions               |   +-- todo_shares              |
   |   +-- emission_factors           |   todo_calendar_notifications  |
   |   +-- emission_reports           |                                |
   |   +-- emission_targets           |                                |
   +----------------------------------+----------------------------------+
   |
   +-- PERAKENDE ---------------------+-- FINANSAL ---------------------+
   |   retail_chains                  |   invoices                     |
   |   +-- stores                     |   +-- invoice_details          |
   |       +-- store_contacts         |   financials                   |
   |       +-- store_operating_hours  |   customers                    |
   |       +-- store_services         |   +-- deals                    |
   |   data_sync_logs                 |                                |
   +----------------------------------+----------------------------------+
   |
   +-- URETIM/BAKIM ------------------+-- RAPORLAMA/KPI ----------------+
   |   productions                    |   report_templates             |
   |   +-- production_orders          |   +-- report_fields            |
   |   +-- production_characteristics |   kpi_groups                   |
   |   maintenance_records            |   +-- kpi_reports              |
   +----------------------------------+----------------------------------+

+===========================================================================+
|                          LOOKUP/SISTEM TABLOLARI                          |
+===========================================================================+
| countries -> states -> cities -> districts                                |
| languages, lang_values, keywords                                          |
| categories, characteristics                                               |
| device_types, device_models, devices                                      |
| priorities, markers, measurements                                         |
| txn_types, txns, confirmations                                           |
| query_limits, http_logs, ftp_users                                       |
+===========================================================================+
```

---

## Son Guncelleme

**Tarih:** 2026-01-24
**Versiyon:** 1.0.0
