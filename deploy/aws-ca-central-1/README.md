2026-09-04 21:10 ET
Deploy runbook. Project: Clinton-OS server on AWS ca-central-1. Version 1.0.

# Clinton-OS server on AWS Canada

One EC2 host in ca-central-1 (Montreal) runs Postgres, the sync server, Caddy for TLS, and a nightly dump to S3. Client data never leaves Canada. Nothing in this folder stores a credential.

## What you need before running

- AWS account with the CLI signed in (aws sts get-caller-identity returns your account).
- A domain you control. Example used below: brain.clinton-os.ca.
- The fork pushed to GitHub. Example: https://github.com/clinton-reid/clinton-os.git. A private repo needs a deploy key on the instance. Public is simpler.

## Run

```
cd deploy/aws-ca-central-1
./deploy.sh brain.clinton-os.ca https://github.com/clinton-reid/clinton-os.git
```

The script creates, in order: the S3 backup bucket with 30 day expiry and public access blocked, an instance role limited to that bucket plus SSM, a security group with 80 and 443 only, an Ubuntu 24.04 arm64 t4g.small with a 30 GB encrypted gp3 volume, an Elastic IP, and a daily EBS snapshot policy. Cloud init installs Docker, clones the fork, generates POSTGRES_PASSWORD and JWT_SECRET on the box, and starts the stack.

Then create one DNS A record pointing the domain at the printed Elastic IP. Caddy issues the Let's Encrypt certificate on first request.

## Verify

```
curl https://brain.clinton-os.ca/health          # {"ok":true}
curl -i https://brain.clinton-os.ca/api/mcp      # 401 with WWW-Authenticate, correct
```

In the desktop app: Vault settings, General, Server URL = https://brain.clinton-os.ca. Sign up. The first account becomes owner of the first vault.

## Cost, monthly, CAD approximate

| Item | Cost |
|---|---|
| t4g.small on demand | 22 |
| 30 GB gp3 plus 14 snapshots | 6 |
| Elastic IP | 5 |
| S3 dumps, under 1 GB | 1 |
| Total | about 34 |

A one year reserved t4g.small drops the first line to about 13.

## Operate

| Task | Command |
|---|---|
| Shell on the box, no SSH keys | aws ssm start-session --target INSTANCE_ID |
| Logs | sudo docker compose -f /opt/clinton-os/deploy/aws-ca-central-1/docker-compose.yml logs -f server |
| Upgrade server | cd /opt/clinton-os && sudo git pull && cd deploy/aws-ca-central-1 && sudo docker compose up -d --build |
| Manual dump | sudo docker compose exec postgres pg_dump -U context -Fc context > context.dump |
| Restore | sudo docker compose exec -T postgres pg_restore -U context -d context --clean < context.dump |
| Rotate JWT_SECRET | Edit .env, docker compose up -d server. Every device signs in again. |

Migrations run before the server starts on every deploy. They are idempotent.

## Security posture

- Port 22 closed. Access through SSM Session Manager only, logged in CloudTrail.
- IMDSv2 required. Instance role can write to one bucket and nothing else.
- Postgres is not published to the host network.
- JWT_SECRET generated on the instance at first boot, never in git, never in this chat.
- Notes travel as Yjs binary over TLS. The server operator (you) can reconstruct them. At rest encryption of the volume is on. Application level encryption is not, same as upstream.

## Desktop release for the fork

The desktop app auto updates from the endpoint in tauri.conf.json, now set to the clinton-reid/clinton-os GitHub releases. Before the first release:

1. Generate a signing key: pnpm tauri signer generate -w ~/.tauri/clinton-os.key
2. Paste the public key into tauri.conf.json plugins.updater.pubkey (currently a placeholder that fails the build on purpose).
3. Add TAURI_SIGNING_PRIVATE_KEY and the Apple Developer ID secrets to the GitHub repo per docs/RELEASE.md.
4. Bump the version in the four files listed in docs/RELEASE.md and merge to main.

Until then, run the stock Baalda 0.1.47 app against this server. The app is identical against any compliant server. Only the brand and colours differ.
