# Security Policy — Coordinated Vulnerability Disclosure

This policy covers the Protoolbag mobile core (`protoolbag_core`) and the mobile
apps built from this repository (PMS, PHR, CRM, PPM). It describes how to report
vulnerabilities and how we handle them, as required by the EU Cyber Resilience
Act (CRA), Annex I Part II (vulnerability handling). It mirrors the policy of the
web platform (`protoolbag-platform/SECURITY.md`); the shared backend (Supabase:
database, RLS, Edge Functions) is covered there.

## How to Report a Vulnerability

**Please do NOT open a public GitHub issue for security vulnerabilities.**

- **Email:** security@protoolbag.com
  > **PLACEHOLDER — to be confirmed.** This address must be verified as a
  > monitored security inbox before this policy is published or referenced from
  > the store listings.
- Machine-readable contact (RFC 9116): `https://protoolbag.com/.well-known/security.txt`.

Please include, where possible:

- App and version (Settings → About, or the store version) and platform
  (iOS / Android, OS version, device)
- Description of the vulnerability and its impact
- Step-by-step reproduction or proof-of-concept
- Any suggested remediation
- How you would like to be credited (or if you prefer to remain anonymous)

## Scope

**In scope:**

- This repository: `lib/` (core package), `example_pms`, `example_phr`,
  `example_crm`, `example_ppm`, CI workflows and build scripts
- Released builds of the Protoolbag mobile apps (TestFlight / App Store / Play)
- On-device data handling: session/token storage (Keychain / Android
  Keystore), offline queues, caches, deep links, push-notification payloads,
  biometric lock, file and avatar access (signed URLs), network transport

**Out of scope:**

- Server-side issues in the shared backend — report via the web platform
  policy (same contact)
- Attacks requiring a rooted/jailbroken device or physical access to an
  unlocked device, unless they bypass a documented protection
- Denial-of-service / volumetric testing against production systems
- Social engineering or phishing against staff or users
- Third-party services (Supabase, Apple, Google, Microsoft Graph, …) — report
  to the vendor; a heads-up is appreciated
- Automated scanner output without a demonstrated, exploitable impact

## Response SLAs

| Stage | Target |
| --- | --- |
| Acknowledgement of report | within **3 business days** |
| Initial triage and severity assessment | within **7 calendar days** |
| Status updates during remediation | at least every **14 days** |
| Fix or mitigation after triage | **Critical 14 days · High 30 days · Medium 90 days · Low next release** |
| Coordinated public disclosure | by mutual agreement, default **90 days** after report |

Security fixes are provided free of charge. When a fix requires an app update,
the minimum supported version can be raised server-side
(`platform_app_configs.min_mobile_app_version`, see `AppVersionGate`) so
outdated clients are asked to update.

## Supported Versions

Only the latest released version of each app receives security updates.
Older versions may be blocked via the minimum supported version gate once a
fixed version is available.

## Safe Harbor

We will not pursue legal action against researchers who act in good faith,
follow this policy, avoid privacy violations and service disruption, and give
us reasonable time to remediate before any public disclosure.
