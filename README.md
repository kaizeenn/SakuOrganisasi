# APK Bendahara (HMPS)

Aplikasi mobile bendahara organisasi berbasis Flutter untuk pencatatan keuangan, kas anggota, monitoring kegiatan/proker, dan export laporan.

## Ringkasan

Project ini dirancang untuk kebutuhan operasional organisasi (default nama organisasi: **HMPS**) dengan pendekatan **offline-first** menggunakan database lokal SQLite (Drift).

Fokus utama:
- Pencatatan transaksi pemasukan, pengeluaran, dan transfer antar rekening.
- Pengelolaan kas anggota per periode.
- Rekap data yang mudah dibackup, dipulihkan, dan diexport.

## Fitur Utama

- **Dashboard keuangan**: ringkasan saldo, pemasukan, pengeluaran.
- **Manajemen transaksi**:
    - Income / Expense / Transfer antar rekening.
    - Filter transaksi dan detail berdasarkan akun/event.
- **Kas anggota**:
    - Buat periode kas.
    - Checklist pembayaran per anggota.
    - Total dana terkumpul per periode.
    - Print checklist pembayaran per periode (PDF).
- **Master data**:
    - Kelola rekening/dompet dan kategori.
    - Hapus akun dengan pemindahan histori transaksi ke akun pengganti.
- **Laporan & export**:
    - Export PDF.
    - Export Excel.
- **Backup & restore**:
    - Backup data ke file JSON biasa (plain JSON).
    - Restore dari JSON.
    - Mendukung format data lama melalui migrasi restore.
- **Keamanan aplikasi**:
    - Dukungan biometrik (`local_auth`).

## Teknologi

- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Database**: Drift + SQLite
- **Charts**: fl_chart
- **Document**: pdf, printing, excel
- **Storage & Sharing**: shared_preferences, file_picker, share_plus

## Struktur Folder (inti)

```text
lib/
    database/
    models/
    providers/
    repositories/
    screens/
    services/
    utils/
    widgets/
tools/
    backup_tools/
```

## Menjalankan Project (Developer)

### 1) Clone repository
```bash
git clone https://github.com/<username>/<repo>.git
cd <repo>
```

### 2) Install dependency
```bash
flutter pub get
```

### 3) Generate kode Drift
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4) Jalankan aplikasi
```bash
flutter run
```

## Build APK Release

```bash
flutter build apk --release
```

Output biasanya ada di: `build/app/outputs/flutter-apk/app-release.apk`

## Backup Tools

Folder: `tools/backup_tools/`

- Normalisasi JSON backup:
    ```bash
    dart run tools/backup_tools/decrypt_backup.dart <input_file> [output_file]
    ```
- Konversi JSON backup ke XLSX:
    ```bash
    dart run tools/backup_tools/json_to_xlsx.dart <input_json> [output_xlsx]
    ```

## Catatan Penting

- Nama organisasi default di aplikasi adalah **HMPS**.
- Data disimpan lokal (offline-first).
- Backup saat ini menggunakan **plain JSON** (tanpa enkripsi).

## Rekomendasi Sebelum Push ke GitHub

1. Jalankan:
     ```bash
     flutter analyze
     flutter test
     ```
2. Pastikan file sensitif tidak ikut ter-push.
3. Perbarui bagian ini jika ada fitur baru.

## License

Private/Internal project.