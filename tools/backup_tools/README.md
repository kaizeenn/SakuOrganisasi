# Backup Tools

Tool untuk memvalidasi dan merapikan file backup JSON dari aplikasi.

## Normalize backup JSON

Jalankan dari root project:

`dart run tools/backup_tools/decrypt_backup.dart <input_file> [output_file]`

Contoh:

`dart run tools/backup_tools/decrypt_backup.dart /path/backup_bendahara_20260317_1200.json`

Jika `output_file` tidak diisi, hasil akan dibuat otomatis dengan suffix `_plain.json` di folder yang sama.

Tool ini membaca file JSON biasa lalu menuliskannya ulang dalam format JSON yang rapi.
