#!/usr/bin/env bash
# Destructive only inside the fixed, disposable verification Compose project.
set -Eeuo pipefail
umask 077
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$project_root"
export COMPOSE_PROJECT_NAME=glowbook-backup-verification
fixture="$project_root/spec/fixtures/backup/compose.yaml"
test_dir=$(mktemp -d /tmp/glowbook-backup-test.XXXXXXXX)
env_file="$test_dir/verification.env"
printf '# Disposable verification stack; credentials are fixtures.\n' >"$env_file"
compose=(docker compose --env-file "$env_file" --project-directory "$project_root" -f "$fixture")
if [[ -n $(docker ps -aq --filter label=com.docker.compose.project=glowbook-backup-verification) ]]; then
  echo "An existing backup verification stack must be inspected before another run." >&2
  exit 69
fi
files_container=""
cleanup() {
  result=$?
  trap - EXIT
  [[ -z "$files_container" ]] || docker rm -f "$files_container" >/dev/null
  "${compose[@]}" down --remove-orphans --volumes >/dev/null
  [[ "$test_dir" == /tmp/glowbook-backup-test.* ]] && rm -rf -- "$test_dir"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

"${compose[@]}" up -d --wait --wait-timeout 180
"${compose[@]}" exec -T web ./bin/rails runner - <spec/fixtures/backup/seed.rb
blob_key=$("${compose[@]}" exec -T web cat /rails/tmp/backup-fixture-key)
"${compose[@]}" exec -T db psql -X -v ON_ERROR_STOP=1 -U glowbook -d glowbook_production_queue -c "CREATE TABLE backup_marker (value text); INSERT INTO backup_marker VALUES ('queue-data-restored');" >/dev/null
bash script/backup.sh "$env_file" "$test_dir/backups" "$fixture"
mapfile -t completed < <(find "$test_dir/backups" -mindepth 1 -maxdepth 1 -type d ! -name '.*')
[[ ${#completed[@]} == 1 ]]
backup=${completed[0]}
(cd -- "$backup" && sha256sum --check SHA256SUMS)

for database in glowbook_restore_application glowbook_restore_queue; do
  "${compose[@]}" exec -T db createdb -U glowbook -T template0 "$database"
done
"${compose[@]}" exec -T db pg_restore -U glowbook --no-owner --no-privileges --single-transaction --exit-on-error -d glowbook_restore_application <"$backup/application.dump"
"${compose[@]}" exec -T db pg_restore -U glowbook --no-owner --no-privileges --single-transaction --exit-on-error -d glowbook_restore_queue <"$backup/queue.dump"
[[ $("${compose[@]}" exec -T db psql -X -At -U glowbook -d glowbook_restore_application -c 'SELECT count(*) FROM users') == 1 ]]
[[ $("${compose[@]}" exec -T db psql -X -At -U glowbook -d glowbook_restore_application -c 'SELECT key FROM active_storage_blobs') == "$blob_key" ]]
[[ $("${compose[@]}" exec -T db psql -X -At -U glowbook -d glowbook_restore_queue -c 'SELECT value FROM backup_marker') == queue-data-restored ]]

files_container=$(docker run -d --init caddy:2.11.7-alpine sh -c 'mkdir -p /restore; exec sleep infinity')
gzip -dc "$backup/uploads.tar.gz" | docker cp - "$files_container:/restore"
relative_blob="${blob_key:0:2}/${blob_key:2:2}/$blob_key"
source_hash=$("${compose[@]}" exec -T web sha256sum "/rails/storage/$relative_blob" | cut -d ' ' -f 1)
restored_hash=$(docker exec "$files_container" sha256sum "/restore/$relative_blob" | cut -d ' ' -f 1)
[[ "$source_hash" == "$restored_hash" ]]
[[ $(tar -xzOf "$backup/caddy-data.tar.gz" ./backup-marker) == certificate-fixture ]]
[[ $(tar -xzOf "$backup/caddy-config.tar.gz" ./backup-marker) == config-fixture ]]

# Inject one failed queue dump into this invocation, then prove EXIT recovery.
docker_binary=$(command -v docker)
mkdir "$test_dir/failing-cli"
printf '#!/usr/bin/env bash\nif [[ "$*" == *pg_dump*glowbook_production_queue* ]]; then exit 42; fi\nexec %q "$@"\n' "$docker_binary" >"$test_dir/failing-cli/docker"
chmod +x "$test_dir/failing-cli/docker"
if PATH="$test_dir/failing-cli:$PATH" bash script/backup.sh "$env_file" "$test_dir/backups" "$fixture" >"$test_dir/failure.log" 2>&1; then
  echo "Injected dump failure was incorrectly accepted." >&2
  exit 1
else
  [[ $? == 42 ]]
fi
[[ $(docker inspect --format '{{.State.Health.Status}}' "$("${compose[@]}" ps -q web)") == healthy ]]
[[ $("${compose[@]}" ps --status running --services | sort | tr '\n' ' ') == 'db proxy web worker ' ]]
[[ $(find "$test_dir/backups" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | wc -l) == 1 ]]

exec 8>"$test_dir/backups/.backup.lock"
flock -n 8
if bash script/backup.sh "$env_file" "$test_dir/backups" "$fixture" >"$test_dir/lock.log" 2>&1; then exit 1; else [[ $? == 73 ]]; fi
flock -u 8
exec 8>&-

"${compose[@]}" stop --timeout 30 worker >/dev/null
if bash script/backup.sh "$env_file" "$test_dir/backups" "$fixture" >"$test_dir/stopped.log" 2>&1; then exit 1; else [[ $? == 69 ]]; fi
[[ -z $("${compose[@]}" ps --status running -q worker) ]]
"${compose[@]}" start --wait --wait-timeout 120 worker >/dev/null

mkdir "$test_dir/corrupt-copy"
cp "$backup/queue.dump" "$test_dir/corrupt-copy/queue.dump"
grep 'queue.dump$' "$backup/SHA256SUMS" >"$test_dir/corrupt-copy/SHA256SUMS"
printf 'corruption' >>"$test_dir/corrupt-copy/queue.dump"
if (cd "$test_dir/corrupt-copy" && sha256sum --check SHA256SUMS) >/dev/null 2>&1; then exit 1; fi
echo 'Backup verification passed: application DB, queue DB, upload bytes, Caddy data, checksums, failure recovery, lock, stopped-service guard, corruption detection.'
