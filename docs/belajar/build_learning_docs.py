"""Build offline learning artifacts from authored Markdown and tracked source.

No application/database access. Private files, uploads and generated assets are
excluded. Run from the repository root with Python + reportlab.
"""
from pathlib import Path
import re
import html
import json
import subprocess
import textwrap
from html.parser import HTMLParser

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "belajar"
SNAPSHOT = "cb1cc60"

def blocks(source):
    """Small Markdown subset used by these documents, not a general parser."""
    lines = source.splitlines()
    result, i = [], 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith("```"):
            language, code = line[3:].strip(), []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code.append(lines[i]); i += 1
            result.append(("code", language, "\n".join(code))); i += 1
        elif re.match(r"^#{1,6} ", line):
            match = re.match(r"^(#+) (.*)$", line)
            result.append(("heading", len(match[1]), match[2])); i += 1
        elif line.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                if not re.match(r"^\|[\s:|\-]+\|$", lines[i]):
                    rows.append([cell.strip() for cell in re.split(r"\|(?=(?:[^`]*`[^`]*`)*[^`]*$)", lines[i].strip("|"))])
                i += 1
            result.append(("table", rows))
        elif re.match(r"^[-*] |^\d+\. ", line):
            numbered = bool(re.match(r"^\d+\. ", line))
            items = []
            while i < len(lines) and re.match(r"^[-*] |^\d+\. ", lines[i]):
                items.append(re.sub(r"^[-*] |^\d+\. ", "", lines[i])); i += 1
            result.append(("list", numbered, items))
        else:
            paragraph = [line]; i += 1
            while i < len(lines) and lines[i].strip() and not re.match(r"^(#{1,6} |```|\||[-*] |\d+\. )", lines[i]):
                paragraph.append(lines[i]); i += 1
            result.append(("paragraph", " ".join(paragraph)))
    return result

def inline(value):
    """Escape all raw input before adding the restricted formatting tokens."""
    value = html.escape(value)
    value = re.sub(r"`([^`]+)`", r"<code>\1</code>", value)
    value = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", value)
    value = re.sub(r"\[([^\]]+)\]\((https?://[^)]+)\)", r'<a href="\2">\1</a>', value)
    return value

CSS = """
:root{--ink:#17232c;--muted:#5f717b;--accent:#c32153;--line:#dde5e8;--paper:#fff;--wash:#f3f6f7}
*{box-sizing:border-box}body{margin:0;background:var(--wash);color:var(--ink);font-family:'Segoe UI',Arial,sans-serif;line-height:1.75}
a{color:var(--accent);text-underline-offset:3px}header{background:#172d38;color:white;padding:48px max(24px,calc((100vw - 1150px)/2));border-bottom:7px solid #df3668}
header p{max-width:720px;color:#d2e0e6}header .eyebrow{color:#ffabc4;letter-spacing:.15em;text-transform:uppercase;font-size:12px;font-weight:700}
.layout{max-width:1220px;margin:auto;display:grid;grid-template-columns:260px minmax(0,1fr);gap:28px;padding:28px}
aside{position:sticky;top:20px;align-self:start;max-height:calc(100vh - 40px);overflow:auto;padding:20px;background:white;border:1px solid var(--line);border-radius:14px;font-size:13px}
aside a{display:block;padding:6px 0;color:var(--ink);text-decoration:none}aside a:hover{color:var(--accent)}
main{min-width:0;background:white;border:1px solid var(--line);border-radius:16px;padding:34px 42px}
h1,h2,h3{line-height:1.3}h1{font-size:36px;letter-spacing:-.025em}h2{font-size:26px;margin:55px 0 22px;padding-top:22px;border-top:2px solid var(--line);scroll-margin-top:20px}h3{font-size:19px;margin-top:30px}
p{margin:16px 0}li{padding:4px 0}pre{background:#132b37;color:#ecf4f7;padding:20px;border-radius:10px;overflow:auto;line-height:1.6;font-size:12px;tab-size:2}
code{font-family:Consolas,'Courier New',monospace;font-size:.92em}p code,td code,li code{background:#f0f3f5;padding:2px 5px;border-radius:4px;color:#a11b44;overflow-wrap:anywhere}
.table-wrap{overflow:auto;margin:22px 0}table{width:100%;border-collapse:collapse;font-size:14px}th{background:#edf3f5;text-align:left;color:#173a4a}td,th{padding:12px 14px;border:1px solid var(--line);vertical-align:top}tr:nth-child(even) td{background:#fafcfc}
.tools{display:flex;flex-wrap:wrap;gap:10px;margin-top:22px}.tools a,.tools button{padding:9px 15px;background:white;color:#173a4a;border:1px solid #d2e0e6;border-radius:8px;text-decoration:none;font:600 13px 'Segoe UI',sans-serif;cursor:pointer}
.note{padding:18px 22px;border-left:4px solid var(--accent);background:#fff2f6;border-radius:4px;margin-bottom:28px}
.source-card{padding:20px 0;border-bottom:1px solid var(--line)}.source-card h2{margin:0 0 12px;border:0;padding:0;font-size:19px;overflow-wrap:anywhere}.source-card p{margin:8px 0;font-size:14px}.source-card summary{cursor:pointer;color:var(--accent);font-weight:600;padding:12px 0}.source-card pre{max-height:650px}
.source-line{display:flex;line-height:1.7}.source-line .n{color:#85a6b6;width:44px;flex:none;text-align:right;padding-right:12px;user-select:none}.source-line .src{white-space:pre;flex:1}
.search{width:100%;padding:12px;border:1px solid var(--line);border-radius:8px;font:14px 'Segoe UI',sans-serif;margin-bottom:10px}.small{font-size:13px;color:var(--muted)}[hidden]{display:none!important}footer{text-align:center;padding:30px;color:var(--muted);font-size:12px}
@media(max-width:850px){.layout{display:block;padding:16px}aside{position:static;max-height:260px;margin-bottom:20px}main{padding:22px}h1{font-size:29px}h2{font-size:23px}header{padding:30px 22px}td,th{padding:10px}pre{padding:14px}}
@media print{body{background:white;font-size:10pt}.layout{display:block;padding:0}aside,.tools{display:none}header{padding:18px;color:#17232c;background:white}header p,header .eyebrow{color:#17232c}main{border:0;padding:0}h2{break-before:page}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#eef2f4;color:#17232c}tr{break-inside:avoid}.source-card pre{max-height:none}a{color:inherit}footer{display:none}}
"""

