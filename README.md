# Pinpoint

Bowling score tracker. Sign up, log your games (final score or all 10 frames), and see your average, high game, last-10 average, strike/spare rates, and trend.

Static site (plain HTML + JS) using Supabase for logins and storage. Hosted free on GitHub Pages.

## Setup

1. **Supabase** — create a new project (separate from any other app).
   - SQL Editor → New query → paste `setup.sql` → Run.
   - Authentication → Sign In / Providers → Email: turn **off** "Confirm email" so people can start right away (Supabase's free email sender only allows a few emails per hour).
   - Authentication → URL Configuration: set **Site URL** to your GitHub Pages address, e.g. `https://nextlevellighting.github.io/pinpoint/`, and add it under Redirect URLs (needed for password reset links).
   - Project Settings → API: copy the **Project URL** and **anon / publishable key** into `config.js`.
2. **GitHub Pages** — push these files to a repo, then Settings → Pages → Source: *Deploy from a branch* → `main` / root → Save.

## Files

- `index.html` — the whole app
- `config.js` — your Supabase URL + public key
- `setup.sql` — database table + security rules (each user sees only their own games)
- `manifest.webmanifest`, `icon*.png`, `icon.svg` — home-screen app icon
