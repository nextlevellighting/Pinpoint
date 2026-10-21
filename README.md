# Pinpoint

Bowling score tracker. Scan the lane screen or type your score, compare averages with friends, and track weekly league nights.

Static site (plain HTML + JS) using Supabase for logins and storage. Hosted free on GitHub Pages.

## Setup

1. **Supabase** — create a new project (separate from any other app).
   - SQL Editor → New query → paste `setup.sql` → Run.
   - Authentication → Sign In / Providers → Email: turn **off** "Confirm email" so people can start right away (Supabase's free email sender only allows a few emails per hour).
   - Authentication → URL Configuration: set **Site URL** to your GitHub Pages address, e.g. `https://nextlevellighting.github.io/pinpoint/`, and add it under Redirect URLs (needed for password reset links).
   - Project Settings → API: copy the **Project URL** and **anon / publishable key** into `config.js`.
2. **GitHub Pages** — push these files to a repo, then Settings → Pages → Source: *Deploy from a branch* → `main` / root → Save.

## Upgrade (friends, leagues, scanning)

1. SQL Editor → run `setup-v2.sql` (after `setup.sql`).
2. Get a free Gemini API key at https://aistudio.google.com → Get API key.
3. Supabase → Edge Functions → Deploy a new function → Via Editor → name it `scan` → paste `supabase/functions/scan/index.ts` → Deploy.
4. Edge Functions → Secrets → add `GEMINI_API_KEY` with your key.

## Live updates

SQL Editor → run `setup-v3.sql` to turn on Supabase Realtime for games, friends, and leagues.

## Releasing an update

Bump the version in **both** `version.json` and `APP_VERSION` in `index.html` (and the `config.js?v=` tag). Open copies of the app check `version.json` on open and every 5 minutes, and reload themselves when it changes.

## Files

- `index.html` — the whole app
- `config.js` — your Supabase URL + public key
- `setup.sql` — games table + security rules
- `setup-v2.sql` — usernames, friends, leagues, and who-can-see-what rules
- `setup-v3.sql` — turns on live updates
- `version.json` — current version; open apps reload when it changes
- `supabase/functions/scan/index.ts` — photo scanning (Gemini)
- `manifest.webmanifest`, `icon*.png`, `icon.svg` — home-screen app icon
