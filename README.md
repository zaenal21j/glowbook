# GlowBook

GlowBook adalah marketplace kecantikan dan wellness untuk mencari bisnis, melihat layanan, lalu memesan jadwal secara online. Aplikasi menggunakan Rails 8.1, PostgreSQL, Hotwire, dan Tailwind CSS; antarmuka utamanya berbahasa Indonesia.

## Fitur utama

- Pencarian bisnis berdasarkan kota, kategori, layanan, dan harga.
- Booking dengan pemeriksaan ketersediaan jadwal agar slot tidak dipesan ganda.
- Dashboard pelanggan dan pemilik bisnis, termasuk layanan, staff, booking, promosi, dan galeri.
- Pendaftaran bisnis yang menunggu verifikasi admin.
- Chat pelanggan dan bisnis, email booking melalui antrean, serta notifikasi in-app.
- Dashboard admin untuk mengelola pengguna, bisnis, booking, kategori, ulasan, promosi, dan laporan bulanan yang dapat diunduh sebagai CSV.
- Service worker PWA untuk aset statis dan halaman fallback saat offline.

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

## Catatan kesiapan production

Image Docker dan startup container sudah dapat diverifikasi secara lokal. Deploy publik tetap memerlukan domain HTTPS, secret production, email SMTP, backup database, dan pemeriksaan operasional. Settlement/komisi otomatis bergantung pada penyelesaian serta verifikasi integrasi pembayaran; Midtrans tetap menjadi tahap terakhir.
