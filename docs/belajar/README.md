# Paket belajar GlowBook

Mulai dari **[panduan utama HTML](PANDUAN_GLOWBOOK.html)** atau **[buku PDF](../../output/pdf/Belajar_GlowBook.pdf)**.

## Isi

- Buku PDF 45 halaman: 33 bab, contoh kode dan 18 latihan/pembahasan.
- [Atlas kode](ATLAS_KODE.html): 327 file sumber snapshot `cb1cc60`, 17.031 baris, nomor baris, ringkasan tanggung jawab, method dan petunjuk pola.
- [Workbook HTML](LATIHAN_DAN_JAWABAN.html) dan [sumber Markdown](LATIHAN_DAN_JAWABAN.md).
- [Sumber panduan](PANDUAN_GLOWBOOK.md) dan indeks kode JSON untuk pemeliharaan dokumentasi.

HTML dapat dibuka langsung di browser tanpa server/internet. Tautan referensi eksternal tentu memerlukan internet. Atlas menjelaskan per file dan pola yang terdeteksi; pembahasan proses bisnis ada di buku. Ini bukan klaim semua 17.031 baris dijelaskan satu per satu secara semantik.

## Membawa paket ke komputer lain

Ekstrak `output/GlowBook_Paket_Belajar.zip`, lalu buka `docs/belajar/PANDUAN_GLOWBOOK.html`. Pertahankan struktur folder agar tautan PDF dan workbook berfungsi.

## Cara belajar

1. Bab 01-06 untuk mengenali stack dan Ruby.
2. Bab 07-09 untuk lingkungan latihan dan katalog kecil.
3. Latihan 1-4 untuk membangun sesuatu dengan tangan sendiri.
4. Baru lanjut relasi, akses, jadwal dan booking.

Kerjakan pada folder/database latihan. Jangan seed/reset data project utama. Jangan memasukkan secret asli ke file dokumentasi.

## Memperbarui dokumen

Edit Markdown dan ringkasan file pada `build_learning_docs.py`, lalu jalankan script dengan Python yang memiliki ReportLab. Generator membaca source yang terlacak Git; key/dump/upload/build asset dikecualikan. PDF memerlukan font Segoe UI dan Consolas dari Windows. Snapshot/date saat ini sengaja tetap 14 Oktober 2026 / `cb1cc60`; ubah secara sadar saat membuat edisi baru.

Dokumen ini tidak mengubah source aplikasi, data lokal, konfigurasi layanan atau kredensial. Status pengujian historis tidak disamakan dengan uji ulang hari ini.