def shell(title, subtitle, body, sidebar, extra_script="", links=""):
    return f'''<!doctype html><html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title><style>{CSS}</style></head><body>
    <header><div class="eyebrow">GlowBook / Learning Library / 14 Oktober 2026</div><h1>{html.escape(title)}</h1><p>{subtitle}</p><div class="tools"><a href="PANDUAN_GLOWBOOK.html">Panduan utama</a><a href="ATLAS_KODE.html">Atlas kode</a><a href="LATIHAN_DAN_JAWABAN.html">Latihan & pembahasan</a>{links}<button onclick="window.print()">Cetak</button></div></header>
    <div class="layout"><aside>{sidebar}</aside><main>{body}</main></div><footer>Snapshot {SNAPSHOT} · Dokumen belajar offline · Tidak menyertakan kredensial pribadi</footer>{extra_script}</body></html>'''

def render_markdown(filename, title, subtitle):
    parsed = blocks((OUT / filename).read_text(encoding="utf-8"))
    content, toc, headings = [], [], 0
    for block in parsed:
        kind = block[0]
        if kind == "heading":
            _, level, text = block
            if level == 1:
                continue
            headings += 1; anchor = f"section-{headings}"
            content.append(f'<h{level} id="{anchor}">{inline(text)}</h{level}>')
            if level == 2:
                toc.append(f'<a href="#{anchor}">{html.escape(text)}</a>')
        elif kind == "code":
            content.append(f'<pre aria-label="Contoh kode {html.escape(block[1])}"><code>{html.escape(block[2])}</code></pre>')
        elif kind == "paragraph":
            content.append(f'<p>{inline(block[1])}</p>')
        elif kind == "list":
            tag = "ol" if block[1] else "ul"
            content.append(f'<{tag}>'+"".join(f'<li>{inline(item)}</li>' for item in block[2])+f'</{tag}>')
        elif kind == "table":
            rows = block[1]
            content.append('<div class="table-wrap"><table><thead><tr>'+"".join(f'<th>{inline(c)}</th>' for c in rows[0])+ '</tr></thead><tbody>'+"".join('<tr>'+"".join(f'<td>{inline(c)}</td>' for c in row)+'</tr>' for row in rows[1:])+'</tbody></table></div>')
    page = shell(title, subtitle, "\n".join(content), '<strong>Daftar isi</strong><p class="small">Ctrl+F untuk mencari istilah. Pilih satu bab setiap sesi.</p>'+"\n".join(toc), links='<a href="../../output/pdf/Belajar_GlowBook.pdf">Unduh PDF</a>')
    (OUT / filename.replace(".md", ".html")).write_text(page, encoding="utf-8")
    return parsed

