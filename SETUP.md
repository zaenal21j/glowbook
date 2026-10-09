# GlowBook — Panduan Setup di Komputer Baru

Repository ini berisi source aplikasi **GlowBook** (marketplace booking kecantikan Indonesia — Rails 8.1 + PostgreSQL + Hotwire + Tailwind). Dump database lokal dan file upload tidak disertakan di GitHub karena dapat berisi data pribadi. Database development dapat dibuat ulang dari seed demo.

## Isi paket

| Item | Keterangan |
|---|---|
| Source code aplikasi | Termasuk `config/credentials.yml.enc` yang terenkripsi; `config/master.key` dan `.env.production` tidak disertakan |
| `db/seeds.rb` | Seed data demo untuk database development |
| `storage/` | File upload lokal; tidak disertakan di repository |
| `SETUP.md` | File ini |

## Prasyarat

> **Penting:** Jalankan di **Linux (Ubuntu 22.04+ / WSL2)** atau **macOS**. Rails di Windows native tidak disarankan — di Windows gunakan WSL2.

- Ruby **3.4.7** (lihat `.ruby-version`) — disarankan via rbenv
- PostgreSQL **14+**
- Build tools: `build-essential`, `libpq-dev`, `libyaml-dev`, `git`

Contoh instalasi di Ubuntu:

```bash
sudo apt update
sudo apt install -y build-essential libpq-dev libyaml-dev git curl libssl-dev zlib1g-dev

# rbenv + Ruby 3.4.7
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
exec $SHELL
rbenv install 3.4.7
rbenv global 3.4.7
```

## Langkah setup

```bash
cd glowbook
bundle install

# 1) Buat role & database PostgreSQL
sudo -u postgres psql -c "CREATE ROLE glowbook LOGIN PASSWORD 'glowbook';"
sudo -u postgres createdb -O glowbook glowbook_development

# Buat skema development dan data demo
bin/rails db:prepare
```

Jika Anda memiliki dump database pribadi dari komputer lama, simpan di luar repository, restore secara terpisah, lalu jalankan `bin/rails db:migrate`.

> Kalau `psql` meminta password, ketik `glowbook` (sesuai `config/database.yml`).

## Menjalankan

```bash
bin/rails server        # buka http://localhost:3000
# atau dengan watcher Tailwind:
bin/dev
```

Port bentrok? `bin/rails server -p 3001`

## Akun demo (password semua: `password123`)

| Email | Peran | Dashboard |
|---|---|---|
| `admin@glowbook.id` | Admin | `/admin` |
| `owner1@glowbook.id` | Pemilik bisnis | `/bisnis` |
| `sari@example.com` | Customer | `/akun` |

## Opsional: Login Facebook

Set environment variable sebelum menjalankan server (dipakai `config/initializers/devise.rb`):

```bash
export FACEBOOK_APP_ID="..."
export FACEBOOK_APP_SECRET="..."
```

Tanpa env var ini, tombol "Lanjut dengan Facebook" otomatis disembunyikan — aplikasi tetap jalan normal dengan login email/password.

## Email booking dan keamanan akun

GlowBook mengirim email konfirmasi ke pelanggan dan pemilik bisnis saat booking dibuat, lalu email pembatalan/perubahan jadwal saat booking diperbarui. Peristiwa yang sama juga muncul di halaman **Notifikasi** untuk pelanggan dan pemilik bisnis; notifikasi dapat ditandai dibaca satu per satu atau sekaligus. Pada development, email disimpan sebagai file di `tmp/mail/`. Untuk production, atur SMTP berikut (contoh di bawah untuk server SMTP dengan STARTTLS):

```bash
export APP_HOST="https://domain-anda.id"
export MAILER_FROM="notifikasi@domain-anda.id"
export SMTP_ADDRESS="smtp.domain-anda.id"
export SMTP_PORT="587"
export SMTP_USERNAME="..."
export SMTP_PASSWORD="..."
```

Production menonaktifkan pengiriman jika `SMTP_ADDRESS` belum diisi. Email booking, reset kata sandi, pemberitahuan perubahan kata sandi dan perubahan email disimpan di antrean PostgreSQL Solid Queue, diproses oleh service `worker`, dan dicoba ulang sampai lima kali untuk gangguan SMTP sementara. Server web menyiapkan kedua database sebelum aktif; service worker menunggu web sehat agar skema antrean sudah siap. Development tetap memakai adapter lokal yang ada.

