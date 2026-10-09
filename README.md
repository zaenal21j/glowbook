# GlowBook

GlowBook adalah marketplace kecantikan dan wellness untuk mencari bisnis, melihat layanan, lalu memesan jadwal secara online. Aplikasi menggunakan Rails 8.1, PostgreSQL, Hotwire, dan Tailwind CSS; antarmuka utamanya berbahasa Indonesia.

## Fitur utama

- Pencarian bisnis berdasarkan kota, kategori, layanan, dan harga.
- Login email, Google, dan Facebook; pengaturan OAuth serta SMTP melalui Admin → Integrasi dengan secret terenkripsi.
- Booking dengan pemeriksaan ketersediaan jadwal agar slot tidak dipesan ganda.
- Dashboard pelanggan dan pemilik bisnis, termasuk layanan, staff, booking, promosi, dan galeri.
- Pengaturan jam operasional, beberapa shift staff per hari, istirahat mingguan, dan blokir waktu untuk staff atau seluruh bisnis.
- Pilihan bahasa Indonesia/Inggris untuk halaman publik, akun, dashboard, admin, dan pesan booking.
- Pendaftaran bisnis yang menunggu verifikasi admin.
- Chat pelanggan dan bisnis, email booking melalui antrean, serta notifikasi in-app.
- Dashboard admin untuk mengelola pengguna, bisnis, booking, kategori, ulasan, promosi, dan laporan bulanan yang dapat diunduh sebagai CSV.
- Navigasi publik pada desktop dan ponsel, termasuk menu layanan, kota, dan akun.
- Service worker PWA untuk aset statis dan halaman fallback saat offline, dengan ikon GlowBook serta manifest sesuai bahasa pengguna.

## Menjalankan secara lokal

Ikuti [panduan setup lengkap](SETUP.md) untuk memasang Ruby dan PostgreSQL, memulihkan atau membuat database, serta menyiapkan akun demo. Ringkasnya:

```bash
bundle install
bin/rails db:prepare
bin/dev
```

Buka [http://localhost:3000](http://localhost:3000). Akun demo dan konfigurasi email dijelaskan di `SETUP.md`.

## Docker

Project menyertakan Dockerfile dan Compose untuk menjalankan image production satu host, termasuk database PostgreSQL dan worker Solid Queue. Ikuti bagian Docker di [SETUP.md](SETUP.md) dan ganti nilai contoh pada `.env.production.example` sebelum menjalankan stack.

## Menjalankan test suite

```bash
bundle exec rspec
```

Pengujian juga dapat dijalankan melalui Docker dengan database sementara yang terpisah dari stack lokal:

```bash
docker compose -f compose.test.yaml up --build --abort-on-container-exit --exit-code-from tests
docker compose -f compose.test.yaml down --remove-orphans
```

Pengujian navigasi, cache service worker dan bahasa halaman offline menggunakan Node.js:

```bash
node --test spec/javascript/*_test.cjs
```

GitHub Actions menjalankan suite Rails, pengujian navigasi dan service worker, pemeriksaan route/template/terjemahan serta registrasi controller Stimulus, pemindaian Brakeman, build image production, validasi proxy HTTPS, serta verifikasi backup/restore pada stack terpisah untuk push ke `main`, cabang `codex/**`, serta pull request. Workflow tidak menggunakan secret production dan tidak melakukan deployment. Panduan pencadangan dan jadwal server ada di [BACKUP_RESTORE.md](BACKUP_RESTORE.md).

Ikon PNG PWA dibuat dari `public/icon.svg`. Setelah mengubah vektor tersebut, jalankan `bundle exec ruby script/render_pwa_icons.rb` untuk memperbarui ukuran 192 dan 512 piksel.

## Catatan kesiapan production

Image Docker dan startup container sudah dapat diverifikasi secara lokal. Deploy publik tetap memerlukan domain HTTPS, secret production, email SMTP, backup database, dan pemeriksaan operasional. Settlement/komisi otomatis termasuk tahap keuangan yang belum selesai. Implementasi Midtrans dipertahankan selama fitur non-pembayaran diselesaikan; migrasi ke Duitku dilakukan pada tahap pembayaran terakhir sesuai arahan pemilik project.