DESCRIPTIONS = {
    "app/controllers/application_controller.rb": "Landasan controller: locale, parameter Devise, tujuan login, serta pembatasan akses pelanggan/bisnis/admin.",
    "app/controllers/bookings_flow_controller.rb": "State lima langkah booking di session; memvalidasi pilihan dan memanggil BookingBuilder. Harga tetap berasal dari database.",
    "app/controllers/bookings_controller.rb": "Detail booking pelanggan, pembatalan dan ubah jadwal, dengan aturan akses dan perubahan booking.",
    "app/controllers/business_registrations_controller.rb": "Onboarding mandiri: kategori valid, bisnis pending, jam default, dan kenaikan peran owner dalam transaksi.",
    "app/controllers/chats_controller.rb": "Daftar percakapan, peserta, pengiriman dan polling pesan. Pesan hanya dapat dibaca pihak yang berhak.",
    "app/controllers/searches_controller.rb": "Filter marketplace, pengurutan rating/harga/jarak, validasi lokasi dan pagination publik 12 hasil.",
    "app/controllers/concerns/paginatable.rb": "Mesin tabel bersama: pencarian terikat scope, pilihan ukuran, filter field/relasi/tanggal dan metadata pagination.",
    "app/controllers/booking_payments_controller.rb": "Endpoint pelanggan untuk membuat checkout dan memeriksa ulang status attempt milik booking yang boleh diakses.",
    "app/controllers/duitku_notifications_controller.rb": "Endpoint callback server Duitku. Ekstrak field body, jalankan verifikasi service, balas 200/422/503.",
    "app/controllers/admin/users_controller.rb": "CRUD pengguna admin; role diatur secara eksplisit, password kosong dipertahankan dan akun bersejarah dilindungi.",
    "app/controllers/admin/businesses_controller.rb": "Tambah/edit profil bisnis, pending, persetujuan, suspend/reaktivasi; ownership lama tidak dipindahkan melalui edit biasa.",
    "app/controllers/admin/promotions_controller.rb": "Tambah/edit/hapus promosi dan aktif/nonaktif; bisnis promosi lama dipertahankan saat edit.",
    "app/controllers/admin/reports_controller.rb": "Laporan bulanan dan ekspor; baca definisi status/periode sebelum menyamakan nilai booking dengan uang diterima.",
    "app/controllers/admin/integrations_controller.rb": "Form integrasi admin dan update konfigurasi provider; field secret dipertahankan atau dihapus dengan pilihan eksplisit.",
    "app/controllers/dashboard/base_controller.rb": "Landasan dashboard bisnis: akses owner/staff dan pemilihan bisnis yang terkait dengan pengguna.",
    "app/controllers/admin/base_controller.rb": "Landasan panel admin: layout dashboard, Paginatable dan guard require_admin!.",
    "app/controllers/account/base_controller.rb": "Landasan dashboard akun pelanggan dan akses login; controller turunannya bekerja pada data pengguna.",
    "app/controllers/dashboard/staff_availability_controller.rb": "Mengelola shift, break dan menyalin jam untuk staff dalam bisnis yang boleh diakses.",
    "app/controllers/dashboard/blocked_times_controller.rb": "Membuat/edit/hapus interval larangan booking untuk bisnis atau staff; periksa overlap dan scope bisnis.",
    "app/controllers/dashboard/galleries_controller.rb": "Upload galeri hingga enam file, urutan, validasi dan penghapusan melalui scope bisnis.",
    "app/controllers/dashboard/customers_controller.rb": "Aggregate pelanggan bisnis: jumlah booking, nilai booking dan kunjungan terakhir; pagination grouped query.",
    "app/controllers/dashboard/analytics_controller.rb": "Analitik bisnis menggunakan bulan jadwal, timezone Jakarta dan scope bisnis; sandbox dipisahkan dari uang production.",
    "app/controllers/users/omniauth_callbacks_controller.rb": "Menerima identitas OAuth dan menangani sukses/gagal login; bukan tempat menaruh client secret.",
    "app/controllers/users/registrations_controller.rb": "Penyesuaian pendaftaran/akun Devise dan perlindungan penghapusan akun dengan data yang perlu dipertahankan.",
    "app/models/user.rb": "Identitas, Devise, empat role, relasi data, validasi nama/telepon dan lookup OAuth provider+UID.",
    "app/models/business.rb": "Profil bisnis, owner, kota, kategori, layanan/jadwal/galeri, status dan scope pencarian publik.",
    "app/models/service.rb": "Layanan milik bisnis/kategori dengan harga rupiah integer, durasi, keaktifan dan kualifikasi staff.",
    "app/models/staff.rb": "Anggota staff dan relasi ke bisnis/user/layanan/jadwal; kelayakan staff memengaruhi availability.",
    "app/models/staff_service.rb": "Tabel penghubung kualifikasi staff-layanan; jangan menyamakan semua staff dengan semua layanan.",
    "app/models/staff_schedule.rb": "Interval shift mingguan staff, validasi menit dan aturan jadwal.",
    "app/models/staff_break.rb": "Interval istirahat mingguan staff yang mengurangi waktu tersedia.",
    "app/models/business_hour.rb": "Jam operasional per hari berupa menit dari tengah malam; closed menonaktifkan hari.",
    "app/models/blocked_time.rb": "Interval blocked time bisnis/staff dengan scope overlap dan validasi rentang.",
    "app/models/booking.rb": "Induk janji: status/reference/waktu/total, relasi item/payment, aturan cancel/reschedule/complete/no-show dan lock.",
    "app/models/booking_item.rb": "Snapshot layanan/harga/durasi/staff dan tstzrange yang dilindungi exclusion constraint DB.",
    "app/models/payment_attempt.rb": "Attempt pembayaran terpisah dari status booking; provider/mode/merchant, scope paid dan production_payments.",
    "app/models/integration_setting.rb": "Konfigurasi provider terenkripsi, fallback ENV, validasi, SMTP dan lock perubahan Duitku saat pending.",
    "app/models/platform_setting.rb": "Pengaturan platform tersimpan seperti komisi dan pendaftaran bisnis; bukan mesin penagihan komisi.",
    "app/models/city.rb": "Data referensi kota untuk profil bisnis dan filter marketplace.",
    "app/models/category.rb": "Data kategori, slug, urutan dan pilihan populer serta relasi bisnis/layanan.",
    "app/models/business_category.rb": "Tabel penghubung bisnis dengan beberapa kategori.",
    "app/models/business_gallery.rb": "Satu foto terlampir, caption dan posisi; JPEG/PNG/WebP maksimal 10 MB.",
    "app/models/favorite.rb": "Relasi pengguna-bisnis favorit, dengan keunikan pasangan pada database.",
    "app/models/review.rb": "Rating/komentar pengguna untuk bisnis serta pembaruan aggregate rating; baca kelayakan review pada controller juga.",
    "app/models/promotion.rb": "Judul, kode, persen diskon, periode dan keaktifan promosi; scope active_now memeriksa waktu berlaku.",
    "app/models/conversation.rb": "Percakapan bisnis-pelanggan dan predicate participant? untuk melindungi akses pesan.",
    "app/models/chat_message.rb": "Isi pesan, pengirim, percakapan dan waktu dibaca; server mengontrol identitas pengirim.",
    "app/models/user_notification.rb": "Notifikasi pengguna, event booking, judul/body dan read/unread.",
    "app/models/application_record.rb": "Superclass abstrak Active Record yang diwarisi model project.",
    "app/services/availability.rb": "Slot layanan: jam bisnis, staff berkualifikasi, shift, break, blocked time dan booking yang overlap.",
    "app/services/booking_sequence_availability.rb": "Menghitung ketersediaan rangkaian layanan berurutan pada staff; juga dapat menggunakan snapshot booking saat reschedule.",
    "app/services/booking_builder.rb": "Mengecek layanan/staff/interval lalu membuat booking dan item dalam transaksi; menangani konflik database.",
    "app/services/booking_result.rb": "Objek hasil proses booking: membawa booking atau error dan predicate ok?.",
    "app/services/booking_rescheduler.rb": "Ubah jadwal atomik: lock booking, cek availability, lepas range lama, isi range baru dan rollback jika gagal.",
    "app/services/booking_notification_delivery.rb": "Membuat notifikasi in-app dan mengantrekan email untuk event yang dibatasi allowlist.",
    "app/services/duitku_client.rb": "Klien HTTP Duitku: signature HMAC, invoice/status, timeout, validasi host checkout dan hasil ambigu.",
    "app/services/create_booking_payment.rb": "Membuat/memakai attempt yang sesuai merchant/mode; menjaga order saat timeout dan menolak booking yang tak layak.",
    "app/services/process_duitku_notification.rb": "Verifikasi callback signature/merchant/amount/reference lalu delegasi rekonsiliasi status server.",
    "app/services/reconcile_duitku_payment.rb": "Cek API transactionStatus, cocokkan identitas/nominal, lock update dan lindungi paid dari callback terlambat.",
    "app/services/oauth_provider_setup.rb": "Mengisi konfigurasi strategi OAuth per request dari pengaturan efektif dan callback kanonis.",
    "app/services/payment_attempt_csv.rb": "Menyusun CSV pembayaran dengan provider/mode dan pengamanan nilai yang dapat dianggap formula spreadsheet.",
    "app/services/admin_charts.rb": "Aggregate grafik admin, memakai periode dan tanggal lokal Jakarta.",
    "app/services/platform_bootstrap.rb": "Inisialisasi production tanpa demo: admin dan data referensi, mempertahankan data/password lama.",
    "app/mailers/application_mailer.rb": "Pengirim/layout dasar email dan konfigurasi SMTP efektif saat delivery.",
    "app/mailers/booking_mailer.rb": "Isi email confirmation/cancellation/reschedule beserta konteks booking, penerima dan locale.",
    "app/jobs/booking_mailer_delivery_job.rb": "Job pengiriman mailer booking dengan kebijakan eksekusi/retry yang tertulis di file.",
    "app/jobs/application_job.rb": "Superclass Active Job untuk pekerjaan latar aplikasi.",
    "app/javascript/controllers/chat_controller.js": "Polling empat detik, pesan setelah ID terakhir, render textContent dan pembersihan timer.",
    "app/javascript/controllers/dropdown_controller.js": "Buka/tutup menu, click-outside, Escape/fokus dan reset saat navigasi/cache Turbo.",
    "app/javascript/controllers/dismissable_controller.js": "Menutup pesan pada elemen yang dikendalikan tanpa memengaruhi pesan lain.",
    "app/javascript/controllers/nearby_search_controller.js": "Meminta lokasi browser untuk pencarian terdekat dan menyiapkan request setelah izin pengguna.",
    "app/javascript/controllers/index.js": "Mendaftarkan nama controller Stimulus yang dipakai data-controller pada view.",
    "app/javascript/controllers/application.js": "Menjalankan aplikasi Stimulus dan konfigurasi awalnya.",
    "app/javascript/application.js": "Entry point frontend: import Turbo dan controller yang diperlukan.",
    "app/views/shared/_table_controls.html.erb": "Form GET bersama: pencarian, ukuran, filter, tanggal, Apply/Reset dan ringkasan; query lain dipertahankan sesuai aturan.",
    "app/views/shared/_table_pagination.html.erb": "Link previous/next berbasis metadata tabel, mempertahankan filter dan mengubah page.",
    "app/views/shared/_pagination.html.erb": "Pagination umum/legacy yang masih dipakai bagian tertentu; berbeda dari kontrol tabel bernamespace.",
    "app/views/pwa/service-worker.js": "Cache aset statis dan fallback offline; tidak menyimpan HTML akun/admin atau mengambil alih request mutasi.",
    "app/assets/tailwind/application.css": "Sumber style Tailwind, komponen bersama dan CSS responsive filter; edit sumber ini, bukan CSS build.",
    "config/routes.rb": "Peta URL dan metode HTTP ke action; namespace Ruby dipisah dari path Indonesia.",
    "config/application.rb": "Konfigurasi Rails bersama: locale id/en, zona Jakarta, UTC database dan APP_HOST.",
    "config/database.yml": "Koneksi DB per environment, primary/queue production; password dibaca ENV, bukan kredensial nyata dalam file.",
    "config/storage.yml": "Adapter Active Storage test/local; contoh S3/GCS masih komentar dan bukan konfigurasi aktif.",
    "config/queue.yml": "Pengaturan dispatcher/worker Solid Queue; baca concurrency bersama environment dan Compose.",
    "config/puma.rb": "Thread/port server Puma dan plugin restart; PORT/RAILS_MAX_THREADS datang dari environment.",
    "config/importmap.rb": "Memetakan dependency JavaScript dan controller tanpa bundler npm untuk aplikasi ini.",
    "config/environments/production.rb": "Reload/cache, SSL, host, SMTP, storage lokal dan Solid Queue production.",
    "config/initializers/filter_parameter_logging.rb": "Menentukan parameter rahasia yang disaring dari log; ini bukan izin menyimpan log privat di GitHub.",
    "Dockerfile": "Tahap image base/dependencies/build/verification/runtime, library OS, aset dan proses non-root.",
    "compose.yaml": "PostgreSQL + web + worker, environment, healthcheck dan volume data permanen satu host.",
    "compose.test.yaml": "Stack test terpisah, PostgreSQL sementara dan perintah RSpec. Jangan gunakan untuk menyimpan data penting.",
    "compose.production.yaml": "Overlay deployment HTTPS, proxy dan volume terkait. Domain nyata masih memerlukan konfigurasi lingkungan.",
    "bin/docker-entrypoint": "Menjalankan db:prepare sebelum server, lalu exec proses utama; tidak menyiapkan admin demo production.",
    "lib/tasks/glowbook.rake": "Task glowbook:bootstrap membaca input admin dari environment dan memanggil PlatformBootstrap.",
    ".github/workflows/ci.yml": "Tahap CI: specs, JavaScript, Brakeman, release checks, image, HTTPS dan backup/restore.",
    "script/check_release.rb": "Memeriksa syntax Ruby/ERB, literal key id/en, action routes dan registrasi Stimulus.",
    "script/backup.sh": "Backup data database/storage dengan pengendalian keadaan worker dan checksum; baca BACKUP_RESTORE.md sebelum menjalankan.",
    "script/verify_backup.sh": "Pembuktian workflow backup/restore pada lingkungan terpisah termasuk skenario kegagalan.",
    "db/schema.rb": "Snapshot skema hasil migration, termasuk range dan constraint. Bukan tempat mengedit struktur secara manual.",
    "db/seeds.rb": "Data demo development yang menghapus/mengisi ulang data; ditolak di production. Bukan bootstrap production.",
    "Gemfile": "Library langsung dan grouping environment. Gemfile.lock mengunci dependency aktual termasuk dependency turunan.",
}

