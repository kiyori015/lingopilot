# Windows Native Codex Handoff

This repository was prepared for migration from WSL2 to Windows native Codex on 2026-05-31.

## Current State

- Git remote: `https://github.com/kiyori015/lingopilot.git`
- Branch: `main`
- Latest deployed code commit before this handoff note: `d15e29b fix(supabase): serve lingopilot as html`
- GitHub Pages production URLs:
  - Korean: `https://kiyori015.github.io/lingopilot/`
  - Thai: `https://kiyori015.github.io/lingopilot/thai.html`
- Supabase project ref: `ieakvpwzhihqttcxegti`
- Supabase Edge Function: `lingopilot`

## Recent Fix

Login was restored from email OTP back to username and password authentication.

The deployed pages now use:

- Username input
- Password input
- `signInWithPassword`
- Auth email mapping: `<username>@lingopilot.local`

The same HTML was synchronized into:

- `src/index.html`
- `src/thai.html`
- `supabase/functions/lingopilot/index.html`
- `supabase/functions/lingopilot/thai.html`

## Verification Already Done

- Parsed inline scripts in all four HTML files with Node.
- Pushed fixes to GitHub.
- Confirmed GitHub Pages workflow succeeded.
- Opened and checked both GitHub Pages URLs in a browser.
- Deployed Supabase Edge Function with:
  - `npx supabase functions deploy lingopilot --project-ref ieakvpwzhihqttcxegti`

## Supabase Note

The standard Supabase Edge Function URL returns the updated HTML body, but Supabase rewrites `text/html` GET responses to `text/plain` unless a custom domain is used. Use GitHub Pages as the actual public page URL unless a custom Supabase domain is configured.

## Windows Native Notes

No WSL-specific source paths were found in the tracked project files.

Windows-side tool check from WSL found:

- `git` was not available in PowerShell PATH.
- `node` / `npm` were not available in PowerShell PATH.
- `python` resolved to the Windows app execution alias, not a confirmed full Python install.

For Windows native Codex, install or enable these on Windows if it needs to run Git, `npx supabase`, or a local HTTP server. Git for Windows installation was attempted with `winget`, but the installer requested UAC/admin confirmation.

Recommended checks after opening this folder in Windows native Codex:

```powershell
git status
git log --oneline -5
```

If Supabase deployment is needed from Windows and the Supabase CLI is not installed globally, use:

```powershell
npx supabase functions deploy lingopilot --project-ref ieakvpwzhihqttcxegti
```

For local static testing:

```powershell
python -m http.server 4173
```

Then open:

- `http://127.0.0.1:4173/src/index.html`
- `http://127.0.0.1:4173/src/thai.html`
