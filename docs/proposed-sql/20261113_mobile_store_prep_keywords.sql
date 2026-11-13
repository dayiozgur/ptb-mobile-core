-- PROPOSED — NOT APPLIED. Keywords used by the mobile apps (ptb-mobile-core, lane/store-prep,
-- 2026-11-13). The apps read UI texts from public.keywords (same table as the web app); until this
-- is applied they fall back to the built-in tr / en / de texts in
-- lib/src/core/localization/app_localizations.dart (Italian falls back to English).
--
-- Insert-only, idempotent (NOT EXISTS per key + language). tr, en, de, it.
-- No schema, RLS, grant or SECURITY DEFINER change. Apply on the web side (migration + db push);
-- CACHE_VERSION bump: coordinator. Placeholders use the web form {{name}}.
--
-- 18 keys x 4 languages = 72 rows.

BEGIN;

INSERT INTO public.keywords (id, key, language_id, defaultvalue, active, created_at)
SELECT gen_random_uuid(), v.key, v.language_id::uuid, v.txt, true, now()
  FROM (VALUES
    ('m365.problem.admin_consent_required.title', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Microsoft 365 yöneticinizin onayı gerekiyor'),
    ('m365.problem.admin_consent_required.title', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Your Microsoft 365 administrator has to approve this'),
    ('m365.problem.admin_consent_required.title', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Ihr Microsoft 365-Administrator muss dies genehmigen'),
    ('m365.problem.admin_consent_required.title', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Serve l''approvazione dell''amministratore di Microsoft 365'),
    ('m365.problem.admin_consent_required.hint', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Kuruluşunuz bu izin için yönetici onayı istiyor; yeniden bağlanmak bunu değiştirmez. Microsoft 365 yöneticinizden uygulamayı kuruluş adına onaylamasını isteyin (web uygulamasında Bağlı uygulamalar → kurulum sihirbazı → Kuruluş onayı). Onaydan sonra yeniden deneyin.'),
    ('m365.problem.admin_consent_required.hint', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Your organisation requires administrator approval for this permission; reconnecting will not change it. Ask your Microsoft 365 administrator to approve the app for the organisation (in the web app: Connected apps → setup wizard → Organisation approval). Try again after the approval.'),
    ('m365.problem.admin_consent_required.hint', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Ihre Organisation verlangt für diese Berechtigung eine Administratorgenehmigung; erneutes Verbinden ändert das nicht. Bitten Sie Ihren Microsoft 365-Administrator, die App für die Organisation zu genehmigen (in der Web-App: Verbundene Apps → Einrichtungsassistent → Organisationsgenehmigung). Versuchen Sie es nach der Genehmigung erneut.'),
    ('m365.problem.admin_consent_required.hint', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'La tua organizzazione richiede l''approvazione dell''amministratore per questa autorizzazione; ricollegare l''account non cambia la situazione. Chiedi all''amministratore di Microsoft 365 di approvare l''app per l''organizzazione (nell''app web: App collegate → configurazione guidata → Approvazione dell''organizzazione). Riprova dopo l''approvazione.'),
    ('m365.problem.admin_consent_required.toast', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Bu işlem için Microsoft 365 yöneticinizin onayı gerekiyor.'),
    ('m365.problem.admin_consent_required.toast', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'This action needs the approval of your Microsoft 365 administrator.'),
    ('m365.problem.admin_consent_required.toast', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Für diese Aktion ist die Genehmigung Ihres Microsoft 365-Administrators erforderlich.'),
    ('m365.problem.admin_consent_required.toast', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Questa azione richiede l''approvazione dell''amministratore di Microsoft 365.'),
    ('integrations.ms.oauth_result.admin_consent_required.hint', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Kuruluşunuz bu izinler için yönetici onayı istiyor; bu yüzden hesabınız bağlanamadı. Microsoft 365 yöneticiniz uygulamayı web uygulamasındaki Bağlı uygulamalar sayfasından (kurulum sihirbazı → Kuruluş onayı) tüm kuruluş için onaylayabilir. Onaydan sonra yeniden bağlanın.'),
    ('integrations.ms.oauth_result.admin_consent_required.hint', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Your organisation requires administrator approval for these permissions, so your account could not be connected. Your Microsoft 365 administrator can approve the app for the whole organisation on the Connected apps page of the web app (setup wizard → Organisation approval). Connect again after the approval.'),
    ('integrations.ms.oauth_result.admin_consent_required.hint', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Ihre Organisation verlangt für diese Berechtigungen eine Administratorgenehmigung, daher konnte Ihr Konto nicht verbunden werden. Ihr Microsoft 365-Administrator kann die App auf der Seite „Verbundene Apps“ der Web-App (Einrichtungsassistent → Organisationsgenehmigung) für die gesamte Organisation genehmigen. Verbinden Sie sich danach erneut.'),
    ('integrations.ms.oauth_result.admin_consent_required.hint', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'La tua organizzazione richiede l''approvazione dell''amministratore per queste autorizzazioni, quindi non è stato possibile collegare l''account. L''amministratore di Microsoft 365 può approvare l''app per tutta l''organizzazione nella pagina App collegate dell''app web (configurazione guidata → Approvazione dell''organizzazione). Dopo l''approvazione collega di nuovo l''account.'),
    ('integrations.ms.connect_on_web', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Bu uygulamadan Microsoft hesabı bağlanamıyor. Hesabınızı web uygulamasındaki Bağlı uygulamalar sayfasından bağlayın; bağlantı burada da geçerli olur.'),
    ('integrations.ms.connect_on_web', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'A Microsoft account cannot be connected from this app. Connect your account on the Connected apps page of the web app; the connection is then used here as well.'),
    ('integrations.ms.connect_on_web', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'In dieser App kann kein Microsoft-Konto verbunden werden. Verbinden Sie Ihr Konto auf der Seite „Verbundene Apps“ der Web-App; die Verbindung gilt dann auch hier.'),
    ('integrations.ms.connect_on_web', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Da questa app non è possibile collegare un account Microsoft. Collega il tuo account nella pagina App collegate dell''app web; il collegamento vale poi anche qui.'),
    ('crm.agenda.load_failed', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'CRM etkinlikleri yüklenemedi.'),
    ('crm.agenda.load_failed', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'The CRM events could not be loaded.'),
    ('crm.agenda.load_failed', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Die CRM-Termine konnten nicht geladen werden.'),
    ('crm.agenda.load_failed', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Impossibile caricare gli eventi CRM.'),
    ('common.web_only.title', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Web uygulamasında'),
    ('common.web_only.title', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'In the web app'),
    ('common.web_only.title', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'In der Web-App'),
    ('common.web_only.title', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Nell''app web'),
    ('common.web_only.message', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Bu ekran web uygulamasında kullanılır; mobil uygulamada karşılığı yok.'),
    ('common.web_only.message', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'This screen is used in the web app; it has no counterpart in the mobile app.'),
    ('common.web_only.message', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Dieser Bildschirm wird in der Web-App verwendet; in der mobilen App gibt es kein Gegenstück.'),
    ('common.web_only.message', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Questa schermata si usa nell''app web; non ha un equivalente nell''app mobile.'),
    ('common.web_only.open_failed', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Tarayıcı açılamadı.'),
    ('common.web_only.open_failed', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'The browser could not be opened.'),
    ('common.web_only.open_failed', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Der Browser konnte nicht geöffnet werden.'),
    ('common.web_only.open_failed', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Impossibile aprire il browser.'),
    ('common.open_on_web', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Web''de aç'),
    ('common.open_on_web', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Open on the web'),
    ('common.open_on_web', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Im Web öffnen'),
    ('common.open_on_web', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Apri sul web'),
    ('common.coming_soon_mobile', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Bu ekran mobil uygulamada henüz yok.'),
    ('common.coming_soon_mobile', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'This screen is not in the mobile app yet.'),
    ('common.coming_soon_mobile', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Dieser Bildschirm ist in der mobilen App noch nicht verfügbar.'),
    ('common.coming_soon_mobile', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Questa schermata non è ancora disponibile nell''app mobile.'),
    ('common.no_access.title', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Bu içeriğe erişiminiz yok'),
    ('common.no_access.title', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'You have no access to this content'),
    ('common.no_access.title', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Sie haben keinen Zugriff auf diesen Inhalt'),
    ('common.no_access.title', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Non hai accesso a questo contenuto'),
    ('common.no_access.message', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Rolünüz bu bilgiyi görmeye yetmiyor. Kendi kayıtlarınız ve size bağlı ekibinizin kayıtları ilgili ekranlarda görünmeye devam eder; daha fazlası gerekiyorsa kuruluş yöneticinize başvurun.'),
    ('common.no_access.message', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Your role does not allow you to see this information. Your own records and those of the team reporting to you remain available on their screens; if you need more, ask your organisation''s administrator.'),
    ('common.no_access.message', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Ihre Rolle erlaubt es nicht, diese Informationen zu sehen. Ihre eigenen Einträge und die des Ihnen unterstellten Teams bleiben auf den jeweiligen Bildschirmen sichtbar; wenn Sie mehr benötigen, wenden Sie sich an den Administrator Ihrer Organisation.'),
    ('common.no_access.message', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Il tuo ruolo non consente di vedere queste informazioni. I tuoi dati e quelli del team che fa capo a te restano disponibili nelle rispettive schermate; se ti serve altro, rivolgiti all''amministratore della tua organizzazione.'),
    ('workflow_approvals.expires_at', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Bitiş'),
    ('workflow_approvals.expires_at', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Expires'),
    ('workflow_approvals.expires_at', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Läuft ab'),
    ('workflow_approvals.expires_at', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Scadenza'),
    ('work_inbox.empty', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Atanmış iş yok'),
    ('work_inbox.empty', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'No work assigned to you'),
    ('work_inbox.empty', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Ihnen ist keine Arbeit zugewiesen'),
    ('work_inbox.empty', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Nessuna attività assegnata'),
    ('alarm.active_load_failed', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Aktif alarmlar yüklenemedi. Bu, alarm olmadığı anlamına gelmez; tekrar deneyin.'),
    ('alarm.active_load_failed', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'The active alarms could not be loaded. This does not mean there are none; try again.'),
    ('alarm.active_load_failed', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Die aktiven Alarme konnten nicht geladen werden. Das bedeutet nicht, dass es keine gibt; versuchen Sie es erneut.'),
    ('alarm.active_load_failed', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Impossibile caricare gli allarmi attivi. Questo non significa che non ce ne siano; riprova.'),
    ('account.security.password.mfa_required', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'İki adımlı doğrulamanız açık. Şifrenizi değiştirmek için doğrulama uygulamanızdaki 6 haneli kodu girin.'),
    ('account.security.password.mfa_required', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Two-step verification is on for your account. To change your password, enter the 6-digit code from your authenticator app.'),
    ('account.security.password.mfa_required', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Für Ihr Konto ist die zweistufige Verifizierung aktiviert. Geben Sie zum Ändern Ihres Passworts den 6-stelligen Code aus Ihrer Authenticator-App ein.'),
    ('account.security.password.mfa_required', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'La verifica in due passaggi è attiva per il tuo account. Per cambiare la password inserisci il codice a 6 cifre della tua app di autenticazione.'),
    ('account.security.password.mfa_code_required', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Doğrulama kodunu girin.'),
    ('account.security.password.mfa_code_required', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Enter the verification code.'),
    ('account.security.password.mfa_code_required', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Geben Sie den Bestätigungscode ein.'),
    ('account.security.password.mfa_code_required', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Inserisci il codice di verifica.')
  ) AS v(key, language_id, txt)
 WHERE NOT EXISTS (SELECT 1 FROM public.keywords k WHERE k.key = v.key AND k.language_id = v.language_id::uuid);

COMMIT;
