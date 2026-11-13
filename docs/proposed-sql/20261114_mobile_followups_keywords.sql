-- PROPOSED — NOT APPLIED. Keywords used by the mobile apps (ptb-mobile-core, lane/mobile-followups,
-- 2026-11-14). The apps read UI texts from public.keywords (same table as the web app); until this
-- is applied they fall back to the built-in tr / en / de texts in
-- lib/src/core/localization/app_localizations.dart (Italian falls back to English).
--
-- Insert-only, idempotent (NOT EXISTS per key + language). tr, en, de, it.
-- No schema, RLS, grant or SECURITY DEFINER change. Apply on the web side (migration + db push);
-- CACHE_VERSION bump: coordinator. Placeholders use the web form {{name}}.
-- Companion of 20261113_mobile_store_prep_keywords.sql (yesterday's lane; no key overlap).
--
-- 2 keys x 4 languages = 8 rows.

BEGIN;

INSERT INTO public.keywords (id, key, language_id, defaultvalue, active, created_at)
SELECT gen_random_uuid(), v.key, v.language_id::uuid, v.txt, true, now()
  FROM (VALUES
    ('auth.mfa.required_header_admin', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Yönetici hesapları iki adımlı doğrulama gerektirir'),
    ('auth.mfa.required_header_admin', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Administrator accounts require two-step verification'),
    ('auth.mfa.required_header_admin', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Administratorkonten erfordern eine zweistufige Verifizierung'),
    ('auth.mfa.required_header_admin', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Gli account amministratore richiedono la verifica in due passaggi'),
    ('auth.mfa.unavailable_message', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'İki adımlı doğrulama gereksiniminiz şu anda okunamadı. Yönetici hesapları bu kontrol yapılmadan açılmaz; bağlantınızı kontrol edip tekrar deneyin ya da çıkış yapın.'),
    ('auth.mfa.unavailable_message', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Your two-step verification requirement could not be read right now. Administrator accounts do not open without this check; check your connection and try again, or sign out.'),
    ('auth.mfa.unavailable_message', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Ihre Anforderung an die zweistufige Verifizierung konnte gerade nicht gelesen werden. Administratorkonten werden ohne diese Prüfung nicht geöffnet; prüfen Sie Ihre Verbindung und versuchen Sie es erneut oder melden Sie sich ab.'),
    ('auth.mfa.unavailable_message', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Al momento non è stato possibile leggere il requisito di verifica in due passaggi. Gli account amministratore non si aprono senza questo controllo; controlla la connessione e riprova, oppure esci.')
  ) AS v(key, language_id, txt)
 WHERE NOT EXISTS (SELECT 1 FROM public.keywords k WHERE k.key = v.key AND k.language_id = v.language_id::uuid);

COMMIT;
