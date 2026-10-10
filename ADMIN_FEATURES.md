# Pengelolaan Admin

## Pembaruan

- Pengguna: tambah, detail, edit nama/email/telepon/peran/kata sandi, pencarian, filter, pagination dan hapus akun tanpa riwayat. Kata sandi kosong saat edit mempertahankan kata sandi sebelumnya. Peran admin, akun sendiri dan owner/staff yang terhubung dilindungi; email OAuth tidak dapat diganti melalui panel ini.
- Bisnis: tambah dengan owner dan kategori, edit profil/lokasi/kategori, detail, persetujuan, suspend dan reaktivasi. Bisnis baru pending dengan tujuh hari tertutup; owner menyiapkan operasional sebelum publikasi. Owner lama dan slug publik dipertahankan saat edit. Suspend mempertahankan booking dan riwayat.
- Promosi: tambah, edit termasuk aktif/nonaktif dan periode, filter, pagination dan hapus. Promosi yang sudah tersimpan tetap terhubung ke bisnis semula.
- Kategori: tambah/edit/hapus dan pilihan populer tersedia sebelumnya.
- Booking: detail, filter/pencarian dan perubahan status tersedia sebelumnya. Pembayaran diverifikasi Duitku, bukan diubah menjadi lunas secara manual.
- Ulasan: moderasi/hapus tersedia; isi ulasan tetap milik penulis.
- Laporan/analitik, riwayat pembayaran/CSV, pengaturan komisi dan integrasi tersedia. Angka komisi konfigurasi belum berarti komisi ditagih otomatis.

## Pekerjaan yang belum dapat dinyatakan selesai

- Model keuangan: tentukan apakah dana diterima platform atau bisnis sebelum mengimplementasikan saldo owner, payout dan komisi otomatis. Refund otomatis belum tersedia.
- Duitku: kredensial merchant sandbox, host callback publik, uji transaksi nyata dan persetujuan merchant production.
- Google/Facebook dan SMTP: kredensial, konfigurasi penyedia dan pembuktian login/pengiriman nyata.
- Production: server, domain/DNS/HTTPS, secret production, backup terjadwal di luar host dan uji restore.
- WhatsApp belum menjadi kanal notifikasi. Notifikasi aplikasi memakai email dan in-app.

Dokumen ini mencatat cakupan dan batas implementasi, bukan klaim semua fitur aplikasi sudah 100% siap production.