#!/bin/sh
# Imports the workflows into the running n8n container with your Discord
# webhook URL filled in, publishes them so their schedules run, and restarts
# n8n. Run it again after you change a workflow file: it updates the same
# workflows instead of making copies.
#
# Usage: ./publish-workflows.sh 'https://discord.com/api/webhooks/...'
set -eu

url="${1:-${DISCORD_WEBHOOK_URL:-}}"
case "$url" in
  https://discord.com/api/webhooks/* | https://discordapp.com/api/webhooks/*) ;;
  *)
    echo "Usage: $0 'https://discord.com/api/webhooks/...'" >&2
    exit 1
    ;;
esac

cd "$(dirname "$0")"

# The n8n CLI starts its own task broker, so give it a port that the running
# n8n server is not using.
docker compose exec -T -e N8N_RUNNERS_BROKER_PORT=5690 -e WEBHOOK="$url" n8n sh -c '
  set -e
  rm -rf /tmp/metsxm && mkdir /tmp/metsxm
  for f in /workflows/*.json; do
    sed "s#PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE#$WEBHOOK#" "$f" > "/tmp/metsxm/$(basename "$f")"
  done
  n8n import:workflow --separate --input=/tmp/metsxm
  for id in $(grep -ho "\"id\": \"MetsXM[A-Za-z0-9]*\"" /tmp/metsxm/*.json | cut -d\" -f4); do
    n8n publish:workflow --id="$id"
  done
  rm -rf /tmp/metsxm
'

docker compose restart n8n
echo "Done. The MetsXMFanZone workflows are published and will run on schedule."
