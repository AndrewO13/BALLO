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

## Apple Developer / Google Play

- **Apple:** Create App ID `com.ballonetwork.app` (or let Xcode Automatic Signing register it on first archive). Update Sign in with Apple Services ID return URL if used.
- **Google Cloud OAuth:** Add `com.ballonetwork.app` as the Android package name / iOS bundle ID for the OAuth clients. Add authorized redirect URI for web if using Google on web.
- **Google Play Console:** Application ID must match `com.ballonetwork.app` (changing ID after first publish requires a new listing).
