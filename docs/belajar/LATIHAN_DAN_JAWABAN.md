# Workbook GlowBook — Latihan dan Pembahasan

Gunakan bersama PANDUAN_GLOWBOOK.html. Semua perubahan eksperimen dilakukan pada `glowbook_latihan` atau salinan project dengan database latihan. Jangan gunakan data klien sebagai data belajar. Urutan ini tidak menetapkan jam kerja Upwork.

## Cara mengerjakan

1. Baca tugas dan tulis rencana tiga kalimat.
2. Kerjakan dahulu sebelum membaca pembahasan.
3. Jelaskan input, proses, output dan kemungkinan kegagalan.
4. Simpan satu commit setelah tugas selesai dan diperiksa.

## Latihan 1 — Menjelaskan satu request

**Tugas:** tulis urutan saat browser membuka `/admin/pengguna`.

**Selesai jika:** Anda menyebut routes, access guard, controller, model, filter dan view.

**Pembahasan:** GET dipetakan routes ke Admin::UsersController#index. Admin::BaseController menjalankan require_admin!. Scope User dipilih, Paginatable membaca kontrol tabel, PostgreSQL menyediakan data, lalu view index menghasilkan HTML. Pengguna yang tidak berhak tidak boleh mencapai data admin.

## Latihan 2 — Ruby sederhana

**Tugas:** hitung harga tiga layanan `[100_000, 150_000, 75_000]`, lalu tampilkan totalnya.

**Selesai jika:** hasil 325000 dan Anda memahami Array/Integer.

```ruby
harga = [100_000, 150_000, 75_000]
total = harga.sum
puts total
```

**Pembahasan:** underscore hanya membantu membaca angka. `sum` menjumlahkan elemen. `puts` menampilkan hasil; belum menyimpan apa pun ke database.

## Latihan 3 — Katalog mini

**Tugas:** selesaikan CRUD mini bab 09: list, new dan create.

**Selesai jika:** layanan baru tampil setelah submit; nama kosong dan harga negatif ditolak; pesan error ditampilkan.

**Pembahasan:** route menentukan action, controller membuat Service dari strong parameters, model memvalidasi, view menampilkan hasil. Validasi form browser tidak menggantikan validasi server. Bila gagal, render new dengan status 422; bila berhasil, redirect ke daftar.

## Latihan 4 — Tambah deskripsi

**Tugas:** tambahkan `description:text` pada katalog mini, tampilkan textarea dan deskripsinya di daftar.

**Selesai jika:** deskripsi tetap ada setelah halaman dimuat ulang.

**Pembahasan:** buat migration, migrate, permit `:description`, tambahkan `f.text_area`, lalu tampilkan `service.description`. Jangan hanya menambah field HTML: tanpa permit data tidak masuk ke model. Jangan mengedit schema.rb secara langsung.

## Latihan 5 — Relasi bisnis dan layanan

**Tugas:** rancang relasi Business–Service; jelaskan di tabel mana foreign key berada. Belum perlu menyalin seluruh schema GlowBook.

**Selesai jika:** Anda menjelaskan satu bisnis memiliki banyak layanan, service belongs_to business, dan services menyimpan business_id.

**Pembahasan:** `has_many :services` pada Business dan `belongs_to :business` pada Service. Migration membutuhkan reference business. Ketika menambah relasi pada data yang sudah ada, rencanakan pengisian foreign key lama sebelum memberi null:false; generator saja tidak menyelesaikan migrasi data.

## Latihan 6 — Periksa akses owner

**Tugas:** jelaskan mengapa `@business.services.find(id)` lebih tepat daripada `Service.find(id)` untuk edit layanan owner.

**Selesai jika:** Anda menyebut scope, ownership dan kemungkinan mengganti ID pada URL.

**Pembahasan:** scope pertama membatasi record ke bisnis yang boleh diakses. Login owner tidak membuat semua layanan menjadi miliknya. Tombol edit disembunyikan bukan perlindungan server; endpoint juga perlu memeriksa akses.

## Latihan 7 — Memahami interval

**Tugas:** staff punya booking 09.00–10.00. Apakah 09.30–10.30 bentrok? Apakah 10.00–10.30 bentrok jika range `[)`?

**Jawaban:** yang pertama bentrok; yang kedua tidak.

**Pembahasan:** `[)` memasukkan awal, mengecualikan akhir. Tugas lanjutan: tambahkan break 10.15–10.45. Walau tidak bentrok booking, layanan 10.00–10.30 tetap tidak tersedia karena break.

## Latihan 8 — Rangkaian layanan

**Tugas:** layanan A 45 menit, B 30 menit, awal 09.00. Staff punya break 10.00–10.30. Tentukan waktu selesai dan apakah rangkaian tersedia.

**Jawaban:** akhir 10.15; tidak tersedia.

**Pembahasan:** A berakhir 09.45, B berakhir 10.15. Jangan hanya memeriksa apakah waktu awal 09.00 tersedia. Seluruh interval harus valid.

## Latihan 9 — Transaction dan lock

**Tugas:** booking berhasil dibuat tetapi BookingItem kedua gagal. Jelaskan hasil bila keduanya berada dalam transaksi dan penyimpanan memakai bang method.

**Jawaban:** exception menyebabkan rollback perubahan dalam transaksi; jangan meninggalkan booking setengah lengkap.

**Pembahasan:** transaksi menjaga kesatuan perubahan. Lock mengatur perubahan bersamaan. Constraint overlap tetap diperlukan karena dua transaksi dapat semula sama-sama melihat slot kosong. Ketiganya mempunyai tugas berbeda.

## Latihan 10 — Pagination

