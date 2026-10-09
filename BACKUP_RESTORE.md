# Backup dan pemulihan GlowBook

Panduan ini untuk satu server Linux dengan Docker Compose, PostgreSQL dan Active Storage lokal. Backup meliputi database aplikasi, database antrean dan file upload. Jika container Caddy tersedia, data sertifikat serta konfigurasi runtime Caddy ikut disalin. `.env.production`, Rails master key dan secret production harus disimpan terpisah di penyimpanan rahasia yang aman.

## Membuat backup

Prasyarat host: Bash, Docker Compose, `flock` (util-linux), GNU coreutils dan gzip. Stack harus mempunyai satu container web, satu worker dan database yang sedang berjalan. Script membaca file environment melalui Compose; file tersebut tidak dijalankan sebagai shell dan isinya tidak dicetak.

```bash
cd /opt/glowbook
sudo bash script/backup.sh /opt/glowbook/.env.production /var/backups/glowbook
```

Script memakai `compose.yaml` dan `compose.production.yaml` secara default. Untuk stack tanpa Caddy, tambahkan `compose.yaml` sebagai argumen ketiga. Jika project memakai nama Compose khusus, gunakan `COMPOSE_PROJECT_NAME` yang sama pada pemanggilan backup.

Web dan worker dihentikan sementara untuk mengambil kedua dump dan upload dari keadaan yang sama; pelanggan akan mendapat jeda layanan selama penyalinan. Layanan dinyalakan kembali sebelum verifikasi arsip. Waktu jeda bergantung pada ukuran data, sehingga jadwalkan saat sepi. Bila dump atau penyalinan gagal, trap mencoba menyalakan layanan kembali dan script keluar dengan status gagal. Script menolak stack yang sudah berhenti agar tidak menyalakan layanan yang sengaja dimatikan. Kegagalan pemulihan layanan harus segera ditangani operator.

Direktori backup baru dibuat dengan izin `0700` dan file memakai `0600`. Direktori yang sudah ada harus dimiliki pengguna pelaksana serta tidak dapat diakses grup/pengguna lain. Gunakan satu direktori tujuan untuk satu stack; lock mencegah dua backup bersamaan pada direktori tersebut.

Backup lengkap muncul sebagai direktori bertanggal UTC, berisi:

- `application.dump`: PostgreSQL custom dump aplikasi.
- `queue.dump`: PostgreSQL custom dump Solid Queue.
- `uploads.tar.gz`: isi volume Active Storage.
- `caddy-data.tar.gz` dan `caddy-config.tar.gz`: hanya jika container proxy tersedia. Data Caddy disalin saat proxy berjalan, terpisah dari snapshot aplikasi.
- `metadata.txt`: format, waktu dan commit source jika Git tersedia.
- `SHA256SUMS`: checksum seluruh berkas di atas.

Direktori `.incomplete-*` merupakan percobaan gagal dan tidak boleh dipakai sebagai backup lengkap. Script tidak menghapus backup sebelumnya. Tentukan retensi sesuai kapasitas dan kebutuhan pemulihan; periksa ruang disk dan kegagalan timer. Arsip berisi data pelanggan, hash kata sandi, token antrean dan private key sertifikat. Simpan salinan terenkripsi di luar server serta uji pemulihan berkala; arsip pada disk server yang sama belum melindungi dari hilangnya server. Jangan masukkan arsip atau secret ke GitHub.

## Menjadwalkan pada server

Unit contoh mengasumsikan checkout di `/opt/glowbook`, environment di `/opt/glowbook/.env.production`, dan backup di `/var/backups/glowbook`. Sesuaikan path sebelum memasang. Timer berjalan setiap hari sekitar **03:15 WIB** (20:15 UTC hari sebelumnya). `Persistent=true` mengejar jadwal yang terlewat ketika server/timer kembali aktif; jeda layanan dapat terjadi saat itu.

```bash
sudo install -m 0644 deploy/systemd/glowbook-backup.service /etc/systemd/system/glowbook-backup.service
sudo install -m 0644 deploy/systemd/glowbook-backup.timer /etc/systemd/system/glowbook-backup.timer
sudo systemd-analyze verify /etc/systemd/system/glowbook-backup.service /etc/systemd/system/glowbook-backup.timer
sudo systemctl daemon-reload
sudo systemctl start glowbook-backup.service
sudo journalctl -u glowbook-backup.service --no-pager -n 100
sudo systemctl enable --now glowbook-backup.timer
sudo systemctl list-timers glowbook-backup.timer
```

