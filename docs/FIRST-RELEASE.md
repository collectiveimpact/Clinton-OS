2026-09-05 12:40 ET
Runbook. Project: Clinton-OS first desktop release via GitHub Actions. Version 1.0.

# First Clinton-OS release

Outcome: a Clinton-OS v0.2.0 release on your GitHub with a macOS arm64 DMG, macOS x64 DMG, Windows installer, Linux packages, and latest.json for the auto updater. About 25 minutes of runner time.

## 1. Create the repo and push

```
cd clinton-os
git remote add origin https://github.com/collectiveimpact/Clinton-OS.git
git branch -M main
git push -u origin main
```

Public repo is simplest. Private works too, the release assets are still downloadable by anyone with the release URL only if the repo is public. For a private repo the updater needs a token, so keep it public or accept manual updates.

## 2. Add two repo secrets

Settings, Secrets and variables, Actions, New repository secret.

| Secret | Value |
|---|---|
| TAURI_SIGNING_PRIVATE_KEY | The full contents of clinton-os.key from the keys folder in the fork zip. One line. |
| TAURI_SIGNING_PRIVATE_KEY_PASSWORD | Leave the value empty. The key was generated without a password. Create the secret anyway so the workflow variable exists. |

The matching public key is already in app/apps/desktop/src-tauri/tauri.conf.json. Keep the private key in your password manager. Lose it and every installed copy stops receiving updates.

Do not add the six APPLE_ secrets yet. With none of them set, Tauri signs the app ad hoc (signingIdentity "-") and skips notarization. That build runs on your Mac after one right click, Open.

## 3. Run the workflow

Actions, release, Run workflow, branch main, notarize unchecked, Run.

The gate job passes on manual dispatch regardless of version. Four platform jobs run in parallel. When they finish, Releases shows Clinton-OS v0.2.0 with the assets and latest.json.

## 4. Install on the Mac

1. Download Clinton-OS_0.2.0_aarch64.dmg from the release.
2. Drag Clinton-OS to Applications.
3. First launch: right click the app, Open, then Open again in the dialog. This is the ad hoc signing prompt, once.
4. Open existing, choose Clinton-2nd AI Brain. Add Business Solutions Brain the same way.
5. Vault settings, General, Server URL, paste your ca-central-1 domain. Sign up. Turn on sync.

Existing Baalda users on the same Mac: the bundle id is unchanged, so Clinton-OS reads the same vault registry and keychain entry. Remove Baalda.app afterwards to avoid two apps polling two update channels.

## 5. Later, signed and notarized builds

When you have an Apple Developer ID (99 USD a year):

| Secret | Source |
|---|---|
| APPLE_CERTIFICATE | Base64 of the Developer ID Application .p12 |
| APPLE_CERTIFICATE_PASSWORD | The .p12 password |
| APPLE_SIGNING_IDENTITY | Developer ID Application: Clinton Reid (TEAMID) |
| APPLE_ID | Your Apple account email |
| APPLE_PASSWORD | An app specific password from appleid.apple.com |
| APPLE_TEAM_ID | Ten character team id |

Set all six, change signingIdentity in tauri.conf.json from "-" to the identity string, and run the workflow with notarize checked. docs/RELEASE.md covers the rest.

## 6. Every release after this one

Bump the version in the four files (tauri.conf.json, package.json, Cargo.toml, Cargo.lock) and merge to main. The workflow ships automatically. Installed apps update on their next poll after verifying the minisign signature.
