# Deep-link association files (templates)

One folder per web host. Each host must serve **both** files, unauthenticated, over HTTPS,
without redirects, with `Content-Type: application/json`:

| File in this folder | Served at |
|---|---|
| `assetlinks.json` | `https://<host>/.well-known/assetlinks.json` |
| `apple-app-site-association` (no extension) | `https://<host>/.well-known/apple-app-site-association` |

These are **templates**. Replace the placeholders before publishing:

| Placeholder | Where it comes from |
|---|---|
| `<PLAY_APP_SIGNING_SHA256_FINGERPRINT>` | Play Console → the app → Test and release → App integrity → App signing key certificate → SHA-256 |
| `<UPLOAD_KEY_SHA256_FINGERPRINT_OPTIONAL>` | Same page, "Upload key certificate" (only needed for builds installed outside Play; delete the entry otherwise) |
| `<APPLE_TEAM_ID>` | Apple Developer → Membership details → Team ID (the Xcode projects name `283AHKB4WM`; PEM names `5F37BRKPX9` — see the readiness document) |

Notes

- `package_name` is the Android **applicationId as it is in the repo today**. If the owner
  renames the application ids (recommended: `com.protoolbag.<code>`), update the file before the
  first Play upload — the id cannot change after publication.
- Android can only associate a whole host: every `https://<host>/…` link opens the app once the
  file verifies. Paths without a mobile screen show the app's "open on the web" screen.
- On iOS the `components` list excludes pages that only exist in the web app (legal pages, sign-in /
  registration, the Microsoft connection page, report builder, Microsoft 365 hub pages, visual
  builders), so those links keep opening in the browser. Extend the list when a new web-only area
  is added.
- Today only CRM, FixFlow and PEM declare the association in the app (Android `autoVerify`
  intent filter, iOS `applinks:` entitlement). PMS, PHR and PPM do not: their files are prepared
  here but have no effect until the apps declare the domain.
- The web hosts are static SPA containers: make sure the `.well-known` paths are served as files and
  are not rewritten to `index.html` (a 200 with HTML fails verification silently).