def describe(path):
    if path in DESCRIPTIONS:
        return DESCRIPTIONS[path]
    stem = Path(path).stem
    if path.startswith("app/views/"):
        if path.startswith("app/views/layouts/"):
            return "Layout pembungkus halaman: head/aset, navigasi, pesan dan yield konten. Periksa content_for pada view pemanggil."
        if stem.startswith("_"):
            return "Partial tampilan yang dipakai melalui render. Data berasal dari locals atau instance variable; jalur folder menunjukkan fitur pemakainya."
        return "Template respons fitur pada jalur ini. Controller menentukan data, ERB menyusun HTML/JSON/email, helper dan locale memberi format/teks."
    if path.startswith("app/controllers/"):
        namespace = "admin" if "/admin/" in path else "bisnis" if "/dashboard/" in path else "akun" if "/account/" in path else "publik/aplikasi"
        return f"Controller area {namespace} untuk {stem.replace('_controller', '').replace('_', ' ')}. Lihat action dan before_action di bawah untuk scope, parameter dan respons aktual."
    if path.startswith("db/migrate/") or path.startswith("db/queue_migrate/"):
        return "Migration perubahan skema sesuai nama/tanggal file. up/change menerapkan perubahan; down/reversal perlu diperiksa sebelum rollback."
    if path.startswith("spec/"):
        return "Sumber pengujian/data uji, bukan alur production. Baca describe/it/expect untuk skenario dan bukti yang benar-benar dicakup; stub bukan panggilan penyedia nyata."
    if path.startswith("config/locales/"):
        return "Kamus locale. Key dipanggil t/I18n.t dan l/I18n.l; pasangan id/en harus menyediakan key yang sesuai."
    if path.startswith("deploy/"):
        return "Konfigurasi deployment/backup host. Template perlu diterapkan dan diperiksa pada host nyata; keberadaan file bukan bukti layanan aktif."
    if path.startswith("config/"):
        return "Konfigurasi Rails/library pada tahap boot atau environment. Nilai ENV dapat mengubah perilaku; jangan memasukkan secret nyata ke sumber."
    if path.startswith("bin/"):
        return "Entry point perintah project. Periksa environment, working directory dan layanan yang dijalankan sebelum mengeksekusi."
    return "Sumber pendukung pada jalur ini. Gunakan nama file, deklarasi dan pemanggil untuk memahami perannya bersama bab panduan terkait."