**Tugas:** 63 hasil, 25 per halaman. Berapa halaman? Berapa offset halaman ketiga? Apa hasil bila filter hanya menyisakan 6 record?

**Jawaban:** tiga halaman; offset 50; satu halaman untuk enam hasil.

**Pembahasan:** total halaman ceil(63/25). Halaman terakhir bukan selalu penuh. Page dari URL harus divalidasi/dibatasi. Filter harus diterapkan sebelum count, limit dan offset.

## Latihan 11 — Filter tanggal

**Tugas:** jelaskan perbedaan filter created_at User dan start_time Booking.

**Jawaban:** yang pertama memilih tanggal akun dibuat; yang kedua tanggal janji layanan.

**Pembahasan:** jangan menyebut kedua filter sebagai “tanggal transaksi” tanpa konteks. GlowBook memberi label basis tanggal. Waktu harus sesuai timezone aplikasi.

## Latihan 12 — Spacing CSS

**Tugas:** buat card filter dengan label tidak menempel tepi, pencarian selebar baris, dan dua field sejajar di layar kecil.

**Selesai jika:** padding sisi 16 px terlihat, label punya margin bawah, dan field tidak melebar keluar wadah.

**Pembahasan:** padding untuk sisi card, gap untuk jarak kolom, min-width:0 untuk grid item. Periksa view lebar kecil dan besar. Tidak perlu menambah JavaScript hanya untuk spacing.

## Latihan 13 — Email dan chat

**Tugas:** booking berhasil tetapi email belum sampai. Buat daftar pemeriksaan. Jelaskan juga mengapa pesan chat memakai textContent.

**Pembahasan:** periksa konfigurasi SMTP aktif, antrean, worker, job gagal, penerima dan inbox/spam. `deliver_later` hanya mengantrekan. `textContent` menghindari menafsirkan isi pesan sebagai HTML yang dapat berbahaya.

## Latihan 14 — Pembayaran palsu dari browser

**Tugas:** seseorang membuka return URL dengan `resultCode=00`. Bolehkah aplikasi langsung memberi status lunas?

**Jawaban:** tidak.

**Pembahasan:** browser dapat mengubah parameter. Pembayaran ditentukan oleh callback terverifikasi dan pemeriksaan API status. Cocokkan merchant, mode, order, reference dan nominal. Callback dua kali tidak boleh membuat efek pembayaran dua kali.

## Latihan 15 — Bahasa

**Tugas:** tambahkan label fitur latihan dalam locale id dan en, lalu panggil t(...) pada view.

```yaml
id:
  latihan:
    deskripsi: Deskripsi layanan
```

```yaml
en:
  latihan:
    deskripsi: Service description
```

```erb
<%= t("latihan.deskripsi") %>
```

**Pembahasan:** key sama pada kedua file; value berbeda bahasa. Indentasi YAML menentukan hirarki. Tidak perlu mengganti nama key menjadi bahasa Inggris pada file en.

## Latihan 16 — Uji dan debugging

**Tugas:** tambahkan model spec harga negatif pada katalog mini dan buat ia lulus karena model benar, bukan karena expectation dilemahkan.

**Selesai jika:** spec gagal ketika validasi sengaja dilepas dan berhasil ketika validasi dikembalikan.

**Pembahasan:** ini bukti spec menguji perilaku yang dimaksud. Skenario valid dan invalid sama-sama diperlukan; validasi yang menolak semua data juga dapat meluluskan satu spec invalid.

## Latihan 17 — Deployment dan backup

**Tugas:** sebutkan tiga kelompok data yang perlu dipulihkan pada GlowBook production dan satu secret yang harus dipertahankan.

**Jawaban:** database aplikasi, database queue, file upload; key utama SECRET_KEY_BASE untuk membaca konfigurasi terenkripsi.

**Pembahasan:** metadata Active Storage di database tidak menggantikan byte file. Backup key perlu disimpan aman terpisah. Restore ke lingkungan terpisah untuk menghindari menimpa data aktif.

## Latihan 18 — Komunikasi klien

**Tugas:** tulis update singkat untuk fitur filter pengguna. Sertakan hasil, bukti, keterbatasan dan actual time bila kontrak hourly.

**Contoh:**

```text
Implemented admin user search, role filter and page-size controls.
Verified 10-row paging and combined role/email search.
Commit: [your actual commit]
Known limit: All records can be expensive on large datasets.
Time: actual work recorded under the agreed contract scope.
```

**Pembahasan:** jangan menulis jumlah jam yang tidak dikerjakan. Jangan menyebut “all tests pass” bila hanya membuka satu halaman. Dokumentasi, review dan pengujian nyata merupakan hasil kerja yang bisa dijelaskan dengan konkret.

## Penilaian diri

| Pertanyaan | Jawab Ya/Belum |
| --- | --- |
| Saya dapat menelusuri satu URL sampai view. | |
| Saya memahami perbedaan model validation dan DB constraint. | |
| Saya dapat membuat CRUD kecil tanpa generator penuh. | |
| Saya dapat menjelaskan scope owner dan strong parameters. | |
| Saya tahu mengapa booking memakai range dan transaksi. | |
| Saya tidak memakai return URL untuk memutuskan pembayaran. | |
| Saya tahu kapan perlu worker dan permanent storage. | |
| Saya dapat membaca diff dan membuat commit yang jelas. | |
| Saya dapat melaporkan hasil tanpa melebih-lebihkan bukti. | |

Jika banyak jawaban Belum, pilih satu latihan dan ulangi. Jangan menambah semua teknologi sekaligus. Pada sesi belajar berikutnya, mulai dari bab 09 dan satu error yang dapat direproduksi.
