# App Store Review Notes — Content Safety (Guideline 1.2)

Paste into **App Store Connect → App Review Information → Notes**.

---

## Demo account

Use this pre-seeded account for App Review (onboarding complete, Community Guidelines accepted):

| Field | Value |
|---|---|
| **Email** | `reviewer@ballonetwork.com` |
| **Password** | `BalloReview2026!` |

Seeded content for this account:
- Player profile: **App Reviewer** (`@appreviewer`)
- League: **App Review League** (owner)
- Teams: **Review United** (captain) and **Demo FC**
- Matches: 1 finished (3–1) + 1 upcoming
- Explore: 2 approved sample highlight videos (Report / Block available on feed cards)

Backend (Supabase) will be live during review.

## User-generated content safety

Ballo includes UGC (match highlight videos, profile/team/league images and names, Explore feed).

### Filtering before / during posting
- Text (player names, usernames, team/league names) and images (avatars, logos, banners) are checked via the **OpenAI Moderation API** (`omni-moderation-latest`) through a **Supabase Edge Function** (`moderate-content`). The OpenAI API key never ships in the client.
- Videos: the app samples up to 15 frames (first/last + every ~2.5s, max 60s clip), sends frames to the same Edge Function, then **discards frames immediately**. Full videos are never sent to OpenAI.
- Football context: violence thresholds are relaxed for match highlights to reduce false positives on tackles; clearly abusive content is still rejected.

### Borderline (human review queue)
- Content scored in a grey zone is **published immediately** as `pending_review` and entered into an asynchronous moderation queue.
- Humans review queue items within our SLA (below); if confirmed violating, content is removed (`rejected`) after the fact.
- This avoids blocking 99% of legitimate uploads while still meeting safety expectations.

### Report
- Every Explore video card and full-screen player has a **Report** action.
- Reports are stored in `content_reports` with reason + optional details.

### Block
- Users can **Block** an uploader from the report sheet (or block dialog).
- Blocking immediately hides that user’s videos from the blocker’s Explore feed (`user_blocks` + feed RPC filtering). Follow relationships are removed.
- Block is preferred for stop-seeing-abuse-now; Report is for platform action.

### Contact
- In-app: Settings → Help & Support opens `mailto:info@ballonetwork.com`
- Community Guidelines (in-app modal + web): https://app.ballonetwork.com/community-guidelines
- Support email also shown in guidelines.

### Legal URLs (App Store Connect)
After deploying the Flutter web build (so `web/privacy.html` and `web/terms.html` are live):

| Field | URL |
|---|---|
| **Privacy Policy URL** | https://app.ballonetwork.com/privacy |
| Terms and Conditions | https://app.ballonetwork.com/terms |
| Community Guidelines | https://app.ballonetwork.com/community-guidelines |
| Support | info@ballonetwork.com |

**Bundle / application ID:** `com.ballonetwork.app` (iOS + Android). OAuth redirect: `com.ballonetwork.app://login-callback` — see [PRODUCTION_BUNDLE_ID.md](./PRODUCTION_BUNDLE_ID.md).

Legal entity on those pages: **BALLO NETWORK LTD** (Uganda). Also available as `.html` paths (`/privacy.html`, `/terms.html`) if clean redirects are not yet active on the host.

### Community Guidelines
- Shown as a required acknowledgment modal after account creation (email verify / OAuth).
- Also available anytime from Settings → Community Guidelines.
- In-app Terms / Privacy open the live web pages above (Settings + onboarding).

## No gambling / Predictions feature

Ballo shows **Predictions** (win / draw / lose **percentages**) on match cards and fixture detail. These are heuristic estimates from in-app form, standings, squad ratings, and head-to-head — for entertainment only.

- **No real-money betting**, wagering, deposits, payouts, or gambling services.
- **No bookmaker odds** or ability to place bets in the app.
- UI label: **Predictions**; disclaimer on fixture detail: *For fun only — no real-money betting*.
- Terms prohibit using the Service for gambling or illegal betting.

## Response SLA

| Queue | Target |
|---|---|
| User content reports | **Within 24 hours** |
| Borderline auto-queue (`pending_review`) | **Within 24 hours** |
| Critical safety (CSAM / credible threats) | Escalate immediately; remove content and contact authorities as required |

Contact for App Review / users: **info@ballonetwork.com**

## Secrets required (ops)

Set Supabase Edge Function secret before production:

```bash
supabase secrets set OPENAI_API_KEY=sk-...
```

`SUPABASE_SERVICE_ROLE_KEY` is available to Edge Functions by default for enqueueing review items.
