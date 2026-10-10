# Network → Relationships: full-app audit

2026-10-06. Apple rejected Network iOS 1.0 under guideline 4.3 (spam) and 4.2.6. The plan is to rebrand it as **Relationships** and resubmit it as a complete native relationship manager, not a read-only companion to the web app.

Sources compared:

- **iOS today:** `apps/ios/network-ios` (≈3,600 lines of Swift).
- **Web Network:** `web-products/network` (Angular, network.taliferro.tech).
- **Left behind:** `taliferrotech/frontend/src/app/features/contact`, the original TODD contact feature that web Network was cut down from. Examples of the cut: the list went from 2,465 lines to 267, contact view from 1,260 to 174, deal flow from 1,750 to 290, CSV import from 1,470 to 425, and the editor from 1,349 to 429.
- **Design:** Claude Design handoffs `corporate/design_handoff_music_leadvault_network` (frames 15a–15s) and `corporate/design_handoff_network_contact_detail` (15t–15v).

## 1. What iOS has today

- Sign in with Apple or Google and Face ID re-lock (TODDAuthKit).
- Onboarding wizard, in-app profile, awards, and a StoreKit paywall.
- **A read-only card feed:** one contact per screen, with page-curl paging and a company logo or monogram.
- A lazy AI insight line per card (`/contact-insight`).
- Natural-language search (`/network/cards?query=`).
- Email with Maya: draft, then a required preview, then send.
- Share a contact as a vCard.
- A status screen (health % and contacts by status, from `/network/stats`).
- A Getting Started checklist.

The README calls the app read-only **by design**: "If you need to change a contact, that's still TODD on the web." That is the core 4.3 problem. The app is a viewer for a website.

## 2. About the design handoff

Both handoffs are for the **Angular web app**. Their iPhone frames (15k–15s, 15u, 15v) are phone-width web layouts, not native iOS specs. They are still the right visual source for the native app:

- **Tokens:** the Network family's light and dark colors, tint pairs, type scale and radii.
- **Screen structure:** Relationships home, Contacts, Contact detail, Editor, Import, Pipeline and Progress.

Translate them to native patterns:

- Tab bar instead of the web's Menu nav.
- Native navigation stack, swipe actions, sheets for pickers, and SF Symbols where the handoff uses Lucide icons.

## 3. Gap audit

Legend: **Web** = in web Network today. **Left behind** = only in taliferrotech's original contact feature. **Native-only** = something no web version can do, which carries the most weight with App Review.

### P0: required to be a "full app"

| Feature | iOS now | Web | Left behind | Design | Notes |
|---|---|---|---|---|---|
| Contacts list (search, sort, filter by status, count) | Card feed only | ✅ | ✅ richer (sorting, rolodex, horizontal scroll) | 15c / 15m | Keep the card feed as a "Flip through" mode, but a list is the primary surface. |
| Contact detail (identity, status, 8-step communication stage + Next, notes, company, capabilities, addresses, profile types, every email and phone) | Partial (card) | ✅ | ✅ | 15t / 15u / 15v | Card model lacks notes, all emails and phones, addresses, profile types, `emailStage` and status. |
| Create contact | ❌ | ✅ | ✅ (address autocomplete, NAICS type-ahead, missing-info prompts) | 15d / 15n | Five-section editor with live preview and per-section validation. |
| Edit and delete contact | ❌ | ✅ | ✅ | 15d | Swipe to delete, with confirmation. |
| Change status / pipeline stage | ❌ | ✅ (`status-flow`) | ✅ | 15f "Move ›" | One tap from list, detail or pipeline. |
| Notes: add, edit, view | ❌ | Read only | ✅ (`note-modal`) | 15t notes card | Notes are where a phone app earns its place: right after a meeting or call. |
| Email and Call quick actions | Email via Maya only | `mailto:` | — | 15u | Add Call (`tel:`), Text (`sms:`) and plain Email. **Log each one as an interaction** and update `lastContacted`. |
| Relationships home: health rings, care-cycle table, App status | Partial (`NetworkStatusView`) | ✅ (`contact-home`) | ✅ (arc gauges, command deck, status LEDs) | 15b / 15k | Rename the home to "Relationships". Use real `diagnosisRows` (handoff open item 3). |
| Pipeline lane view with Move | ❌ | ✅ | ✅ (`deal-flow-board`) | 15f / 15p | On the phone: a stage picker plus one lane, as in 15p. |

### P1: makes it clearly more than CRUD

