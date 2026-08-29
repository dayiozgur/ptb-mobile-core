-- ===========================================================================
-- Backend contract generator (mobile drift-guard) — FAZ-0.4
-- ===========================================================================
-- Emits a single JSON object pinning the backend surface the mobile app depends
-- on: table columns (+types+nullability), the fn_* RPC signatures, pg enums, and
-- critical CHECK allowed-value sets. Run against the live/staging Supabase
-- (project gzdhnonhjnxjpqcnrohu) and save the output to database/backend_contract.json.
-- CI then diffs live-vs-pinned: a web-side schema change that the mobile references
-- surfaces as a contract diff (→ regenerate + fix the affected Dart model) instead
-- of a silent runtime PGRST400. See database/DATABASE_SYNC_PLAN.md.
--
--   supabase db execute --file scripts/gen_backend_contract.sql > database/backend_contract.json
--   (or run via the SQL editor / MCP and redirect the single-row `contract` value)
-- ===========================================================================

select jsonb_pretty(jsonb_build_object(

  'generated_note', 'Regenerate with scripts/gen_backend_contract.sql after any web schema change',

  -- Mobile-relevant tables (PMS-first + shared/RBAC/menu). Extend the IN-list as
  -- the mobile references more tables. Shape: { table: [ {c:col, t:type, n:nullable} ] }.
  'schema', (
    with rel as (
      select c.table_name,
             jsonb_agg(jsonb_build_object('c', c.column_name, 't', c.data_type, 'n', (c.is_nullable='YES'))
                       order by c.ordinal_position) as cols
      from information_schema.columns c
      where c.table_schema='public'
        and c.table_name in (
          'profiles','staffs','tenants','organizations','platform_menu_items','platforms',
          'keywords','languages','rbac_roles','rbac_user_roles','status_definitions',
          'entity_type_configs','form_submissions','form_templates','notifications',
          'sites','controllers','variables','device_models','alarms','alarm_histories',
          'logs_rollup','energy_readings_rollup',
          'mfa_policy','mfa_email_factors')
      group by c.table_name)
    select jsonb_object_agg(table_name, cols) from rel),

  -- RPC signatures the mobile calls (or should call for perf parity with web).
  'rpcs', (
    select jsonb_object_agg(sig.name, sig.def) from (
      select p.proname as name,
             jsonb_build_object('args', pg_get_function_arguments(p.oid), 'returns', pg_get_function_result(p.oid)) as def
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname like 'fn_%'
        and (p.proname like 'fn_my_%' or p.proname like 'fn_pms_%' or p.proname like 'fn_energy_%'
             or p.proname like 'fn_coarse_%' or p.proname like 'fn_alarm_%' or p.proname like 'fn_controller_%'
             or p.proname in ('fn_is_admin','fn_user_in_org','fn_profiles_with_coarse_role',
                              'fn_is_email_mfa_satisfied','fn_mfa_email_unenroll'))
    ) sig ),

  'enums', (
    select coalesce(jsonb_object_agg(t.typname, e.vals), '{}'::jsonb) from (
      select enumtypid, jsonb_agg(enumlabel order by enumsortorder) vals from pg_enum group by enumtypid
    ) e join pg_type t on t.oid=e.enumtypid ),

  'checks', (
    select coalesce(jsonb_object_agg(cls.relname || '::' || con.conname, pg_get_constraintdef(con.oid)), '{}'::jsonb)
    from pg_constraint con join pg_class cls on cls.oid=con.conrelid join pg_namespace n on n.oid=cls.relnamespace
    where n.nspname='public' and con.contype='c'
      and cls.relname in ('profiles','staffs','tenants','form_submissions','status_definitions','variables','rbac_roles')
      and pg_get_constraintdef(con.oid) ilike '%ANY%' )

)) as contract;
