#!/usr/bin/env bash
# Updates every running Docker Compose stack on the homelab docker host.
# Run it ON the host by feeding it over ssh (nothing to copy):
#   ssh -i ~/.ssh/ubuntu_w_docker root@10.10.10.10 'bash -s' < update.sh
# Pull failures are reported, never fatal. Writes the pre-update container state
# to $BASELINE so verify.sh can tell regressions from pre-existing failures.

SKIP_RE='minecraft|mc-router|mc-afk|m2s'   # never touch these stacks
BASELINE=/root/.stack-update-baseline

docker info >/dev/null 2>&1 || { echo "docker is not reachable"; exit 1; }
docker ps -a --format '{{.Names}}\t{{.State}}\t{{.Status}}' > "$BASELINE"

updated=0 recreated=0 pullerr=0 wdone=""
# One row per compose project that currently has a running container.
while IFS=$'\t' read -r proj files wdir; do
  [ -z "$proj" ] && continue
  ffs=""; oldIFS=$IFS; IFS=,
  for f in $files; do [ -f "$f" ] && ffs="$ffs -f $f"; done
  IFS=$oldIFS
  if printf '%s %s' "$proj" "$wdir" | grep -qiE "$SKIP_RE"; then echo "SKIP   $proj (minecraft)"; continue; fi
  if [[ "$files" == /_work/* || "$files" == /tmp/runner/* ]]; then echo "SKIP   $proj (CI-deployed checkout)"; continue; fi
  if [ -z "$ffs" ]; then echo "SKIP   $proj (compose file not on host: ${files:-none})"; continue; fi
  # shellcheck disable=SC2086  # ffs/svcs are meant to word-split
  svcs=$(docker compose -p "$proj" $ffs ps --services --status running </dev/null 2>/dev/null | tr '\n' ' ')
  [ -z "$svcs" ] && { echo "SKIP   $proj (no running services)"; continue; }
  echo "== $proj  [running: $svcs]"
  if out=$(docker compose -p "$proj" $ffs pull --ignore-buildable </dev/null 2>&1); then
    printf '%s\n' "$out" | grep -E 'Pulled' | sed 's/^/       /'
  else
    pullerr=$((pullerr + 1))
    printf '%s\n' "$out" | grep -E 'Pulled|Error|unauthorized|interpolat' | grep -v 'Error response from daemon' | sed 's/^/       /'
  fi
  # Only the services that were already running: stopped ones stay stopped.
  if ! out=$(docker compose -p "$proj" $ffs up -d $svcs </dev/null 2>&1); then
    printf '%s\n' "$out" | grep -E 'rror' | tail -1 | sed 's/^/       up FAILED: /'
  fi
  n=$(printf '%s\n' "$out" | grep -c ' Recreated')
  updated=$((updated + 1)); recreated=$((recreated + n))
  [ "$n" -gt 0 ] && printf '%s\n' "$out" | grep ' Recreated' | awk '{print "       recreated", $2}'
  wdone="$wdone$wdir"$'\n'
done < <(docker ps --format '{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.project.config_files"}}\t{{.Label "com.docker.compose.project.working_dir"}}' </dev/null \
           | awk -F'\t' '!seen[$1]++' | sort)

# Homelab convention: one compose file per /home/jeppe/<Project>. Stopped stacks
# get their images refreshed but are left stopped.
echo "== stopped stacks: refresh images only"
find /home/jeppe -maxdepth 3 \( -name docker-compose.yml -o -name docker-compose.yaml -o -name compose.yml -o -name compose.yaml \) 2>/dev/null \
  | grep -viE "$SKIP_RE" | xargs -rn1 dirname | sort -u | grep -vxFf <(printf '%s' "$wdone") \
  | while read -r d; do
      out=$(cd "$d" && docker compose pull --ignore-buildable </dev/null 2>&1)
      printf '%s\n' "$out" | grep -E 'Pulled|rror|denied|unauthorized|interpolat' | sed "s#^#       [$d] #" | tail -3
    done

echo
echo "SUMMARY  stacks updated=$updated  containers recreated=$recreated  stacks with pull errors=$pullerr"
echo "next: wait ~60s for healthchecks, then run verify.sh"