PATTERNS = [
    (r"before_action", "before_action: guard/persiapan yang dijalankan sebelum action; perhatikan only/except."),
    (r"belongs_to", "belongs_to: relasi ke induk melalui foreign key; optional/polymorphic mengubah aturan."),
    (r"has_many|has_one", "has_many/has_one: asosiasi record; dependent menentukan dampak penghapusan."),
    (r"validates|validate\s", "Validasi: pemeriksaan model sebelum save, dengan pesan errors bila ditolak."),
    (r"\.transaction|\btransaction do|with_lock", "Transaction/lock: menjaga kesatuan perubahan dan mengatur request bersamaan; tidak menggantikan constraint DB."),
    (r"\.permit\(|params\.require", "Strong parameters: memilih input yang boleh diteruskan. Akses pengguna tetap diperiksa terpisah."),
    (r"scope\s+:|\.where\(|\.joins\(|\.includes\(", "Query: kondisi/relasi membentuk SQL. Scope awal dan preload memengaruhi akses serta jumlah query."),
    (r"redirect_to|render\s", "Respons: redirect membuat request baru; render menyajikan template/data pada request sekarang."),
    (r"rescue\s", "Rescue: menangani exception yang disebut; lihat apakah hasil menjadi pesan, rollback atau retry."),
    (r"deliver_later", "deliver_later: antrekan job email; worker/SMTP menentukan pengiriman nyata."),
    (r"has_one_attached|has_many_attached", "Active Storage: metadata database terpisah dari byte file; storage dan backup keduanya diperlukan."),
    (r"I18n\.|\bt\([\"']|\bl\(", "I18n: t membaca key terjemahan; l memformat tanggal/waktu menurut locale."),
    (r"form_with|fields_for", "Form: menghasilkan input dan token CSRF; model/url menentukan endpoint, permit menentukan data diterima."),
    (r"render [\"']|render partial", "Partial: susunan tampilan yang digunakan ulang; periksa locals dari pemanggil."),
    (r"textContent", "textContent: tampilkan masukan sebagai teks, bukan HTML yang dapat dieksekusi."),
    (r"setInterval|clearInterval", "Timer: polling/refresh terjadwal harus dibersihkan ketika elemen dilepas."),
    (r"OpenSSL::HMAC|secure_compare|encrypt_and_sign", "Kriptografi: gunakan primitive library, key privat dan verifikasi; jangan menggantinya dengan algoritma buatan sendiri."),
    (r"tstzrange|EXCLUDE USING|ExclusionViolation", "Range/constraint: PostgreSQL menolak interval overlap; syntax [) membedakan batas awal/akhir."),
    (r"\bit [\"']|\bit\(|expect\(", "Skenario uji: it menjelaskan kondisi; expect memeriksa hasil. Mock/stub tidak membuktikan integrasi nyata."),
]

