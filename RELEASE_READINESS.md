# Status kesiapan GlowBook

Audit lokal: 10 Oktober 2026 (Asia/Bangkok). Status ini mencatat bukti yang sudah diperiksa, bukan klaim bahwa aplikasi sudah 100% siap production.

## Fitur dan bukti

| Area | Kondisi saat audit | Bukti |
| --- | --- | --- |
| Marketplace | Homepage termasuk database kosong, filter kota/kategori/rating/promo/jam buka/harga, urutan terdekat dan pagination diperiksa | `spec/requests/marketplace_spec.rb`; endpoint lokal `/` dan `/cari?open_today=1` memberi 200 |
| Akun | Daftar, login, peran, pembatasan penghapusan akun bersejarah, ubah kata sandi saat login, reset sekali pakai dan proteksi perubahan email diperiksa | Request specs akun/admin/OAuth; 11 account security examples; email reset/perubahan akun melalui test adapter; SMTP nyata tetap belum dibuktikan |
| Booking | Alur lima langkah, rangkaian layanan, kualifikasi staff, bentrok, pembatalan dan reschedule diperiksa | Booking flow/schedule/builder/availability specs; constraint PostgreSQL tetap aktif |
| Dashboard bisnis | Jam buka, shift, istirahat, blokir waktu, layanan, staff dan profil diperiksa | `business_scheduling_spec.rb`; halaman profil, staff dan blokir waktu lokal memberi 200 |
| Onboarding | Customer membuat bisnis pending dan mengelolanya; publikasi memerlukan persetujuan admin | `customer_business_workflows_spec.rb` |
| Galeri | Upload, tampil publik, validasi gambar, hapus dan pembatasan antar bisnis diperiksa | Request specs galeri; halaman galeri lokal memberi 200 |
| Chat dan notifikasi | Pertukaran pesan, status dibaca, pembatasan peserta, notifikasi dan tiga jenis email booking diperiksa | Request specs; enam email terkirim melalui test adapter. Pengiriman SMTP nyata belum dibuktikan |
| Admin | Seluruh bagian utama merender dalam dua bahasa; persetujuan, suspend/reactivate, kategori, pengaturan dan proteksi akun diperiksa | `admin_workflows_spec.rb`; sepuluh halaman admin lokal memberi 200; menu admin dan bisnis dibuka pada viewport ponsel 390 × 844 |
| Bahasa | Indonesia dan Inggris untuk UI utama, pesan booking dan email keamanan akun | 894 key literal tersedia pada kedua locale; key dinamis juga dicakup sebagian request specs |
| PWA | Manifest, worker, cache aset statis dan fallback offline tersedia | Tujuh pengujian service worker lulus; endpoint nyata memberi 200; browser menampilkan fallback setelah instance sementara port 3002 dihentikan. Instalasi pada perangkat pengguna belum diperiksa |
| Instalasi baru | Task `glowbook:bootstrap` membuat kota/kategori/admin tanpa akun demo; aman diulang | Empat service specs; seed demo ditolak di production |
| HTTPS | Overlay Compose dan konfigurasi Caddy untuk server publik tersedia | Compose dan `caddy validate` lulus dengan domain contoh; proxy HTTP sementara pada loopback meneruskan homepage dan `/up` dengan status 200. DNS, sertifikat publik dan akses server tujuan belum dibuktikan |

## Verifikasi lokal yang selesai

- RSpec: **147 examples, 0 failures**, seed `61082`.
- Node service worker: **7 passed, 0 failed**.
- `script/check_release.rb`: 93 file Ruby, 99 template ERB, 894 key terjemahan dan 157 pasangan controller/action lolos.
- `rails zeitwerk:check`: eager loading berhasil.
- Brakeman: **0 errors, 0 security warnings**.
- Dependency pengujian dapat dipasang dengan lockfile frozen melalui `bundle install --local`.
- Image production web dan worker berhasil dibangun dan dijalankan pada `http://localhost:3000`; kolom staff bio tersedia dan tidak ada migrasi tertunda.
- Cadangan database lokal dibuat sebelum penerapan pada `tmp/local_backups/`; folder tersebut tidak termasuk GitHub.
- CI GitHub commit `055eded` lulus seluruh tahap, termasuk build image verifikasi dari database kosong dan build production: [hasil run](https://github.com/zaenal21j/glowbook/actions/runs/37965763346). Perubahan keamanan akun sesudah commit tersebut tetap harus melewati CI.
- Pemeriksaan tambahan menu ponsel: 32 request examples admin/jadwal bisnis lulus; navigasi menu juga diperiksa di browser.

Pengujian Rails menggunakan PostgreSQL terpisah dari database aplikasi lokal. Hasil ini tidak membuktikan kapasitas beban production atau pengiriman email ke penyedia SMTP.

## Gate sebelum publikasi

1. CI GitHub harus lulus untuk commit yang akan dipublikasikan: [GlowBook Actions](https://github.com/zaenal21j/glowbook/actions).
2. Sediakan domain dan server, arahkan DNS, jalankan reverse proxy HTTPS (overlay `compose.production.yaml` tersedia), lalu jalankan stack dengan secret production baru. Lihat `SETUP.md`.
3. Jalankan bootstrap admin awal, uji onboarding/approval/booking pada host publik, dan periksa persistensi upload setelah restart.
4. Isi SMTP; buktikan penerimaan email konfirmasi, pembatalan, reschedule dan reset password melalui worker production.
5. Pasang jadwal backup database aplikasi, database antrean dan file upload; lakukan percobaan restore pada database terpisah. Cadangan lokal satu kali belum menggantikan proses ini.
6. Periksa instalasi PWA dan fallback offline pada perangkat/browser yang dipakai pelanggan.
7. Jika Facebook akan diaktifkan untuk publik, selesaikan konfigurasi domain/callback serta review aplikasi Meta. Mock OAuth lokal tidak membuktikan persetujuan Meta.

## Tahap pembayaran terakhir

Midtrans sandbox tetap dipertahankan. Migrasi ke Duitku menunggu arahan pemilik project setelah gate non-pembayaran selesai. Refund, payout/settlement dan pemotongan komisi otomatis belum tersedia. Nilai booking selesai di laporan tidak boleh dianggap sebagai dana yang sudah diterima; riwayat pembayaran online menampilkan status payment attempt yang tercatat.

WhatsApp belum menjadi kanal notifikasi. Notifikasi yang tersedia adalah email dan in-app. Chat memakai polling empat detik, sesuai implementasi saat ini.
