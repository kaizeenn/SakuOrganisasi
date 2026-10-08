import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const name = process.env.SEED_ADMIN_NAME || 'Bendahara Utama';
  const username = process.env.SEED_ADMIN_USERNAME || 'admin';
  const password = process.env.SEED_ADMIN_PASSWORD || 'admin123';
  const saltRounds = Number(process.env.BCRYPT_SALT_ROUNDS || 10);

  // Upsert agar idempoten — bisa dijalankan ulang tanpa error
  const passwordHash = await bcrypt.hash(password, saltRounds);

  // Upsert berdasarkan username (unique).
  const admin = await prisma.user.upsert({
    where: { username },
    update: { name, passwordHash, isActive: true },
    create: { name, username, passwordHash, isActive: true },
  });

  // Seed beberapa kategori default bila belum ada
  const existingCats = await prisma.category.count();
  if (existingCats === 0) {
    await prisma.category.createMany({
      data: [
        { name: 'Iuran Anggota', type: 'Income', iconKey: 'iuran' },
        { name: 'Donasi / Sponsor', type: 'Income', iconKey: 'donasi' },
        { name: 'Konsumsi', type: 'Expense', iconKey: 'konsumsi' },
        { name: 'Transportasi', type: 'Expense', iconKey: 'transport' },
        { name: 'ATK', type: 'Expense', iconKey: 'atk' },
        { name: 'Peralatan', type: 'Expense', iconKey: 'alat' },
        { name: 'Lainnya', type: 'Expense', iconKey: 'lainnya' },
        { name: 'Transfer', type: 'Transfer', iconKey: 'transfer' },
      ],
    });
    console.log('✓ Kategori default dibuat (8 kategori)');
  }

  // Seed akun default bila belum ada
  const existingAccs = await prisma.account.count();
  if (existingAccs === 0) {
    await prisma.account.createMany({
      data: [
        { name: 'Kas Tunai', type: 'Cash', initialBalance: 0, currentBalance: 0, iconKey: 'cash' },
        { name: 'Bank BCA', type: 'Bank', initialBalance: 0, currentBalance: 0, iconKey: 'bank' },
      ],
    });
    console.log('✓ Akun default dibuat (Kas Tunai, Bank BCA)');
  }

  console.log('────────────────────────────────────────');
  console.log('Seed selesai. Akun admin default:');
  console.log(`  Nama     : ${admin.name}`);
  console.log(`  Username : ${admin.username}`);
  console.log(`  Password : ${password}  (ubah lewat env SEED_ADMIN_PASSWORD)`);
  console.log('────────────────────────────────────────');
}

main()
  .catch((e) => {
    console.error('Seed gagal:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
