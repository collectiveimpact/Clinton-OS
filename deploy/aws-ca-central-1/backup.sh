#!/bin/sh
# Nightly pg_dump to S3 at 03:15 UTC (23:15 ET). Keeps 30 daily copies via bucket lifecycle.
set -eu
yum install -y -q postgresql16 >/dev/null 2>&1 || apk add --no-cache postgresql16-client >/dev/null 2>&1 || true
while true; do
  now=$(date -u +%s); next=$(date -u -d "tomorrow 03:15" +%s 2>/dev/null || echo $((now+86400)))
  sleep $((next - now))
  stamp=$(date -u +%Y-%m-%dT%H%M)
  pg_dump -h postgres -U context -d context -Fc -f /tmp/context-$stamp.dump
  aws s3 cp /tmp/context-$stamp.dump "s3://$BACKUP_BUCKET/pg/context-$stamp.dump" --sse AES256
  rm -f /tmp/context-$stamp.dump
done
