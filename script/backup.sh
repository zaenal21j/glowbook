#!/usr/bin/env bash
# Linux host utility. Never source the environment file or print its contents.
set -Eeuo pipefail
umask 077

if (( $# < 2 )); then
  echo "Usage: bash script/backup.sh ENV_FILE ABSOLUTE_BACKUP_DIRECTORY [COMPOSE_FILE ...]" >&2
  exit 64
fi

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$project_root"
env_file=$(realpath -e -- "$1")
backup_dir=$2
shift 2
[[ "$backup_dir" == /* && "$backup_dir" != / ]] || { echo "Use an absolute backup directory other than /." >&2; exit 64; }
[[ -f "$env_file" ]] || { echo "Environment file not found." >&2; exit 64; }
for utility in docker flock gzip sha256sum stat; do
  command -v "$utility" >/dev/null || { echo "Required utility missing: $utility" >&2; exit 69; }
done

compose=(docker compose --env-file "$env_file" --project-directory "$project_root")
if (( $# == 0 )); then set -- compose.yaml compose.production.yaml; fi
for compose_file in "$@"; do compose+=(-f "$(realpath -e -- "$compose_file")"); done
"${compose[@]}" config --quiet

mkdir -p -m 700 -- "$backup_dir"
backup_dir=$(realpath -e -- "$backup_dir")
permissions=$(stat -c '%a' -- "$backup_dir")
if [[ ! -O "$backup_dir" ]] || (( (8#$permissions & 077) != 0 )); then
  echo "Backup directory must belong to the current user and have permissions 0700." >&2
  exit 77
fi
exec 9>"$backup_dir/.backup.lock"
flock -n 9 || { echo "Another backup is already running." >&2; exit 73; }

running=$("${compose[@]}" ps --status running --services)
for service in db web worker; do
  [[ $'\n'"$running"$'\n' == *$'\n'"$service"$'\n'* ]] || { echo "Service $service must be running before backup." >&2; exit 69; }
done
web_id=$("${compose[@]}" ps -q web)
[[ -n "$web_id" && "$web_id" != *$'\n'* ]] || { echo "Backup supports one web container." >&2; exit 69; }
proxy_id=$("${compose[@]}" ps -a -q proxy 2>/dev/null || true)

restart_required=0
staging=""
restart_services() {
  "${compose[@]}" start --wait --wait-timeout 120 web worker
}
cleanup() {
  result=$?
  trap - EXIT
  if (( restart_required )); then
    if ! restart_services; then
      echo "ERROR: web/worker recovery failed; inspect the stack immediately." >&2
      result=1
    fi
  fi
  if (( result != 0 )) && [[ -n "$staging" ]]; then
    echo "Backup failed. Incomplete files retained at $staging; no completed backup was published." >&2
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

staging=$(mktemp -d "$backup_dir/.incomplete-XXXXXXXX")
created_at=$(date -u +%Y%m%dT%H%M%SZ)
restart_required=1
"${compose[@]}" stop --timeout 60 worker web
"${compose[@]}" exec -T db pg_dump -U glowbook -Fc --no-owner --no-privileges glowbook_production >"$staging/application.dump"
"${compose[@]}" exec -T db pg_dump -U glowbook -Fc --no-owner --no-privileges glowbook_production_queue >"$staging/queue.dump"
docker cp "$web_id:/rails/storage/." - | gzip -c >"$staging/uploads.tar.gz"
restart_services
restart_required=0

archives=(application.dump queue.dump uploads.tar.gz metadata.txt)
if [[ -n "$proxy_id" && "$proxy_id" != *$'\n'* ]]; then
  docker cp "$proxy_id:/data/." - | gzip -c >"$staging/caddy-data.tar.gz"
  docker cp "$proxy_id:/config/." - | gzip -c >"$staging/caddy-config.tar.gz"
  archives+=(caddy-data.tar.gz caddy-config.tar.gz)
fi
"${compose[@]}" exec -T db pg_restore --list <"$staging/application.dump" >/dev/null
"${compose[@]}" exec -T db pg_restore --list <"$staging/queue.dump" >/dev/null
gzip -t "$staging/uploads.tar.gz"
commit=$(git rev-parse HEAD 2>/dev/null || printf 'unknown')
printf 'format=1\ncreated_at_utc=%s\ngit_commit=%s\ndatabases=glowbook_production,glowbook_production_queue\nuploads=local_active_storage\ncaddy_snapshot=live_if_present\n' "$created_at" "$commit" >"$staging/metadata.txt"
(cd -- "$staging" && sha256sum -- "${archives[@]}" >SHA256SUMS && sha256sum --check SHA256SUMS)
completed="$backup_dir/$created_at-${staging##*.incomplete-}"
mv -- "$staging" "$completed"
staging=""
echo "Backup completed: $completed"