Periksa hasil backup manual pertama sebelum mengaktifkan timer. Status gagal dapat diperiksa dengan `systemctl --failed` dan journal service. Aktifkan pemantauan host atau kanal pemberitahuan operator yang tersedia pada server. Referensi: [systemd timer](https://github.com/systemd/systemd/blob/main/man/systemd.timer.xml).

## Percobaan restore pada stack terpisah

Gunakan backup milik sendiri yang checksum-nya valid, source/image sesuai `metadata.txt`, dan project Compose **glowbook-restore** dengan volume baru. Jangan jalankan langkah ini terhadap stack utama. Salin konfigurasi rahasia yang sesuai menjadi `.env.restore` secara aman, lalu atur:

```dotenv
APP_HOST=http://localhost:3004
GLOWBOOK_PORT=3004
RAILS_ASSUME_SSL=false
RAILS_FORCE_SSL=false
SMTP_ADDRESS=
SMTP_USERNAME=
SMTP_PASSWORD=
FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=
```

Pertahankan secret dan credentials yang dibutuhkan data backup. Pengiriman email sengaja dinonaktifkan pada stack pemulihan ini. Lanjutkan dari Bash:

```bash
set -euo pipefail
cd /opt/glowbook
BACKUP=/var/backups/glowbook/NAMA_DIREKTORI_BACKUP
(cd "$BACKUP" && sha256sum --check SHA256SUMS)
restore=(docker compose --project-name glowbook-restore --env-file .env.restore -f compose.yaml)
"${restore[@]}" up -d --wait db

# Target aplikasi harus kosong; createdb juga menolak antrean yang sudah ada.
table_count=$("${restore[@]}" exec -T db psql -X -At -U glowbook -d glowbook_production -c "SELECT count(*) FROM pg_tables WHERE schemaname='public'")
[[ "$table_count" == 0 ]] || { echo 'Target restore tidak kosong.' >&2; exit 1; }
"${restore[@]}" exec -T db createdb -U glowbook -T template0 glowbook_production_queue
"${restore[@]}" exec -T db pg_restore -U glowbook --no-owner --no-privileges --single-transaction --exit-on-error -d glowbook_production <"$BACKUP/application.dump"
"${restore[@]}" exec -T db pg_restore -U glowbook --no-owner --no-privileges --single-transaction --exit-on-error -d glowbook_production_queue <"$BACKUP/queue.dump"

"${restore[@]}" create web
web_restore_id=$("${restore[@]}" ps -a -q web)
gzip -dc "$BACKUP/uploads.tar.gz" | docker cp - "$web_restore_id:/rails/storage"
"${restore[@]}" run --rm --no-deps --user root --entrypoint /bin/sh web -c 'chown -R 1000:1000 /rails/storage'
"${restore[@]}" up -d --no-deps --wait web
"${restore[@]}" exec -T web ./bin/rails zeitwerk:check
```

Buka `http://localhost:3004`, cocokkan jumlah pengguna/booking, buka gambar galeri dan periksa log. Worker pemulihan tetap berhenti sampai antrean ditinjau: job lama dapat mengirim ulang email atau menjalankan efek yang sudah terjadi setelah waktu backup. Sebelum pemulihan menjadi production, sesuaikan domain, SMTP dan proxy, lalu tinjau antrean dan uji aplikasi pada host tujuan.

Untuk memulihkan arsip Caddy ke volume project restore tanpa menyalakan proxy:

```bash
restore_proxy=(docker compose --project-name glowbook-restore --env-file .env.restore -f compose.yaml -f compose.production.yaml)
"${restore_proxy[@]}" create proxy
proxy_restore_id=$("${restore_proxy[@]}" ps -a -q proxy)
gzip -dc "$BACKUP/caddy-data.tar.gz" | docker cp - "$proxy_restore_id:/data"
gzip -dc "$BACKUP/caddy-config.tar.gz" | docker cp - "$proxy_restore_id:/config"
```

Jalankan bagian Caddy hanya jika kedua arsip tersedia. Jangan menyalakan proxy restore bersamaan dengan proxy utama pada port 80/443. Penerbitan/renewal sertifikat publik tetap perlu diperiksa pada domain tujuan. Referensi format dan pemulihan: [PostgreSQL dump](https://www.postgresql.org/docs/16/backup-dump.html), [Docker cp](https://docs.docker.com/reference/cli/docker/container/cp/).

## Verifikasi otomatis workflow backup

Setelah image production `glowbook:ci` dibangun, jalankan `bash script/verify_backup.sh` pada Linux dengan Docker. Verifikasi membuat project khusus tanpa port host, memakai Rails dan PostgreSQL nyata, memulihkan kedua database ke database baru, serta mencocokkan byte upload. Kegagalan dump, lock, layanan yang sengaja berhenti dan checksum rusak juga diperiksa. Stack dan volume verifikasi dibersihkan setelah selesai. Ini membuktikan workflow lokal; pemasangan timer, salinan di luar server dan restore production tetap harus dibuktikan pada server tujuan.
