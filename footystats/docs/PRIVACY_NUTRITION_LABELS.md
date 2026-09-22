# App Store Privacy Nutrition Labels — Ballo

Use this when filling **App Store Connect → App Privacy → Privacy Nutrition Labels**.
Aligned with `web/privacy.html` and `ios/Runner/PrivacyInfo.xcprivacy`.

**Privacy Policy URL:** `https://app.ballonetwork.com/privacy.html`  
**Tracking:** No (no ATT / IDFA / cross-app advertising).

---

## 1. Data collection overview

| Do you or third-party partners collect data? | **Yes** |
| Do you use data for tracking? | **No** |
| Privacy Nutrition Label “Used for Tracking” | Leave **unchecked** for every type |

Third parties that process data on our behalf (processors, not trackers):

| Partner | Role | Data involved |
|---|---|---|
| **Supabase** | Auth, DB, storage, realtime, edge functions | Account, profile, UGC, feed analytics |
| **OpenAI** | Content moderation only | Text, images, sampled video frames (not full videos) |
| **Google** | Google Sign-In OAuth | Email / name / provider user ID (if user chooses Google) |
| **Apple** | Sign in with Apple | Email / name / Apple user ID (if user chooses Apple) |

No advertising SDKs, analytics suites (e.g. Firebase Analytics, Amplitude), or attribution SDKs ship in the iOS build.

---

## 2. Data types to declare

For each type: **Linked to User = Yes**, **Used for Tracking = No**.

### Contact Info

| Type | Collected | Purposes | Notes |
|---|---|---|---|
| **Email Address** | Yes | App Functionality | Sign-up, login, password reset, account recovery |
| Name | No (use “Name” under Identifiers / Contact? → use **Name** below) | — | Declared as **Name** |
| Phone Number | **No** | — | — |
| Physical Address | **No** | — | — |
| Other Contact Info | **No** | — | Support email content → **Customer Support** |

### Identifiers

| Type | Collected | Purposes | Notes |
|---|---|---|---|
| **User ID** | Yes | App Functionality | Supabase Auth UUID / profile id |
| Device ID | **No** | — | No IDFA / advertising identifier |
| **Name** | Yes | App Functionality | Player name, username, display name |

### Location

| Type | Collected | Purposes | Notes |
|---|---|---|---|
| Precise Location | **No** | — | No GPS / continuous location |
| **Coarse Location** | Yes | App Functionality | Country selected in onboarding only |

### User Content

| Type | Collected | Purposes | Notes |
|---|---|---|---|
| **Photos or Videos** | Yes | App Functionality | Avatars, logos, banners, match highlights |
| Audio Data | **No** | — | Whistle SFX is bundled, not user audio |
| **Customer Support** | Yes | App Functionality | Optional emails to `info@ballonetwork.com` |
| **Other User Content** | Yes | App Functionality | Match stats, lineups, posts, reports, social URLs |

### Usage Data

| Type | Collected | Purposes | Notes |
|---|---|---|---|
| **Product Interaction** | Yes | App Functionality, Analytics, Product Personalization | Explore: videos shown, watch duration, completion, likes, follows, shares |
| Advertising Data | **No** | — | — |
| Other Usage Data | **No** | — | Covered under Product Interaction |

### Diagnostics / Purchases / Sensitive / Contacts / etc.

Declare **No** for: Health, Fitness, Financial, Payment, Credit, Other Financial, Precise Location, Contacts, Search History, Browsing History, Sensitive Info (as a Nutrition category), Crash Data (unless you add a crash reporter later), Performance Data, Other Diagnostic Data, Purchases.

Sports stats are **Other User Content**, not Health.

---

## 3. Purpose mapping (App Store Connect wording)

| Purpose | When to select |
|---|---|
| **App Functionality** | Auth, profiles, matches, UGC upload/display, moderation, invites, support |
| **Analytics** | Feed engagement metrics used to understand / improve ranking |
| **Product Personalization** | Ranking / personalizing the Explore video feed |
| Advertising | **Do not select** |
| Third-Party Advertising | **Do not select** |
| Developer Advertising | **Do not select** |
| Other Purposes | **Do not select** |

---

## 4. PrivacyInfo.xcprivacy (shipped in the app)

| File | Role |
|---|---|
| `ios/Runner/PrivacyInfo.xcprivacy` | App-level: tracking=false, collected types above, required-reason APIs |
| Plugin manifests (auto-merged) | See table below |

### Required Reason APIs (app manifest)

| API category | Reason code | Why |
|---|---|---|
| UserDefaults | `CA92.1` | Onboarding flags, local prefs, video-seen cache |
| File timestamp | `C617.1` | Cache / media file access in app container |
| Disk space | `E174.1` | Before writing/caching media |
| System boot time | `35F9.1` | Timing between in-app events (Flutter engine path) |

### Flutter plugins that already ship `PrivacyInfo.xcprivacy`

These are pulled in via CocoaPods / SPM and merged at archive — do **not** duplicate their API reasons unless your own Swift/ObjC code also calls them:

| Plugin | Notes |
|---|---|
| `shared_preferences_foundation` | UserDefaults |
| `google_sign_in_ios` | Empty API list; OAuth via system APIs |
| `url_launcher_ios` | Opens links (privacy, terms, OAuth) |
| `app_links` | Deep links / auth callbacks |
| `connectivity_plus` | Network reachability |
| `image_picker_ios` | Photo / video library & camera |
| `video_player_avfoundation` | Explore / highlight playback |
| `permission_handler_apple` | Camera / photo / notification permission prompts |
| `share_plus` | System share sheet |
| `sqflite_darwin` | Local DB (via transitive deps if present) |
| `flutter_native_splash` | Launch screen |

Dart-only / no separate Apple privacy SDK: `supabase_flutter`, `dio`, `google_fonts`, `video_compress`, `audioplayers`, Riverpod, etc. Their network calls go through app + Supabase; declare collection at the **app** Nutrition Label level (this doc), not as separate SDK entries.

### Apple “third-party SDK” list

Of Apple’s commonly listed SDKs requiring manifests, Ballo currently includes **Google Sign-In** (`google_sign_in`), which already ships `PrivacyInfo.xcprivacy`. No Firebase / Facebook / Adjust / AppsFlyer SDKs.

---

## 5. Checklist in App Store Connect

1. App Privacy → **Get Started** / **Edit**
2. Answer **Yes** to data collection; **No** to tracking
3. Add each **Yes** type from §2 with Linked=Yes, Tracking=No, purposes from §3
4. Set Privacy Policy URL to `https://app.ballonetwork.com/privacy.html`
5. Archive an iOS build that includes `Runner/PrivacyInfo.xcprivacy` (wired in Xcode Resources)
6. After upload, confirm Privacy Report in Xcode Organizer shows expected required-reason APIs + no unexpected tracking domains

---

## 6. When to update this doc

Update Nutrition Labels **and** `PrivacyInfo.xcprivacy` if you add:

- Crash / analytics SDKs (Sentry, Firebase Crashlytics, Mixpanel, …)
- Advertising or attribution SDKs
- Precise location, contacts, microphone recording, or payment
- Push notification providers that collect device tokens for marketing
- Any “Used for Tracking” / ATT flow
