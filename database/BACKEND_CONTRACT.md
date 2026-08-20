# Backend Contract — mobile drift-guard (FAZ-0.4)

The mobile app queries the **same Supabase DB** as the web platform (project `gzdhnonhjnxjpqcnrohu`). When the web team changes the schema (drops a column, renames `is_active`→`active`, changes an RPC signature, tightens a CHECK), a mobile query that references the old shape fails **silently** with PGRST400 (supabase-flutter surfaces it as an error the caller often ignores) — the exact silent-drift class the web side hardened this cycle.

This contract pins the backend surface the mobile depends on so drift is caught at **CI time**, not at runtime.

## Mechanism
1. `scripts/gen_backend_contract.sql` emits the current backend surface as one JSON object (tables+columns+types, `fn_*` RPC signatures, pg enums, critical CHECK sets).
2. Commit its output as `database/backend_contract.json` (the **pinned** reference).
3. CI re-runs the generator against live/staging and **diffs** live-vs-pinned. A diff on a contracted table/RPC → regenerate + fix the affected Dart model before the runtime break ships.

```sh
supabase db execute --file scripts/gen_backend_contract.sql > database/backend_contract.json   # regenerate
git diff database/backend_contract.json                                                        # review drift
```

## Pinned snapshot committed — `database/backend_contract.json` ✅

`database/backend_contract.json` is now committed (2026-08-20 snapshot: 23 tables,
63 `fn_*` RPCs, 17 enums, 5 CHECK sets). CI can diff live-vs-pinned against it;
regenerate with `scripts/gen_backend_contract.sql` (via `supabase db execute` once
`supabase link` is set up, or the SQL editor / MCP) after any web schema change and
review the `git diff`.

## Pinned reference — 2026-08-20 snapshot

**Contracted tables (22):** profiles, staffs, tenants, organizations, platform_menu_items, platforms, keywords, languages, rbac_roles, rbac_user_roles, status_definitions, entity_type_configs, form_submissions, form_templates, notifications, sites, controllers, variables, device_models, alarms, alarm_histories, logs_rollup, energy_readings_rollup. *(full column list in backend_contract.json — run the generator)*

**RPC signatures the mobile should target for web-parity** (the mobile currently queries tables directly and calls **no** `fn_*` — adopting these gives the same server-side aggregation + the perf/security fixes shipped this cycle):

| RPC | args → returns | use |
|-----|----------------|-----|
| `fn_my_profile_bundle()` | `() → jsonb` | **session-init in ONE round-trip** (role/tenant/org/avatar) — replaces the multi-query cold-start path |
| `fn_pms_kpi_summary(p_tenant_id, p_from?, p_to?)` | `→ TABLE(total_alarms, active_alarms, resolved_alarms, avg_resolution_hours, critical/high/medium/low_count, distinct_sites/controllers_affected)` | dashboard KPI tiles |
| `fn_pms_active_alarms(p_limit=30)` | `→ jsonb` | active-alarm list |
| `fn_pms_alarm_trend(p_tenant_id, p_bucket='day', p_from?, p_to?)` | `→ TABLE(period, cnt, critical)` | alarm trend chart |
| `fn_pms_alarm_priority_breakdown(p_tenant_id, …)` | `→ TABLE(priority_id, priority_name, priority_color, priority_level, cnt)` | priority donut |
| `fn_pms_alarm_site_controller(p_tenant_id, …)` | `→ TABLE(site_id, site_name, controller_id, controller_name, cnt)` | site/controller ranking |
| `fn_pms_provider_health(p_tenant_id, …)` | `→ TABLE(provider_id, provider_name, alarm_count, critical_count, last_alarm_at, health_score)` | provider ranking |
| `fn_pms_controller_uptime(p_tenant_id, …)` | `→ TABLE(controller_id, controller_name, site_name, alarm_count, total_alarm_minutes, availability_pct)` | controller uptime |
| `fn_controller_logged_variables(p_controller_id)` | `→ TABLE(id, name, code, description, measure_unit, data_type)` | **controller variable list — avoids the ~178k-row `logs` fact-scan** (mobile's `iot_log_service` still scans `logs` directly) |
| `fn_pms_telemetry_summary(p_tenant_id, p_variable?, p_from?, p_to?, p_organization_id?)` | `→ jsonb` | telemetry summary |
| `fn_pms_hierarchy_health(p_tenant?)` | `→ jsonb` | data-quality panel |
| `fn_alarm_acknowledge(p_alarm_id)` / `fn_pms_alarm_acknowledge(p_alarm_id)` | `→ boolean` / `jsonb` | ack action |
| `fn_pms_alarm_inhibit(p_alarm_id, p_inhibit=true)` / `fn_pms_alarm_reset(p_alarm_id)` | `→ jsonb` | inhibit/reset actions |
| `fn_is_admin()` / `fn_user_in_org(p_org_id)` / `fn_my_coarse_role()` | `→ boolean/text` | RBAC gate (coarse role: super_admin/admin→ADMIN, manager→MANAGER, customer→CUSTOMER) |

*(energy RPCs — `fn_energy_consumption_rollup`, `fn_energy_baseline_regression`, `fn_energy_load_profile`, `fn_energy_data_quality`, `fn_energy_avoided_savings`, `fn_energy_consumption_anomalies`, … — are pinned in backend_contract.json for a future PEM-mobile.)*

**pg enums** (mail_status, mail_priority, mail_provider_type, factor_type, request_status, oauth_*, code_challenge_method, …) — none are the PMS domain enums; PMS "enum-like" values live in CHECK constraints below.

**Critical CHECK allowed-values (drift-sensitive):**
- `tenants.status` ∈ {active, suspended, pending_deletion, deleted}
- `variables.status` ∈ {active, inactive}
- `variables.data_type` ∈ {number, string, boolean}
- `variables.variable_type` ∈ {DIGITAL, ANALOG, INTEGER, ALARM, COMMAND, UNDEFINED}
- `variables.working_time_variable_type` ∈ {COMPRESSOR_STATUS, DEFROST_STATUS, ACTIVE_ENERGY_VARIABLE, POWER_VARIABLE, RACK_COMPRESSOR_VARIABLE, RACK_DEFROST_VARIABLE}

## Known drift/parity notes (web hardening this cycle → mobile follow-ups)
- **Column naming:** `profiles`/`staffs` use `active` (NOT `is_active`). Mobile's `variable_model.dart` uses `is_active` — OK because `variables` genuinely has `is_active`. Audit any profiles/staffs Dart model for `is_active`.
- **`fn_controller_logged_variables`** was ADDED this cycle to replace a `logs` fact-table scan (web bug: ~178k rows streamed to count ~23 variables). Mobile's `iot_log_service.dart:147` `from('logs').select(...)` should be reviewed for the same pattern.
- **`status_definitions`:** shared defaults must be `is_system=true` under tenant `00000000-…` to be RLS-visible; missing status match → blank badge.
- Mobile calls **zero** `fn_*` RPCs today → misses the server-side aggregation + the perf/security fixes the web now depends on.