| Feature | iOS now | Web | Left behind | Design | Notes |
|---|---|---|---|---|---|
| Networking Progress (Attract, Convert, Close zones; Cold Reserve; TODD Action Priorities) | ❌ | ✅ | ✅ | 15g / 15q | Tapping a priority opens that filtered list. |
| Import CSV | ❌ | ✅ (5 steps) | ✅ richer (data preview, import log, template download) | 15e / 15o | On iOS, pick from Files. Lower priority than importing from iPhone Contacts (below). |
| Company and contact enrichment | Logos only | — | ✅ (`enrich-company-data`, `/enrich-contact`) | — | Backend exists. Add an "Enrich" button on detail. |
| Email verification badge | ❌ | — | ✅ (`email-check-icon`, `/enrich-email`) | — | Shows whether an address is deliverable before you write. |
| Reply intelligence: paste or ingest a reply, AI analysis, signal read, draft reply with alternate angles, send with approval, reply history, sent audit | ❌ | ❌ | ✅ (`view.component`, about 15 actions) | — | The strongest "left behind" feature. Fits the phone well: a reply arrives, you get a read and a drafted answer. Stays draft-only and approval-first. |
| Introduce two contacts (Maya drafts the introduction) | ❌ (README v2) | ❌ | ❌ | — | New backend prompt needed. |
| Never-contacted contacts missing from the feed | Bug | — | — | — | `/network/cards` orders by `lastContacted`, which drops contacts without it. Must be fixed before a list can show every contact. |

### P1: native-only (the strongest answers to 4.3)

| Feature | Why it matters |
|---|---|
| **Import from iPhone Contacts** (`CNContactPickerViewController`) | The fastest way to fill the app, and impossible on the web. |
| **Scan a business card** (VisionKit text recognition) | Opens a pre-filled new contact. Made for the moment you meet someone. |
| **Follow-up reminders** (local notifications) | "Follow up with Maya Chen on Thursday", driven by communication stage and `lastContacted`. |
| **Home Screen and Lock Screen widgets** (WidgetKit) | Today's follow-ups and network health at a glance. |
| **Siri and Shortcuts** (App Intents) | "Add a note to Maya Chen", "Who should I follow up with?" |
| **Call and message logging** | A call or text started from Relationships counts as an interaction and moves the stage forward. |
| **Offline cache** | Read contacts and write notes without a signal (on a trade-show floor, say). Sync when back online. |

### P2: later, or never on mobile

- **Bulk update and bulk delete** (left behind, `list`). It's awkward on a phone; consider multi-select with one action.
- **Customer persona** and **reconfiguration status** (left behind). These are small and low value for this release.
- **Customer Momentum / Today's Momentum** (left behind, about 10,000 lines in `features/help/daily-momentum`). It's too big for this release.
- **Images and documents on a contact.** A photo attachment could come later.
- **Raw JSON view.** It's a web-only developer view; skip it.
- **Opportunities, proposals, contracts, invoices.** These fields are on the `Contact` model, but no current UI uses them.

## 4. Backend work this needs

1. **Mobile contact read and write endpoints** behind `verifiedMobileAuth`, the same pattern as `movesMobileRoutes.js` and `docsMobileRoutes.js`:
   - `GET /mobile/contacts` (paged, every contact).
   - `GET /mobile/contacts/:id` (full detail, minus sensitive fields like `ssn`).
   - `POST`, `PUT` and `DELETE`.
   - `POST /mobile/contacts/:id/notes`.
   - `POST /mobile/contacts/:id/status`.
   - `POST /mobile/contacts/:id/interactions`.

   Keep the README's rule: never send raw `Contact` documents to the phone.
2. **Fix the `lastContacted` ordering gap** in `/network/cards`, or drop the feed's dependence on it.
3. **Expose reply intelligence** through mobile endpoints. Find what `view.component.ts` calls, and wrap those calls with verified auth.
4. **Pipeline and progress data:** check whether `/network/stats` (`contactsByStatus`) is enough for the zones and action priorities, or whether a `/mobile/network/progress` endpoint is needed.

## 5. Rebrand checklist (Network → Relationships)

- App Store name: plain "Relationships" is almost certainly taken. Options: "TODD Relationships" or "Relationships by Taliferro". Check availability in App Store Connect.
- Change `CFBundleDisplayName`, the icon, the paywall copy, onboarding copy and award names that say "Network".
- Bundle ID `tech.taliferro.networkios` can't change and isn't shown to users, so keep it. Keep the same App Store record too; resubmitting it with substantial changes is what Apple asked for.
- Subscription product `TODDNetwork10001`: its display name can change; the ID can't.
- Rename the design's "Network health" to "Relationship health".
- For the resubmission's review notes: say what changed since the rejected build. List the new screens, full create and edit, and native features (Contacts import, card scan, reminders, widgets, Siri), and that it's a complete standalone relationship manager.

## 6. Suggested build order

1. Backend mobile contact endpoints, plus the `lastContacted` fix.
2. Design tokens to SwiftUI theme (light and dark), and the tab bar shell: Relationships · Contacts · Pipeline · Progress · Me.
3. Contacts list, then Contact detail (15t–15v), then the editor (create and edit), then notes, then status change.
4. Quick actions (Call, Text, Email) with interaction logging.
5. Relationships home (health and care cycle), then Pipeline lanes, then Progress.
6. Native features: iPhone Contacts import, business-card scan, reminders, widgets, App Intents.
7. Reply intelligence and enrichment.
8. Rebrand pass, new screenshots, review notes, resubmit.
