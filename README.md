# MiFi

Crowdsourced Wi-Fi for iPhone. Find Wi-Fi passwords that people have shared near you, and share the ones you know.

- **iOS 15+**, UIKit, classic iOS 11–14 look (grouped lists, large titles, blue tint, no Liquid Glass — the build sets `UIDesignRequiresCompatibility`).
- **Backend is this repo.** No servers.

## How the backend works

| | |
|---|---|
| **Read** | The app downloads static JSON tiles from `data/tiles/<geohash5>.json` (raw.githubusercontent.com) for the ~5 km tile around you plus its 8 neighbours. |
| **Write** | The app files a GitHub issue titled `[MiFi] add: …` / `[MiFi] report: …` containing a JSON payload. |
| **Ingest** | `.github/workflows/ingest.yml` runs `scripts/ingest.py`, which validates the payload, merges it into the right tile (same SSID within 150 m updates the entry), commits it, and closes the issue. Three distinct reporters remove a network. |

Because the app can't hold a secret, writes use the **submitter's own GitHub account**:
either GitHub device-flow sign-in inside the app, or a pre-filled "new issue" page in Safari (no setup needed).

> The ingest workflow is triggered by `issues`, so it only runs once it exists on the **default branch (`main`)**.

## Building the unsigned IPA

Push to `main` (or run **Actions → Build unsigned IPA → Run workflow**). The IPA is available as:

- the `MiFi-unsigned-ipa` workflow artifact, and
- the rolling [`latest` release](../../releases/tag/latest) (main only).

It is **unsigned**: sign/install it yourself with AltStore, Sideloadly, TrollStore, etc.
Note: "Join Network" uses `NEHotspotConfiguration`, which needs the Hotspot Configuration entitlement. If your signing method doesn't add it, the app falls back to copying the password.

### Optional: in-app GitHub sign-in

1. GitHub → Settings → Developer settings → OAuth Apps → New. Tick **Enable Device Flow**. Any homepage/callback URL.
2. Add the Client ID as a repository **variable** named `MIFI_GH_CLIENT_ID` (Settings → Secrets and variables → Actions → Variables).
3. Rebuild. Without it, the app uses the Safari fallback.

## Project layout

```
project.yml            XcodeGen spec (generates MiFi.xcodeproj in CI)
MiFi/Core              models, geohash, GitHub client, device flow, location, store
MiFi/UI                Nearby list, Map, Detail, Add, Settings
scripts/ingest.py      submission validator / tile writer (stdlib only)
data/tiles/            the database
```

## Responsible use

Only share passwords the owner publishes for public use (cafés, libraries, shops, venues). Submissions are public and tied to your GitHub username. Don't share private home networks.
