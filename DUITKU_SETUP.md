# Konfigurasi payment gateway Duitku

## Yang perlu disiapkan

1. Akun merchant dan project **Duitku POP** pada portal Duitku.
2. **Merchant Code** dan **API Key sandbox** untuk project tersebut. Masukkan langsung ke formulir Admin, jangan simpan key asli di GitHub atau dokumen ini.
3. Host publik HTTPS yang mengarah ke aplikasi untuk pengujian callback nyata. `http://localhost:3000` dapat dipakai untuk melihat UI dan pengujian otomatis lokal, tetapi server Duitku tidak dapat mengakses localhost Anda.
4. Untuk pembayaran nyata: project/kredensial production serta persetujuan merchant dan kanal pembayaran dari Duitku. Menyimpan konfigurasi di aplikasi tidak menyelesaikan persetujuan penyedia.

## Pengaturan Admin

Buka `/admin/integrasi#duitku_heading` dengan akun admin.

| Field | Nilai awal / pengisian |
| --- | --- |
| Aktifkan integrasi | Nonaktif hingga kredensial tersedia |
| Merchant Code | Kode project dari Duitku |
| API Key | Key sesuai project dan mode; disimpan terenkripsi |
| Mode | Sandbox untuk uji coba; production untuk transaksi nyata |
| Masa berlaku invoice | 60 menit; rentang aplikasi 1–1440 menit |
| Callback URL | Ditampilkan dari `APP_HOST`, misalnya `https://glowbook.example.id/duitku/callback` |

Kolom API Key tidak pernah menampilkan kembali secret. Kosongkan saat mengedit untuk mempertahankannya; isi untuk menggantinya. Pertahankan `SECRET_KEY_BASE` yang sama saat restore/redeploy untuk membaca secret terenkripsi dari database.

Admin menolak penggantian Merchant Code/API Key/mode jika masih ada invoice Duitku pending. Periksa status transaksi tersebut terlebih dahulu. Menonaktifkan integrasi menghentikan checkout baru, tetapi callback dan pemeriksaan status tetap bekerja dengan key lama. Jangan hapus key untuk transaksi yang belum selesai.

Alternatif konfigurasi server (pengaturan tersimpan di Admin mengesampingkan environment):

```dotenv
DUITKU_ENABLED=false
DUITKU_ENVIRONMENT=sandbox
DUITKU_MERCHANT_CODE=
DUITKU_API_KEY=
DUITKU_EXPIRY_MINUTES=60
```

## Alur dan pemeriksaan keamanan

- Server membuat invoice POP; customer diarahkan ke `paymentUrl` Duitku yang telah diperiksa host HTTPS-nya. Kartu/VA/QRIS dipilih pada halaman Duitku sesuai kanal project yang tersedia.
- Create invoice menggunakan header signature HMAC SHA256 dari Merchant Code dan timestamp milidetik. API Key tidak dikirim sebagai plaintext pada payload atau URL.
- Callback memakai HMAC SHA256 dari Merchant Code, amount dan merchantOrderId. Signature dibandingkan dengan constant-time comparison; merchant, mode, order, referensi dan nominal harus cocok dengan transaksi tersimpan.
- Aplikasi mengambil status server melalui transactionStatus. `00` berarti lunas, `01` pending, `02` dibatalkan. Result code pada browser/return URL tidak digunakan untuk mengubah pembayaran.
- Callback berulang bersifat idempoten. Callback terlambat tidak mengubah transaksi lunas menjadi pending; status pending juga tidak membuka kembali attempt yang sudah dibatalkan.
- Kegagalan komunikasi gateway mengembalikan 503 pada callback agar penyedia dapat mencoba ulang. Hasil invoice yang ambigu mempertahankan order ID, sehingga percobaan ulang tidak membuat order lokal baru.
- Customer pemilik booking dapat menekan **Periksa status pembayaran**, dengan jeda minimal 30 detik. Tidak ada polling API gateway/cron otomatis.
- Sandbox ditandai di checkout dan riwayat. Total uang production mengecualikan sandbox dan riwayat Midtrans (implementasi lama hanya sandbox). CSV menyertakan provider dan mode.

## Uji sandbox nyata sebelum production

1. Siapkan domain/host HTTPS dan set `APP_HOST` ke host tersebut pada server, lalu restart web/worker bila environment server berubah.
2. Daftarkan callback URL yang tampil di Admin pada project Duitku bila portal memintanya. Pastikan `/duitku/callback` dapat menerima POST publik, tidak diarahkan ke halaman login, dan tidak diblokir proxy.
3. Masukkan kredensial sandbox di Admin, aktifkan, lalu buat booking online sebagai customer.
4. Pastikan checkout membuka domain sandbox Duitku, nominal dan identitas order benar, lalu selesaikan transaksi menggunakan fasilitas simulator Duitku.
5. Pastikan callback menghasilkan 200 dan status menjadi lunas hanya setelah verifikasi API. Uji juga batal/pending, refresh manual, callback berulang dan percobaan ulang invoice setelah timeout.
6. Periksa riwayat admin/owner dan CSV: label sandbox muncul, sedangkan angka total uang production tidak bertambah.
7. Periksa pengiriman email melalui SMTP nyata, backup/restore dan konfigurasi HTTPS produksi sebelum menerima pelanggan publik.
8. Setelah seluruh invoice sandbox selesai, masukkan project production melalui Admin. Perpindahan mode tidak memindahkan saldo atau transaksi antar project.

Tes otomatis memakai HTTP stub dan database terpisah; hasil hijau bukan bukti merchant production disetujui, transaksi sandbox nyata berhasil, atau dana masuk ke rekening bank.

## Riwayat dan batas fitur

Migrasi memberi label `midtrans` pada record lama; record baru default `duitku`. Data dan identitas transaksi lama dipertahankan. Tidak ada checkout/callback Midtrans aktif. Pending lama atau pembayaran terlambat harus direkonsiliasi oleh merchant sebelum booking tersebut dibayar ulang.

Refund otomatis, payout/settlement ke owner, pemotongan komisi otomatis, serta rekonsiliasi bank belum diimplementasikan. Status pembayaran API berarti pembayaran telah dikonfirmasi gateway, bukan bukti dana telah cair ke owner. Periksa pembayaran ganda/terlambat di portal merchant dan tangani refund melalui prosedur penyedia.

## Referensi resmi

- [Duitku POP: create invoice, hosted redirect dan callback](https://docs.duitku.com/pop/id/)
- [Duitku API: pemeriksaan status transaksi](https://docs.duitku.com/api/id/#cek-transaksi)

Implementasi mengikuti dokumentasi yang diperiksa 10 Oktober 2026. Dokumentasi terbaru menggunakan HMAC SHA256; contoh lama MD5/SHA256 tanpa HMAC tidak dipakai.
