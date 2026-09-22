# Production app identity & Auth redirects

## Bundle / application ID

| Platform | ID |
|---|---|
| iOS / Android / macOS / Linux | `com.ballonetwork.app` |

## Auth redirect URLs

| Platform | Redirect |
|---|---|
| iOS / Android | `com.ballonetwork.app://login-callback` |
| Web | `https://app.ballonetwork.com/login-callback` |

## Supabase Auth (hosted project `dcpltazuzyyhxtkpbuiu`)

In [Auth URL Configuration](https://supabase.com/dashboard/project/dcpltazuzyyhxtkpbuiu/auth/url-configuration):

1. **Site URL:** `https://app.ballonetwork.com`
2. **Additional Redirect URLs** (one per line):
   - `com.ballonetwork.app://login-callback`
   - `com.ballonetwork.app://**`
   - `https://app.ballonetwork.com/login-callback`
   - `https://app.ballonetwork.com/**`
   - `https://app.ballonetwork.com`
   - `http://localhost:*/login-callback` (optional, local web)

Or with CLI (after `npx supabase login`):

```bash
npx supabase config push --project-ref dcpltazuzyyhxtkpbuiu --yes
```

(`supabase/config.toml` already has these auth URLs.)

You can also run `.\scripts\update-supabase-auth-urls.ps1` with `SUPABASE_ACCESS_TOKEN` set.

## Sign in with Apple (required for App Store)

Ballo uses **native** Sign in with Apple on iOS/macOS (`signInWithIdToken`) and **OAuth** on Android.

### 1. Apple Developer

1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → App ID `com.ballonetwork.app` → enable **Sign In with Apple**.
2. (Android / web OAuth only) Create a **Services ID** (e.g. `com.ballonetwork.app.web`), configure Website URLs:
   - Domains: `dcpltazuzyyhxtkpbuiu.supabase.co`
   - Return URL: `https://dcpltazuzyyhxtkpbuiu.supabase.co/auth/v1/callback`
3. (Android / web OAuth only) Create a **Key** with Sign in with Apple → download `.p8` once. Note **Key ID** and **Team ID**.

### 2. Supabase Dashboard → Authentication → Providers → Apple

Enable Apple and set:

| Field | Value |
|---|---|
| **Client IDs** | Services ID first (for OAuth), then App ID `com.ballonetwork.app` for native iOS. Example: `com.ballonetwork.app.web, com.ballonetwork.app` |
| Secret / Key | Team ID, Key ID, and `.p8` contents (needed for OAuth; native iOS mainly needs the App ID in Client IDs) |

Order matters for web/Android OAuth: **Services ID must be first**. Native iOS accepts any listed Client ID as the token audience.

### 3. Xcode (on Mac)

1. Open `ios/Runner.xcworkspace`.
2. **Signing & Capabilities** → select your Apple Developer **Team** (Automatic signing).
3. Confirm **Sign in with Apple** capability is present (wired via `Runner/Runner.entitlements`).
4. Run on a **physical iPhone** and tap Continue with Apple.

## Apple Developer / Google Play

- **Apple:** Create App ID `com.ballonetwork.app` (or let Xcode Automatic Signing register it on first archive). Enable Sign in with Apple as above.
- **Google Cloud OAuth:** Add `com.ballonetwork.app` as the Android package name / iOS bundle ID for the OAuth clients. Add authorized redirect URI for web if using Google on web.
- **Google Play Console:** Application ID must match `com.ballonetwork.app` (changing ID after first publish requires a new listing).
