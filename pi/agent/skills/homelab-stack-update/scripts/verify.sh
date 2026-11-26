#!/usr/bin/env bash
# Post-update health + routing check for the homelab docker host. Feed it over
# ssh exactly like update.sh; re-run it freely a few minutes later.
# Uses the baseline update.sh wrote to tell regressions from pre-existing failures.

BASELINE=/root/.stack-update-baseline

docker info >/dev/null 2>&1 || { echo "docker is not reachable"; exit 1; }
state() { docker inspect -f '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}-{{end}}' "$1" 2>/dev/null || echo "gone/-"; }
before() { [ -f "$BASELINE" ] && awk -F'\t' -v n="$1" '$1 == n { print $3 }' "$BASELINE"; }

echo "== regressions: running before, not running/healthy now"
if [ -f "$BASELINE" ]; then
  while IFS=$'\t' read -r name st status; do
    [ "$st" = running ] || continue
    now=$(state "$name")
    case "$now" in running/healthy | running/-) continue ;; esac
    echo "  $now   $name   (before: $status)"
  done < "$BASELINE"
else
  echo "  (no baseline at $BASELINE — run update.sh first; only the 'before' column is affected)"
fi

echo "== anything restarting, unhealthy or exiting right now"
for c in $(docker ps -q); do
  s=$(state "$c")
  case "$s" in running/healthy | running/-) continue ;; esac
  n=$(docker inspect -f '{{.Name}}' "$c" | tr -d /)
  echo "  $s   $n   (before: $(before "$n"))"
done

echo "== Traefik-routed sites: Host label -> status via 127.0.0.1:443 (2xx/3xx/401 = ok)"
# "/" is unrouted by design on these hosts, so probe a real endpoint instead.
declare -A PROBE_PATH=([ourmoments-api.jeppebs.xyz]=/api/health)
NO_GET=" m2s.terragrouplabs.net "   # webhook that only answers POST: HTTP cannot prove it; judge by container state
probe() { curl -sk -o /dev/null -w '%{http_code}' --max-time 8 --resolve "$1:443:127.0.0.1" "https://$1$2" </dev/null; }
pending=""
for h in $(docker inspect $(docker ps -q) </dev/null | grep -oE 'Host\(`[^`]+`\)' | sed -e 's/^Host(`//' -e 's/`)$//' | sort -u); do
  case "$NO_GET" in *" $h "*) echo "  --   $h (no GET route; judge by container state)"; continue ;; esac
  path=${PROBE_PATH[$h]:-/}
  code=$(probe "$h" "$path")
  case "$code" in 2?? | 3?? | 401) echo "  OK   $code $h$path" ;; *) pending="$pending $h"; echo "  ??   $code $h$path" ;; esac
done
for _ in 1 2 3; do
  [ -z "$pending" ] && break
  echo "   ...$pending still warming up, retrying in 15s"; sleep 15; still=""
  for h in $pending; do
    code=$(probe "$h" "${PROBE_PATH[$h]:-/}")
    case "$code" in 2?? | 3?? | 401) echo "  OK   $code $h (after retry)" ;; *) still="$still $h" ;; esac
  done
  pending="$still"
done
[ -n "$pending" ] && echo "  FAIL$pending  (000 = TLS/connection, 404 = route without backend, 5xx = app error)"
exit 0
