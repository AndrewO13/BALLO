# Legal pages (Privacy & Terms)

Public URLs (after you deploy the `web/` folder with your Flutter web host):

- Privacy Policy: https://app.ballonetwork.com/privacy
- Terms and Conditions: https://app.ballonetwork.com/terms
- Community Guidelines: https://app.ballonetwork.com/community-guidelines

Source files:

- [`web/privacy.html`](../web/privacy.html) — BALLO NETWORK LTD Privacy Policy (last updated June 1, 2026)
- [`web/terms.html`](../web/terms.html) — Terms and Conditions (last updated June 1, 2026)
- [`web/community-guidelines.html`](../web/community-guidelines.html)

## Deploy

Include these files from `footystats/web/` in your usual web deploy:

- `privacy.html`
- `terms.html`
- `community-guidelines.html`
- `_redirects` (Cloudflare-style clean URLs)
- `.htaccess` (Apache / LiteSpeed clean URLs)
- `_routes.json` (excludes legal paths from worker SPA handling)

Then open the URLs in a browser to confirm they are not swallowed by the Flutter `index.html` SPA.

## App Store Connect

Set **Privacy Policy URL** to:

`https://app.ballonetwork.com/privacy`

## In-app

Settings and onboarding Terms / Privacy links open these pages via `url_launcher`.
