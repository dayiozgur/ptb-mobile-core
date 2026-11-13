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
-- 17 keys x 4 languages = 68 rows.

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
    ('auth.mfa.unavailable_message', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Al momento non è stato possibile leggere il requisito di verifica in due passaggi. Gli account amministratore non si aprono senza questo controllo; controlla la connessione e riprova, oppure esci.'),
    ('settings.delete_account.title', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Hesabımı sil'),
    ('settings.delete_account.title', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Delete my account'),
    ('settings.delete_account.title', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Mein Konto löschen'),
    ('settings.delete_account.title', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Elimina il mio account'),
    ('settings.delete_account.subtitle', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Silme talebi web sayfasından iletilir'),
    ('settings.delete_account.subtitle', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'The request is made on our web page'),
    ('settings.delete_account.subtitle', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Die Anfrage wird auf unserer Webseite gestellt'),
    ('settings.delete_account.subtitle', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'La richiesta si invia dalla nostra pagina web'),
    ('settings.delete_account.explanation', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Hesabınızın silinmesini tarayıcıda açılacak sayfadan talep edersiniz; talep doğrulandıktan sonra hesabınız ve kişisel verileriniz, yasal olarak saklanması gerekenler dışında silinir. Kuruluşunuza ait iş kayıtları kuruluşunuzda kalabilir ve silme işlemi geri alınamaz.'),
    ('settings.delete_account.explanation', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'You request the deletion of your account on the page that opens in your browser; once the request is confirmed, your account and your personal data are deleted, except what the law requires us to keep. Business records that belong to your organisation may stay with your organisation, and the deletion cannot be undone.'),
    ('settings.delete_account.explanation', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Sie beantragen die Löschung Ihres Kontos auf der Seite, die sich in Ihrem Browser öffnet; nach Bestätigung der Anfrage werden Ihr Konto und Ihre personenbezogenen Daten gelöscht, ausgenommen Daten, die wir gesetzlich aufbewahren müssen. Geschäftsunterlagen Ihrer Organisation können bei Ihrer Organisation verbleiben, und die Löschung kann nicht rückgängig gemacht werden.'),
    ('settings.delete_account.explanation', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Richiedi l''eliminazione del tuo account dalla pagina che si apre nel browser; una volta confermata la richiesta, il tuo account e i tuoi dati personali vengono eliminati, tranne quelli che la legge ci impone di conservare. I documenti aziendali della tua organizzazione possono restare all''organizzazione e l''eliminazione non può essere annullata.'),
    ('settings.delete_account.continue', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Web''de devam et'),
    ('settings.delete_account.continue', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Continue on the web'),
    ('settings.delete_account.continue', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Im Web fortfahren'),
    ('settings.delete_account.continue', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Continua sul web'),
    ('notification.load_failed', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Bildirimler yüklenemedi. Bu, bildiriminiz olmadığı anlamına gelmez; tekrar deneyin.'),
    ('notification.load_failed', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Your notifications could not be loaded. This does not mean there are none; try again.'),
    ('notification.load_failed', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Ihre Benachrichtigungen konnten nicht geladen werden. Das bedeutet nicht, dass es keine gibt; versuchen Sie es erneut.'),
    ('notification.load_failed', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Impossibile caricare le notifiche. Questo non significa che non ce ne siano; riprova.'),
    ('notification.empty_message', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Henüz bildiriminiz bulunmuyor.'),
    ('notification.empty_message', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'You have no notifications yet.'),
    ('notification.empty_message', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Sie haben noch keine Benachrichtigungen.'),
    ('notification.empty_message', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Non hai ancora notifiche.'),
    ('notification.untitled', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Bildirim'),
    ('notification.untitled', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Notification'),
    ('notification.untitled', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Benachrichtigung'),
    ('notification.untitled', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Notifica'),
    ('crm.contact.load_failed', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Kişiler yüklenemedi. Bu, kayıt olmadığı anlamına gelmez; tekrar deneyin.'),
    ('crm.contact.load_failed', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'The contacts could not be loaded. This does not mean there are none; try again.'),
    ('crm.contact.load_failed', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Die Kontakte konnten nicht geladen werden. Das bedeutet nicht, dass es keine gibt; versuchen Sie es erneut.'),
    ('crm.contact.load_failed', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Impossibile caricare i contatti. Questo non significa che non ce ne siano; riprova.'),
    ('crm.contact.activities_load_failed', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Aktiviteler yüklenemedi.'),
    ('crm.contact.activities_load_failed', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'The activities could not be loaded.'),
    ('crm.contact.activities_load_failed', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Die Aktivitäten konnten nicht geladen werden.'),
    ('crm.contact.activities_load_failed', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Impossibile caricare le attività.'),
    ('crm.sequence.load_failed', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Diziler yüklenemedi.'),
    ('crm.sequence.load_failed', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'The sequences could not be loaded.'),
    ('crm.sequence.load_failed', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Die Sequenzen konnten nicht geladen werden.'),
    ('crm.sequence.load_failed', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Impossibile caricare le sequenze.'),
    ('comments.title', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Yorumlar'),
    ('comments.title', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Comments'),
    ('comments.title', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Kommentare'),
    ('comments.title', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Commenti'),
    ('comments.empty', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Henüz yorum yok.'),
    ('comments.empty', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'No comments yet.'),
    ('comments.empty', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Noch keine Kommentare.'),
    ('comments.empty', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Ancora nessun commento.'),
    ('comments.load_failed', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Yorumlar yüklenemedi.'),
    ('comments.load_failed', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'The comments could not be loaded.'),
    ('comments.load_failed', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Die Kommentare konnten nicht geladen werden.'),
    ('comments.load_failed', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Impossibile caricare i commenti.'),
    ('comments.add_failed', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Yorum eklenemedi.'),
    ('comments.add_failed', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'The comment could not be added.'),
    ('comments.add_failed', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Der Kommentar konnte nicht hinzugefügt werden.'),
    ('comments.add_failed', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Impossibile aggiungere il commento.'),
    ('comments.placeholder', 'fc6e12d2-73b1-4c19-a465-ffdd1a785715', 'Yorum ekle…'),
    ('comments.placeholder', '198b2bf7-c859-4cc5-8a26-a1367cdd28ef', 'Add a comment…'),
    ('comments.placeholder', '44929d49-5cf2-4ba9-b325-2166d250dabc', 'Kommentar hinzufügen…'),
    ('comments.placeholder', '009377a3-faee-4c5e-ba26-ff1e6953c506', 'Aggiungi un commento…')
  ) AS v(key, language_id, txt)
 WHERE NOT EXISTS (SELECT 1 FROM public.keywords k WHERE k.key = v.key AND k.language_id = v.language_id::uuid);

COMMIT;
