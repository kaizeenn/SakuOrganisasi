# Backend SakuOrganisasi (Node.js + Express + Prisma)

Backend REST API untuk aplikasi **SakuOrganisasi** (APK Bendahara HMPS — Flutter). Mendukung **login multi-user** dengan JWT + role-based access control, serta CRUD lengkap untuk data keuangan organisasi (akun, kategori, event/proker, anggota, transaksi, kas anggota, dashboard).

## Teknologi

| Bagian | Teknologi |
|---|---|
| Runtime | Node.js 18+ (dibuat & dites di Node 22) |
| Framework | Express 4 |
| ORM | Prisma 6 |
| Database default | SQLite (mudah diganti PostgreSQL/MySQL via `DATABASE_URL`) |
| Auth | JWT (`jsonwebtoken`) + `bcryptjs` hash password |
| Validasi | Zod |
| Keamanan | `helmet`, `cors`, role middleware |

## Struktur Folder

```
backend/
├── package.json
├── .env.example          ← template environment
├── prisma/
│   ├── schema.prisma     ← skema database (User + tabel aplikasi)
│   └── seed.js           ← seed admin default + kategori/akun awal
└── src/
    ├── server.js         ← entrypoint
    ├── app.js            ← konfigurasi Express + mounting routes
    ├── config/
    │   ├── env.js
    │   └── prisma.js
    ├── middlewares/
    │   ├── auth.js       ← verifikasi JWT → req.user
    │   ├── role.js       ← authorize('admin', 'treasurer')
    │   └── errorHandler.js
    ├── utils/
    │   ├── ApiError.js
    │   └── asyncHandler.js
    ├── services/
    │   ├── auth.service.js
    │   ├── transaction.service.js   ← logika update saldo akun
    │   └── cash.service.js
    ├── controllers/
    │   ├── auth.controller.js
    │   ├── user.controller.js
    │   ├── account.controller.js
    │   ├── category.controller.js
    │   ├── event.controller.js
    │   ├── member.controller.js
    │   ├── transaction.controller.js
    │   ├── cash.controller.js
    │   └── dashboard.controller.js
    └── routes/
        ├── auth.routes.js
        ├── user.routes.js
        ├── account.routes.js
        ├── category.routes.js
        ├── event.routes.js
        ├── member.routes.js
        ├── transaction.routes.js
        ├── cash.routes.js
        └── dashboard.routes.js
```

## Setup Cepat

```bash
cd backend
npm run setup        # install deps + generate prisma + push db + seed
npm run dev          # jalankan dengan auto-reload (node --watch)
```

Setelah jalan, server di `http://localhost:3000`. Cek:

```bash
curl http://localhost:3000/
curl http://localhost:3000/api
```

> **Catatan konfigurasi:** `.env` sudah dibuat otomatis dari `.env.example` saat pertama kali. Ubah nilai `JWT_SECRET` dan kredensial admin sebelum produksi.

## Multi-User & Role

Setiap user punya salah satu role:

| Role | Akses |
|---|---|
| `admin` | Semua operasi + kelola user lain (CRUD user) |
| `treasurer` | CRUD transaksi, kas, master data. Tidak bisa kelola user / hapus master yang sensitif |
| `viewer` | Read-only (GET semua endpoint) |

**User pertama yang registrasi otomatis jadi `admin`** (selama belum ada user sama sekali). Setelah itu hanya admin yang bisa membuat user baru via `POST /api/users` (atau user bisa registrasi sendiri via `POST /api/auth/register`, default role `treasurer`).

Setiap transaksi & cashLog dicatat `createdByUserId` (audit trail — siapa bendahara yang input).

## Autentikasi

Semua endpoint (kecuali `/auth/register`, `/auth/login`, `/` health check) butuh header:

```
Authorization: Bearer <jwt-token>
```

### Login

```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@hmps.local","password":"admin123"}'
```

Response:

```json
{
  "success": true,
  "message": "Login berhasil",
  "data": {
    "user": { "id": 1, "name": "Bendahara Utama", "email": "admin@hmps.local", "role": "admin", "isActive": true },
    "token": "eyJhbGciOi..."
  }
}
```

### Register (user baru)

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Andi","email":"andi@hmps.local","password":"rahasia123","role":"treasurer"}'
```

### Profil sendiri

```bash
curl http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer <token>"
```

### Kelola user (admin)

```bash
# List
curl http://localhost:3000/api/users -H "Authorization: Bearer <admin-token>"
# Buat user baru
curl -X POST http://localhost:3000/api/users \
  -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" \
  -d '{"name":"Budi","email":"budi@hmps.local","password":"rahasia123","role":"treasurer"}'
# Update (mis. ganti role / nonaktifkan)
curl -X PATCH http://localhost:3000/api/users/2 \
  -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" \
  -d '{"isActive":false}'
# Soft delete
curl -X DELETE http://localhost:3000/api/users/2 \
  -H "Authorization: Bearer <admin-token>"
