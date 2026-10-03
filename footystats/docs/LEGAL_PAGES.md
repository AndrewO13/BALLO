# Legal pages (Privacy & Terms)

Public URLs (after you deploy the `web/` folder with your Flutter web host / cPanel):

- Privacy Policy: https://app.ballonetwork.com/privacy
- Terms and Conditions: https://app.ballonetwork.com/terms
- Community Guidelines: https://app.ballonetwork.com/community-guidelines
- **Account deletion (Google Play):** https://app.ballonetwork.com/account-deletion

Source files:

- [`web/privacy.html`](../web/privacy.html) — BALLO NETWORK LTD Privacy Policy (last updated June 1, 2026)
- [`web/terms.html`](../web/terms.html) — Terms and Conditions (last updated June 1, 2026)
- [`web/community-guidelines.html`](../web/community-guidelines.html)
- [`web/account-deletion.html`](../web/account-deletion.html) — Play Store account deletion URL

## Deploy (cPanel)

Upload these files from `footystats/web/` into your site document root (same place as `index.html`):

- `account-deletion.html` *(required for Play Console)*
- `privacy.html`
- `terms.html`
- `community-guidelines.html`
- `_redirects` (Cloudflare-style clean URLs)
- `.htaccess` (Apache / LiteSpeed / typical cPanel clean URLs)
- `_routes.json` (excludes legal paths from worker SPA handling)

Then open https://app.ballonetwork.com/account-deletion in a browser and confirm it is **not** swallowed by the Flutter SPA.

## Google Play Console

**App content → Data safety / Account deletion** URL:

`https://app.ballonetwork.com/account-deletion`

(If clean URLs are not active yet, use `https://app.ballonetwork.com/account-deletion.html`.)

## App Store Connect

Set **Privacy Policy URL** to:

`https://app.ballonetwork.com/privacy`

## In-app

Settings and onboarding Terms / Privacy links open these pages via `url_launcher`.