def build_atlas():
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode("utf-8").split("\0")
    allowed_roots = ("app/", "config/", "db/", "lib/", "script/", "deploy/", "spec/", "bin/", ".github/workflows/")
    extensions = (".rb", ".erb", ".js", ".cjs", ".css", ".yml", ".yaml", ".rake", ".sh", ".service", ".timer")
    exact = {"Gemfile", "Dockerfile", "compose.yaml", "compose.test.yaml", "compose.production.yaml", "Procfile.dev", "deploy/caddy/Caddyfile", "bin/rails", "bin/rake", "bin/jobs", "bin/dev", "bin/docker-entrypoint"}
    files = []
    for name in tracked:
        if not name or name.startswith(("app/assets/builds/", "config/credentials", "spec/fixtures/")) or name == "config/master.key":
            continue
        if name in exact or (name.startswith(allowed_roots) and name.endswith(extensions)):
            files.append(name)
    cards, index = [], []
    for number, path in enumerate(sorted(files), 1):
        source = (ROOT / path).read_text(encoding="utf-8-sig")
        summary = describe(path)
        methods = re.findall(r"^\s*def\s+([^\s(;]+)", source, flags=re.M)
        functions = ", ".join(methods)
        pattern_notes = [note for pattern, note in PATTERNS if re.search(pattern, source)]
        definitions = []
        if path.startswith("app/models/"):
            for match in re.finditer(r"^\s*(belongs_to|has_many|has_one|scope|enum)\s+:(\w+)", source, re.M):
                definitions.append(f"{match[1]} :{match[2]}")
        labels = f'<p><strong>Method yang dideklarasikan:</strong> {html.escape(functions)}</p>' if functions else ''
        if definitions:
            labels += '<p><strong>Deklarasi utama:</strong> '+html.escape("; ".join(definitions))+'</p>'
        notes = '<ul>'+''.join('<li>'+html.escape(note)+'</li>' for note in pattern_notes)+'</ul>' if pattern_notes else '<p class="small">Baca deklarasi/parameter dan komentar lokal, lalu bandingkan dengan bab panduan untuk lapisan file ini.</p>'
        code = ''.join(f'<span class="source-line" id="f{number}-l{line_no}"><span class="n">{line_no}</span><span class="src">{html.escape(line)}</span></span>' for line_no, line in enumerate(source.splitlines(), 1))
        cards.append(f'<section class="source-card" data-name="{html.escape(path.lower())}" data-search="{html.escape((path + " " + summary + " " + functions).lower())}" id="f{number}"><h2>{html.escape(path)}</h2><p>{html.escape(summary)}</p>{labels}<details><summary>Petunjuk pola kode</summary>{notes}</details><details><summary>Buka {len(source.splitlines())} baris kode</summary><pre><code>{code}</code></pre></details></section>')
        index.append({"file": path, "lines": len(source.splitlines()), "methods": methods, "description": summary, "anchor": f"f{number}"})
    intro = f'<div class="note"><strong>{len(files)} file sumber • snapshot {SNAPSHOT}</strong><p>Ringkasan tanggung jawab dan petunjuk pola mendampingi kode lengkap, bukan penjelasan semantik otomatis setiap baris. Pelajari satu jejak request. Nomor baris berlaku pada snapshot ini; bisa berubah setelah commit lain.</p><p>Secret, dump, upload, dependency pihak ketiga dan aset hasil build tidak dimasukkan. Folder spec hanya berisi data/contoh uji, bukan kredensial merchant nyata.</p></div><p id="results">{len(files)} file ditampilkan</p>'
    groups = ["app/controllers", "app/models", "app/services", "app/views", "app/javascript", "config", "db", "spec", "deploy", "script"]
    sidebar = '<strong>Cari file / method</strong><label for="source-search" class="small">Contoh: availability, users_controller, table_controls</label><input class="search" id="source-search" type="search" placeholder="Ketik nama file atau method…"><p class="small">Buka petunjuk dahulu, lalu kode. Ctrl+F mencari teks kode yang sudah dibuka.</p>'+''.join(f'<button class="search" type="button" data-prefix="{group}">{group}</button>' for group in groups)+'<button class="search" type="button" data-prefix="">Semua file</button>'
    script = '''<script>
    const box=document.getElementById('source-search');const cards=Array.from(document.querySelectorAll('.source-card'));
    function filter(){const query=box.value.trim().toLowerCase();let count=0;for(const card of cards){const show=card.dataset.search.includes(query);card.hidden=!show;if(show)count++;}document.getElementById('results').textContent=count+' file ditampilkan';}
    box.addEventListener('input',filter);document.querySelectorAll('[data-prefix]').forEach(button=>button.addEventListener('click',()=>{box.value=button.dataset.prefix;filter();window.scrollTo({top:0,behavior:'smooth'});}));
    </script>'''
    (OUT / "ATLAS_KODE.html").write_text(shell("Atlas Kode GlowBook", "Referensi sumber per file, nomor baris, method dan petunjuk pola. Semua tersedia offline tanpa membuka editor project.", intro+'\n'.join(cards), sidebar, script), encoding="utf-8")
    (OUT / "INDEKS_KODE.json").write_text(json.dumps({"snapshot": SNAPSHOT, "date": "2026-10-14", "files": index}, indent=2, ensure_ascii=False), encoding="utf-8")
    return index

