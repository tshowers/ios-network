# Network iOS

A read-only, swipeable "digital Rolodex" over TODD's Network/contacts data — one full-screen contact card at a time, swipe up for the next. No dashboard, no table, no editing. If you need to change a contact, that's still TODD on the web; this app answers "who is this, should I contact them, how do I contact them."

Backend stays shared with `taliferrotech`/`todd-backend` — no functionality was duplicated. Two backend additions were made alongside this app (see `todd-backend/functions/networkRoutes.js` and `networkLogoEnrichment.service.js`):

- `GET /network/cards` — a new, purpose-built read endpoint. It does **not** forward raw `Contact` documents (which carry SSNs, financials, notes, opportunities) — only the fields the card UI needs.
- Company-logo enrichment, cached at the Firestore root (`companyLogos/{domain}`) since a company's public logo isn't tenant-sensitive — shared across every tenant that has that company as a contact, not looked up per-contact.

## Auth — two different mechanisms, on purpose

- `/network/cards` verifies a real Firebase ID token server-side (`requireVerifiedUser` in `networkRoutes.js`). This is a deliberate departure from the header-trusting `attachAuthContext` pattern most of the backend uses (`X-Tenant-Id`/`X-User-Id` headers, which are spoofable by anyone holding the client-embedded API key) — appropriate for the rest of the backend's existing low-stakes routes, not appropriate for a new endpoint handing real contact data to a phone.
- `/email-drafting/draft` and `/send-email` are the *existing* endpoints TODD's web Composer/Catalyst and SayIt already call — they're gated by the same shared static `TALIFERRO_TECH` key every TODD frontend ships, not by ID token. `NetworkAPIClient` uses whichever auth each endpoint actually expects.

Sign-in is Sign in with Apple only, via the shared [`TODDAuthKit`](../TODDAuthKit) package. Unlike `maya-ios` (works signed out) but like `pulse-ios`, the whole app is gated behind sign-in + a fresh biometric check (`RootView` → `SignInView` → `BiometricLockView` → `CardFeedView`) — this is real CRM data, so there's no guest mode.

Tenant resolution mirrors `frontend/src/app/services/auth.service.ts`'s `resolveAssignedTenantId`: `users/{uid}.companyId`, falling back to the uid itself.

## What's in scope (this pass)

1. Sign in, then a full-screen swipeable card feed (`Features/Feed`) — company logo or a generated monogram, name, title, company, location, relationship, last-contacted.
2. Natural-language search bar, wired to the existing `getAIParsedQuery` (same NL parser the web app's contact search already uses) via `/network/cards?query=...`. **Not** a port of the web app's 300-line synonym/fuzzy `filterContacts()` — see the comment on `matchesParsedFilters` in `networkRoutes.js` for why that was deliberately left alone rather than duplicated.
3. **Email with Maya** (`Features/Compose`) — draft via `/email-drafting/draft` (the same drafting engine web Composer/Catalyst uses), then a **mandatory preview screen**, then an explicit Send tap → `/send-email`. Never auto-sends — matches TODD's existing draft-only/approval-first policy elsewhere in the product.
4. **Share** — a client-side-built vCard handed to the native share sheet (AirDrop/Messages/Mail/Save Contact). No backend round-trip.

## Explicitly out of scope (v2)

- **Introduce** (Maya writes an introduction connecting two contacts) — needs a two-contact prompt that doesn't exist on the backend yet.
- Full parity between mobile search and the web's fuzzy/synonym contact search.
- Editing, creating, or deleting contacts — this app is read-only by design, not by omission.
- A never-contacted contact currently won't appear in the default feed at all — Firestore's `orderBy` silently excludes documents missing the sort field (`lastContacted`). Flagged in `networkRoutes.js`, not silently fixed.

## Recommended path

```bash
brew install xcodegen   # if you don't have it
cd apps/ios/network-ios
xcodegen generate
open NetworkIOS.xcodeproj
```

**One-time setup this repo can't do for you:**

- Sign In with Apple must be enabled on this app's App ID in the (paid) Apple Developer portal — `project.yml` requests the capability, but the portal-side toggle is a separate account-level step.
- A `GoogleService-Info.plist` for a **new iOS app registration** in the `taliferrotech` Firebase project (bundle id `tech.taliferro.networkios`, matching `project.yml`). Firebase console → Project settings → Add app → iOS → download the plist → drop it at `NetworkIOS/GoogleService-Info.plist`. Intentionally not checked in.
- The backend additions (`networkRoutes.js`, `networkLogoEnrichment.service.js`, the `onContactWrittenForCompanyLogo` trigger) need to actually be deployed to `todd-backend` before this app can load anything.

## Required config

- `NETWORK_API_BASE_URL` — set in `project.yml`, currently `https://api.taliferro.tech/api`.
- `NETWORK_API_KEY` — the shared static key used by `environment.apiKey` / checked server-side as `TALIFERRO_TECH`, needed only for `/email-drafting/draft` and `/send-email`. Set it locally (target build settings or an `.xcconfig` file), never commit the real value.
- `GoogleService-Info.plist` — required for Firebase Auth + Firestore, see above.

## Current source mapping

Backend (new, alongside this app):

- `todd-backend/functions/networkRoutes.js`
- `todd-backend/functions/networkLogoEnrichment.service.js`
- `todd-backend/functions/triggers/networkCompanyLogo.js`

Backend (existing, reused as-is):

- `todd-backend/functions/openaiRoutes.js` (`/parse-query`, `/email-drafting/draft`)
- `todd-backend/functions/open-ai.js` (`getAIParsedQuery`, `getContactInsight` — not yet wired into this app's UI)
- `todd-backend/functions/emailDrafting.service.js` (`draftStructuredEmail`)
- `todd-backend/functions/email.js` (`/send-email`)

Web feature this pairs with (planned as a separate, later effort — see project notes):

- `frontend/src/app/features/contact/` (Network/CRM — home, list, view, read, create, deal-flow-dashboard, csv-import, etc.)
