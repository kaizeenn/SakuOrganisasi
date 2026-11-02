# SakuOrganisasi Releases

Daftar APK yang pernah dibangun dan tersedia melalui GitHub Releases.

## Versi offline

| Versi | Status | Keterangan | Download |
|---|---|---|---|
| **v2.3.1** | **Offline / tanpa backend** | Versi terakhir yang memakai database lokal Drift. Dapat digunakan tanpa server backend. | [Download APK](https://github.com/kaizeenn/SakuOrganisasi/releases/tag/v2.3.1) |

> Untuk memakai data bersama melalui MySQL/VPS, gunakan versi online mulai v2.3.2.

## Versi online

| Versi | Status | Perubahan utama | Download |
|---|---|---|---|
| **v2.3.2** | Online | Migrasi aplikasi ke backend API; endpoint awal masih memakai alamat HTTPS sslip.io. | [Download APK](https://github.com/kaizeenn/SakuOrganisasi/releases/tag/v2.3.2) |
| **v2.3.4** | Online | API memakai HTTP port 80 melalui Caddy. | [Download APK](https://github.com/kaizeenn/SakuOrganisasi/releases/tag/v2.3.4) |
| **v2.3.5** | Online | Memperbaiki permission `INTERNET` pada release APK Android. | [Download APK](https://github.com/kaizeenn/SakuOrganisasi/releases/tag/v2.3.5) |
| **v2.3.6** | Online | Menambahkan filter periode grafik pengeluaran. | [Download APK](https://github.com/kaizeenn/SakuOrganisasi/releases/tag/v2.3.6) |
| **v2.3.7** | Online | Menambahkan pemilih bulan dan tahun untuk grafik pengeluaran. | [Download APK](https://github.com/kaizeenn/SakuOrganisasi/releases/tag/v2.3.7) |
| **v2.3.8** | Online | Memperbaiki pembersihan sesi JWT yang invalid atau kedaluwarsa. | Menunggu GitHub Actions selesai |

## Catatan versi

- **v2.3.1 adalah versi offline paling lama dan terakhir.** Versi ini tidak membaca data dari backend VPS.
- Mulai **v2.3.2**, aplikasi menggunakan backend API dan membutuhkan koneksi ke server.
- **v2.3.3 tidak dicantumkan sebagai release aktif** karena sudah ditarik setelah konfigurasi port lama dinyatakan tidak dipakai.
- APK pada halaman release adalah hasil build GitHub Actions untuk tag terkait.