def build_pdf(guide_blocks, workbook_blocks):
    from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, PageBreak, Table, TableStyle, Preformatted, NextPageTemplate)
    from reportlab.platypus.tableofcontents import TableOfContents
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_LEFT
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.lib.pagesizes import A4

    fonts = Path("C:/Windows/Fonts")
    for name, filename in [("Study", "segoeui.ttf"), ("StudyBold", "segoeuib.ttf"), ("StudyItalic", "segoeuii.ttf"), ("Code", "consola.ttf")]:
        pdfmetrics.registerFont(TTFont(name, str(fonts / filename)))
    pdfmetrics.registerFontFamily("Study", normal="Study", bold="StudyBold", italic="StudyItalic", boldItalic="StudyBold")
    output = ROOT / "output" / "pdf" / "Belajar_GlowBook.pdf"
    output.parent.mkdir(parents=True, exist_ok=True)
    width, height = A4
    margin, content_width = 48, width - 96
    ink, accent, muted = colors.HexColor("#17313e"), colors.HexColor("#c32153"), colors.HexColor("#5b6d77")
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name="StudyBody", fontName="Study", fontSize=10, leading=14, textColor=ink, spaceAfter=8))
    styles.add(ParagraphStyle(name="StudyH2", fontName="StudyBold", fontSize=22, leading=28, textColor=ink, spaceBefore=16, spaceAfter=16, keepWithNext=True))
    styles.add(ParagraphStyle(name="StudyH3", fontName="StudyBold", fontSize=13, leading=19, textColor=accent, spaceBefore=14, spaceAfter=8, keepWithNext=True))
    styles.add(ParagraphStyle(name="StudyCell", fontName="Study", fontSize=8.5, leading=12, textColor=ink))
    styles.add(ParagraphStyle(name="StudyHead", fontName="StudyBold", fontSize=8.5, leading=12, textColor=ink))
    styles.add(ParagraphStyle(name="StudyCode", fontName="Code", fontSize=8, leading=10.5, textColor=ink, backColor=colors.HexColor("#edf2f4"), borderPadding=8, spaceBefore=8, spaceAfter=12))
    styles.add(ParagraphStyle(name="CoverTitle", fontName="StudyBold", fontSize=36, leading=43, textColor=ink, spaceAfter=24))
    styles.add(ParagraphStyle(name="CoverKicker", fontName="StudyBold", fontSize=11, leading=18, textColor=accent, spaceAfter=18))
    styles.add(ParagraphStyle(name="Contents", fontName="Study", fontSize=9, leading=14, leftIndent=0, firstLineIndent=0, spaceBefore=4))

    def clean(text):
        return text.replace("—", "-").replace("–", "-").replace("‑", "-").replace("→", "->").replace("…", "...").replace("“", '"').replace("”", '"').replace("·", "|")
    def rich(text):
        text = inline(clean(text)).replace("<strong>", "<b>").replace("</strong>", "</b>")
        text = text.replace("<code>", '<font name="Code" size="8.5">').replace("</code>", "</font>")
        text = re.sub(r'<a href="([^"]+)">', r'<link href="\1" color="#a11b44">', text).replace("</a>", "</link>")
        return text

    class GuideDoc(BaseDocTemplate):
        def afterFlowable(self, flowable):
            if isinstance(flowable, Paragraph) and getattr(flowable, "toc_key", None):
                self.canv.bookmarkPage(flowable.toc_key)
                self.canv.addOutlineEntry(flowable.getPlainText(), flowable.toc_key, 0)
                self.notify("TOCEntry", (0, flowable.getPlainText(), self.page, flowable.toc_key))

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setFont("Study", 8); canvas.setFillColor(muted)
        canvas.drawString(margin, height - 29, "GLOWBOOK / PANDUAN BELAJAR")
        canvas.setStrokeColor(colors.HexColor("#dce5e9")); canvas.line(margin, height - 35, width - margin, height - 35)
        canvas.drawString(margin, 27, "14 Oktober 2026  |  kode acuan " + SNAPSHOT)
        canvas.drawRightString(width - margin, 27, str(doc.page))
        canvas.restoreState()

    doc = GuideDoc(str(output), pagesize=A4, title="Belajar Membuat GlowBook dari Awal", author="GlowBook Learning Documentation", leftMargin=margin, rightMargin=margin, topMargin=54, bottomMargin=45)
    doc.addPageTemplates(PageTemplate(id="body", frames=[Frame(margin, 45, content_width, height - 99, leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)], onPage=footer))
    story = [Spacer(1, 80), Paragraph("BELAJAR / MEMBANGUN / MENJELASKAN", styles["CoverKicker"]), Paragraph("Membuat GlowBook<br/>dari Awal", styles["CoverTitle"]), Paragraph("Panduan Ruby on Rails untuk pemula<br/>dengan contoh kode, alur fitur dan latihan", styles["StudyH3"]), Spacer(1, 28), Paragraph("33 bab + 18 latihan", styles["StudyH2"]), Paragraph("Baca satu bab, kerjakan satu perubahan kecil, lalu jelaskan alasan kode Anda. Atlas HTML mendampingi buku ini dengan sumber project per file dan nomor baris.", styles["StudyBody"]), Spacer(1, 26), Paragraph("Versi belajar: 14 Oktober 2026<br/>Snapshot kode: cb1cc60<br/>Bahasa: Indonesia", styles["StudyBody"]), PageBreak(), Paragraph("Daftar isi", styles["StudyH2"])]
    toc = TableOfContents(); toc.levelStyles = [styles["Contents"]]
    story.extend([toc, PageBreak()])
    heading_number, first_chapter = 0, True

    def append_parsed(parsed, workbook=False):
        nonlocal heading_number, first_chapter
        for block in parsed:
            kind = block[0]
            if kind == "heading":
                _, level, text = block
                if level == 1:
                    continue
                if level == 2 and not workbook:
                    if not first_chapter:
                        story.append(PageBreak())
                    first_chapter = False
                    heading_number += 1
                    paragraph = Paragraph(rich(text), styles["StudyH2"])
                    paragraph.toc_key = "chapter-" + str(heading_number)
                    story.append(paragraph)
                else:
                    story.append(Paragraph(rich(text), styles["StudyH3"]))
            elif kind == "paragraph":
                story.append(Paragraph(rich(block[1]), styles["StudyBody"]))
            elif kind == "list":
                for number, text in enumerate(block[2], 1):
                    prefix = str(number) + ". " if block[1] else "- "
                    story.append(Paragraph(rich(prefix + text), styles["StudyBody"]))
            elif kind == "code":
                # Monospaced snippets are visually wrapped, never silently truncated.
                wrapped = []
                for line in clean(block[2]).splitlines():
                    wrapped.extend(textwrap.wrap(line, width=96, subsequent_indent="  ", expand_tabs=True, replace_whitespace=False, drop_whitespace=False) or [""])
                story.append(Preformatted("\n".join(wrapped), styles["StudyCode"]))
            elif kind == "table":
                rows = block[1]
                cols = len(rows[0])
                if cols == 2:
                    col_widths = [content_width * .35, content_width * .65]
                else:
                    col_widths = [content_width / cols] * cols
                data = [[Paragraph(rich(cell), styles["StudyHead"] if row_index == 0 else styles["StudyCell"]) for cell in row] for row_index, row in enumerate(rows)]
                table = Table(data, colWidths=col_widths, repeatRows=1, hAlign="LEFT")
                table.setStyle(TableStyle([("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#eaf1f4")), ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f7f9fa")]), ("GRID", (0, 0), (-1, -1), .4, colors.HexColor("#dce5e9")), ("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 8), ("RIGHTPADDING", (0, 0), (-1, -1), 8), ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 7)]))
                story.extend([table, Spacer(1, 13)])
    append_parsed(guide_blocks)
    story.append(PageBreak())
    appendix = Paragraph("Lampiran - Latihan dan Pembahasan", styles["StudyH2"]); appendix.toc_key = "workbook"
    story.append(appendix)
    append_parsed(workbook_blocks, workbook=True)
    doc.multiBuild(story)
    return output

if __name__ == "__main__":
    guide = render_markdown("PANDUAN_GLOWBOOK.md", "Belajar Membuat GlowBook", "Dari dasar Ruby dan MVC menuju marketplace, booking, integrasi dan delivery remote. Contoh kecil dahulu; kode project dibaca lewat atlas.")
    workbook = render_markdown("LATIHAN_DAN_JAWABAN.md", "Latihan dan Pembahasan", "18 latihan untuk melatih pemahaman. Kerjakan pada project/database latihan, lalu jelaskan input, proses, output dan batasnya.")
    index = build_atlas()
    pdf = build_pdf(guide, workbook)
    stats = {"snapshot": SNAPSHOT, "source_files": len(index), "source_lines": sum(item["lines"] for item in index), "guide_words": len((OUT / "PANDUAN_GLOWBOOK.md").read_text(encoding="utf-8").split()), "pdf": str(pdf)}
    print(json.dumps(stats, ensure_ascii=False))