Pengguna yang sudah masuk dapat mengganti kata sandi dari Pengaturan → Ubah kata sandi, termasuk dari pengaturan admin dan bisnis. Kata sandi saat ini wajib diisi; sesi browser yang melakukan perubahan tetap aktif. Mengganti email login dari Profil juga memerlukan kata sandi saat ini dan mengirim pemberitahuan ke alamat email lama. Nama dan nomor telepon dapat diperbarui tanpa mengganti kata sandi.

Pengguna yang lupa kata sandi dapat membuka `/users/password/new` dari halaman masuk. Respons permintaan reset sama untuk email terdaftar maupun tidak terdaftar. Tautan reset berlaku enam jam dan hanya dapat digunakan sekali. Bahasa email mengikuti bahasa saat permintaan dibuat. Argumen job email tidak dicatat ke log agar token reset tidak ikut tercetak. Pengiriman ke kotak masuk nyata tetap memerlukan konfigurasi SMTP dan worker yang berjalan.

## Menjalankan image production dengan Docker Compose

Project menyertakan Dockerfile untuk image Rails production dan Compose untuk satu host. Data PostgreSQL dan upload galeri disimpan pada named volume Docker agar bertahan ketika container dibuat ulang.

1. Salin `.env.production.example` menjadi `.env.production`, lalu ganti semua nilai contoh. Buat `SECRET_KEY_BASE` dengan `bin/rails secret`, gunakan kata sandi database yang kuat, isi `APP_HOST` dengan URL HTTPS publik, dan isi konfigurasi SMTP. Jangan gunakan `config/master.key` development untuk production. Jika Anda memakai Rails encrypted credentials, isi `RAILS_MASTER_KEY` dengan key production.
2. Jalankan `docker compose --env-file .env.production config --quiet` untuk memeriksa konfigurasi Compose.
3. Jalankan `docker compose --env-file .env.production up --build -d`. Container web menunggu PostgreSQL sehat, menyiapkan database aplikasi dan antrean sebelum server mulai, lalu menyediakan health check di `/up`. Container `worker` mulai setelah web sehat dan memproses email booking.

Port host default adalah `127.0.0.1:3001`; letakkan reverse proxy HTTPS di depannya dan teruskan header protokol HTTPS. Jangan membuka port container langsung ke internet. Atur `GLOWBOOK_PORT` di `.env.production` jika reverse proxy memakai port host lain. Pengaturan `RAILS_ASSUME_SSL` dan `RAILS_FORCE_SSL` bernilai `true` secara default. Untuk Compose lokal yang sengaja dibuka lewat HTTP, isi keduanya `false` dan atur `APP_HOST=http://localhost`; jangan gunakan pengaturan HTTP tersebut di server publik.

Volume `postgres_data` dan `storage_data` tetap ada setelah `docker compose down`. Jangan menambahkan `-v` ketika menghentikan layanan kecuali memang ingin menghapus database dan file galeri. Database antrean terpisah dari data aplikasi; cadangkan keduanya: `docker compose --env-file .env.production exec -T db pg_dump -U glowbook glowbook_production > glowbook-backup.sql` dan `docker compose --env-file .env.production exec -T db pg_dump -U glowbook glowbook_production_queue > glowbook-queue-backup.sql`.

### Penyiapan pertama tanpa akun demo

Database production baru tidak otomatis menjalankan seed demo. Setelah stack sehat, buat admin awal dan data referensi kota/kategori dengan perintah berikut dari shell Linux/WSL:

```bash
read -r -p "Email admin: " ADMIN_EMAIL
read -r -s -p "Password admin (minimal 12 karakter): " ADMIN_PASSWORD
echo
export ADMIN_EMAIL ADMIN_PASSWORD
docker compose --env-file .env.production exec -T -e ADMIN_EMAIL -e ADMIN_PASSWORD web ./bin/rails glowbook:bootstrap
unset ADMIN_EMAIL ADMIN_PASSWORD
```

