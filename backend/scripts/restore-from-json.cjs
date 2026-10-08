// scripts/restore-from-json.js
// Restore data dari backup JSON (ekspor SQLite/Drift dari app Flutter)
// ke MySQL via Prisma. Dipanggil: node scripts/restore-from-json.js [path-json]
//
// - ID eksplisit dipertahankan agar relasi FK tetap utuh.
// - createdByUserId di-set ke admin (id=1) untuk Transaction & CashLog,
//   dan CashPeriod (optional) — sebagai audit trail "di-input oleh bendahara".
// - Data lama (non-User) di-clear dulu dalam transaksi yang sama (atomic).
// - CashLog yang menunjuk transaksi yang sudah dihapus (orphan) dilewati.

const fs = require('fs');
const path = require('path');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

function msToDate(ms) {
  if (ms == null) return null;
  return new Date(ms);
}

function num(v) {
  return v == null ? null : Number(v);
}

async function main() {
  const file =
    process.argv[2] || '/home/yume/Downloads/backup_bendahara_20261008_2000.json';
  console.log(`📥 Membaca backup: ${file}`);
  const raw = fs.readFileSync(file, 'utf8');
  const data = JSON.parse(raw);

  const {
    accounts = [],
    categories = [],
    events = [],
    members = [],
    transactions = [],
    cashLogs = [],
    cashPeriods = [],
  } = data;

  console.log(
    `   accounts=${accounts.length} categories=${categories.length} ` +
      `events=${events.length} members=${members.length} ` +
      `transactions=${transactions.length} cashPeriods=${cashPeriods.length} ` +
      `cashLogs=${cashLogs.length}`
  );

  // Validasi: user pertama harus ada (untuk audit trail createdByUserId)
  const admin = await prisma.user.findFirst({
    orderBy: { id: 'asc' },
    select: { id: true, name: true },
  });
  if (!admin) {
    throw new Error(
      'User tidak ditemukan. Jalankan `npm run seed` dulu.'
    );
  }
  const ADMIN_ID = admin.id;
  console.log(`👤 Admin (audit trail): id=${ADMIN_ID} name="${admin.name}"`);

  // Deteksi cashLog orphan (transactionId tidak ada di backup)
  const txIds = new Set(transactions.map((t) => t.id));
  const orphanCashLogs = cashLogs.filter((c) => !txIds.has(c.transactionId));
  const validCashLogs = cashLogs.filter((c) => txIds.has(c.transactionId));
  if (orphanCashLogs.length) {
    console.log(
      `⚠️  ${orphanCashLogs.length} cashLog orphan dilewati: ` +
        orphanCashLogs.map((c) => `#${c.id}→tx${c.transactionId}`).join(', ')
    );
  }

  // Siapkan data (dengan ID eksplisit + konversi tanggal)
  const accountsData = accounts.map((a) => ({
    id: a.id,
    name: a.name,
    type: a.type,
    initialBalance: num(a.initialBalance) ?? 0,
    currentBalance: num(a.currentBalance) ?? 0,
    iconKey: a.iconKey || 'default',
  }));

  const categoriesData = categories.map((c) => ({
    id: c.id,
    name: c.name,
    type: c.type,
    iconKey: c.iconKey || 'default',
  }));

  const membersData = members.map((m) => ({
    id: m.id,
    name: m.name,
    phoneNumber: m.phoneNumber ?? '',
  }));

  const eventsData = events.map((e) => ({
    id: e.id,
    name: e.name,
    budgetLimit: num(e.budgetLimit) ?? 0,
    status: e.status || 'Active',
    startDate: msToDate(e.startDate) || new Date(),
    endDate: msToDate(e.endDate),
  }));

  const cashPeriodsData = cashPeriods.map((p) => ({
    id: p.id,
    name: p.name,
    startDate: msToDate(p.startDate) || new Date(),
    endDate: msToDate(p.endDate) || new Date(),
    status: p.status || 'Active',
    createdAt: msToDate(p.createdAt) || new Date(),
    createdByUserId: ADMIN_ID,
  }));

  const transactionsData = transactions.map((t) => ({
    id: t.id,
    amount: num(t.amount),
    type: t.type,
    transactionDate: msToDate(t.transactionDate) || new Date(),
    description: t.description ?? '',
    proofImage: t.proofImage ?? null,
    accountId: t.accountId,
    transferAccountId: t.transferAccountId ?? null,
    categoryId: t.categoryId,
    eventId: t.eventId ?? null,
    memberId: t.memberId ?? null,
    createdByUserId: ADMIN_ID,
    createdAt: msToDate(t.transactionDate) || new Date(),
  }));

  const cashLogsData = validCashLogs.map((c) => ({
    id: c.id,
    memberId: c.memberId,
    transactionId: c.transactionId,
    periodLabel: c.periodLabel ?? null,
    periodId: c.periodId ?? null,
    createdByUserId: ADMIN_ID,
  }));

  console.log('🧹 Membersihkan data lama (non-User) + insert backup dalam 1 transaksi...');

  await prisma.$transaction([
    // 1. Clear (urutan FK-safe)
    prisma.cashLog.deleteMany(),
    prisma.transaction.deleteMany(),
    prisma.cashPeriod.deleteMany(),
    prisma.member.deleteMany(),
    prisma.event.deleteMany(),
    prisma.category.deleteMany(),
    prisma.account.deleteMany(),
    // 2. Insert master data
    prisma.account.createMany({ data: accountsData }),
    prisma.category.createMany({ data: categoriesData }),
    prisma.member.createMany({ data: membersData }),
    prisma.event.createMany({ data: eventsData }),
    prisma.cashPeriod.createMany({ data: cashPeriodsData }),
    // 3. Insert transaksi
    prisma.transaction.createMany({ data: transactionsData }),
    // 4. Insert cash logs (orphan sudah difilter)
    prisma.cashLog.createMany({ data: cashLogsData }),
  ]);

  // Reset AUTO_INCREMENT supaya id berikutnya lanjut dari max id
  const maxTx = transactions.reduce((m, t) => Math.max(m, t.id), 0);
  await prisma.$executeRawUnsafe(
    `ALTER TABLE \`Transaction\` AUTO_INCREMENT = ${maxTx + 1}`
  );
  const maxCl = validCashLogs.reduce((m, c) => Math.max(m, c.id), 0);
  if (maxCl > 0) {
    await prisma.$executeRawUnsafe(
      `ALTER TABLE \`CashLog\` AUTO_INCREMENT = ${maxCl + 1}`
    );
  }

  // Verifikasi
  const counts = {
    account: await prisma.account.count(),
    category: await prisma.category.count(),
    event: await prisma.event.count(),
    member: await prisma.member.count(),
    transaction: await prisma.transaction.count(),
    cashPeriod: await prisma.cashPeriod.count(),
    cashLog: await prisma.cashLog.count(),
  };
  console.log('✅ Selesai. Jumlah baris di MySQL sekarang:');
  console.log('   ', JSON.stringify(counts));

  // Sanity check saldo
  const accs = await prisma.account.findMany({
    orderBy: { id: 'asc' },
    select: { id: true, name: true, currentBalance: true },
  });
  console.log('💰 Saldo akun:');
  for (const a of accs) {
    console.log(`   id=${a.id} ${a.name}: Rp ${a.currentBalance.toLocaleString('id-ID')}`);
  }
}

main()
  .catch((e) => {
    console.error('❌ Gagal:', e.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