```

> Sistem melindungi admin terakhir: tidak bisa dihapus/dinonaktifkan/diturunkan rolenya jika itu satu-satunya admin aktif.

## Ringkasan Endpoint

Base URL: `/api`

| Resource | Endpoint | Ket |
|---|---|---|
| Auth | `POST /auth/register`, `POST /auth/login`, `GET /auth/me` | Register, login, profil |
| Users | `GET/POST /users`, `PATCH/DELETE /users/:id` | Admin only |
| Accounts | `GET/POST /accounts`, `GET/PATCH/DELETE /accounts/:id` | Rekening/dompet |
| Categories | `GET/POST /categories`, `GET/PATCH/DELETE /categories/:id` | Income/Expense/Transfer |
| Events | `GET/POST /events`, `GET/PATCH/DELETE /events/:id` | Proker |
| Members | `GET/POST /members`, `GET/PATCH/DELETE /members/:id` | Anggota |
| Transactions | `GET/POST /transactions`, `GET/PATCH/DELETE /transactions/:id` | Income/Expense/Transfer + auto-update saldo |
| Cash Periods | `GET/POST /cash/periods`, `GET/PATCH/DELETE /cash/periods/:id` | Periode kas |
| Cash Checklist | `GET /cash/periods/:id/checklist` | Status bayar per anggota |
| Cash Pay | `POST /cash/pay` | Tandai anggota bayar (buat transaksi + cashLog) |
| Cash Logs | `GET /cash/logs`, `DELETE /cash/logs/:id` | Riwayat & hapus pembayaran |
| Dashboard | `GET /dashboard/summary`, `GET /dashboard/by-category`, `GET /dashboard/monthly-trend` | Ringkasan & grafik |

### Contoh: Buat transaksi Income

```bash
curl -X POST http://localhost:3000/api/transactions \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{
    "amount": 50000,
    "type": "Income",
    "transactionDate": "2026-01-15",
    "description": "Iuran mingguan",
    "accountId": 1,
    "categoryId": 1,
    "memberId": 1
  }'
```

Saldo akun (`currentBalance`) otomatis terupdate: Income menambah, Expense mengurangi, Transfer mengurangi sumber & menambah tujuan. Update & delete transaksi juga akan menyesuaikan saldo secara konsisten dalam transaksi Prisma.

### Contoh: Anggota bayar kas periode

```bash
curl -X POST http://localhost:3000/api/cash/pay \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{
    "memberId": 1,
    "periodId": 1,
    "amount": 20000,
    "accountId": 1,
    "description": "Kas Januari"
  }'
```

Lihat checklist:

```bash
curl http://localhost:3000/api/cash/periods/1/checklist \
  -H "Authorization: Bearer <token>"
```

## Query Parameter Berguna

- Transactions: `?type=Income&accountId=1&startDate=2026-01-01&endDate=2026-01-31&search=donasi&page=1&limit=50`
- Categories: `?type=Expense`
- Members: `?search=Andi`
- Events: `?status=Active`
- Dashboard summary: `?startDate=2026-01-01&endDate=2026-01-31`

## Database

Default SQLite (`prisma/dev.db`). Untuk PostgreSQL:

1. Edit `prisma/schema.prisma` → ubah `provider = "postgresql"`.
2. Set `DATABASE_URL="postgresql://user:pass@localhost:5432/saku_db"` di `.env`.
3. `npm run db:migrate deploy`.

Perintah berguna:

```bash
npm run db:studio    # buka Prisma Studio (GUI browse data)
npm run db:migrate   # buat migrasi baru (development)
npm run db:push      # sync skema ke DB tanpa migrasi (cepat untuk dev)
npm run db:seed      # ulang seed admin + data default
```

## Integrasi dengan Aplikasi Flutter

Backend ini menyediakan API untuk aplikasi Flutter `apk_bendahara`. Saat ini aplikasi masih **offline-first** (Drift/SQLite lokal). Untuk migrasi ke backend:

1. Ganti `local_auth` biometrik-only di `lib/screens/auth_screen.dart` dengan layar login email+password yang memanggil `POST /api/auth/login` dan menyimpan JWT (mis. via `shared_preferences`).
2. Tambah header `Authorization: Bearer <jwt>` di `dio`/`http` client.
3. Buat repository API yang menggantikan/melengkapi `lib/repositories/*` dan `lib/database/*` (bisa hybrid: sync lokal ↔ server).
4. Gunakan endpoint dashboard untuk mengganti provider lokal di `lib/providers/dashboard_providers.dart`.

## Keamanan — Catatan Produksi

- Ganti `JWT_SECRET` dengan string acak panjang (≥ 32 karakter).
- Set `CORS_ORIGIN` ke domain aplikasi (jangan `*`).
- Ganti password admin default (`SEED_ADMIN_PASSWORD`).
- Gunakan HTTPS (reverse proxy: Nginx/Caddy).
- Pertimbangkan refresh token + token rotation untuk skala besar.
- Jangan push `.env` dan `prisma/dev.db` (sudah di `.gitignore`).

## Lisensi

Internal/Private — sesuai proyek SakuOrganisasi.