Password tidak ditampilkan atau dimasukkan langsung ke riwayat shell. Task ini aman dijalankan ulang: data yang sudah ada, nama kota/kategori yang sudah disesuaikan, serta password admin tetap dipertahankan. Task menolak menaikkan peran akun customer yang kebetulan memiliki email sama. Login admin melalui `/masuk`, kemudian buka `/admin`. Pemilik bisnis mendaftar dari `/daftar-bisnis` dan menunggu persetujuan admin. Jangan menjalankan `db:seed` untuk production; seed demo hanya diizinkan pada development dan menghapus data development sebelumnya.

Konfigurasi ini untuk satu host dengan satu container web dan satu worker. Sebelum menambah instance, siapkan object storage untuk upload galeri dan sesuaikan kapasitas worker. Deploy production belum dijalankan.

## Pendaftaran bisnis

Pengguna dengan akun customer dapat mendaftarkan satu bisnis melalui `/daftar-bisnis`. Bisnis baru berstatus menunggu verifikasi; pemilik dapat melengkapi profil, layanan, staff, dan galeri dari dashboard. Admin menyetujui bisnis dari menu Admin → Bisnis. Jam awal otomatis Senin–Sabtu 09.00–17.00 dan Minggu tutup.

Admin dapat menutup sementara pendaftaran baru dari menu Admin → Pengaturan. Menu Bisnis juga menyediakan aktivasi kembali untuk bisnis yang sebelumnya ditangguhkan. Tarif komisi di halaman pengaturan hanya menyimpan nilai rencana; nilai tersebut belum dipotong dari booking dan belum menjadi settlement.

Admin dapat memperbarui status booking dari halaman detail menggunakan aturan status yang sama seperti dashboard bisnis. Pembatalan tetap ditolak jika pembayaran sedang berjalan atau sudah berhasil; refund belum tersedia. Laporan bulanan dapat diunduh sebagai CSV untuk rekonsiliasi manual.

## Chat customer dan bisnis

Customer dapat memulai percakapan dari halaman bisnis. Pemilik serta staff aktif bisnis dapat membalas melalui menu Pesan. Isi pesan tersimpan di database dan halaman mengambil pesan baru setiap 4 detik; fitur ini tidak memerlukan layanan WebSocket tambahan.

## Opsional: Pembayaran Midtrans Sandbox

Pembayaran online memakai Snap hosted checkout dan **selalu menunjuk ke endpoint Sandbox**. Isi Server Key sandbox dari Midtrans sebelum menyalakan aplikasi:

```bash
export MIDTRANS_SERVER_KEY="SB-Mid-server-..."
export APP_HOST="https://<host-anda>"
```

`APP_HOST` dipakai untuk mengarahkan pelanggan kembali ke detail booking setelah checkout Snap. Setelah aplikasi dapat diakses melalui URL publik HTTPS (atau tunnel lokal), atur `Payment Notification URL` di Midtrans MAP ke `https://<host-anda>/midtrans/notifications`. Endpoint akan memverifikasi signature dan mencocokkan status terbaru, nominal, mata uang, serta order ID sebelum menyimpan status pembayaran. Booking online yang pembayarannya masih berjalan atau sudah lunas tidak bisa dibatalkan/diubah jadwal sampai status pembayaran terminal; alur refund belum tersedia. Jangan gunakan Server Key produksi untuk menjalankan integrasi sandbox.

## Catatan keamanan

- `config/master.key` dan `.env.production` tidak disimpan di GitHub. `config/credentials.yml.enc` adalah file terenkripsi; key yang cocok harus disimpan secara terpisah jika nilainya diperlukan.
- Untuk production, buat credentials dan master key baru: `rm config/credentials.yml.enc && bin/rails credentials:edit`. Simpan master key di secret manager atau konfigurasi deployment, jangan commit ke repository.
- Upload galeri saat ini memakai Active Storage lokal (`storage/`). Docker Compose membagikan volume penyimpanan yang sama ke web dan worker agar analisis gambar latar dapat membaca berkas unggahan. Untuk deployment production dengan disk sementara atau beberapa instance web, konfigurasi object storage persisten sebelum menerima upload bisnis.
