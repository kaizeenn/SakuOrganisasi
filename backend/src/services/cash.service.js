import { z } from 'zod';
import asyncHandler from '../utils/asyncHandler.js';
import prisma from '../config/prisma.js';
import ApiError from '../utils/ApiError.js';
import transactionService from './transaction.service.js';

const periodSchema = z.object({
  name: z.string().min(1).max(100),
  startDate: z.coerce.date(),
  endDate: z.coerce.date(),
  status: z.enum(['Active', 'Closed']).default('Active'),
});

// Skema untuk anggota membayar kas pada periode tertentu.
// Akan membuat: Transaction (Income) + CashLog (member x period).
const payCashSchema = z.object({
  memberId: z.number().int().positive(),
  periodId: z.number().int().positive(),
  amount: z.number().int().positive(),
  accountId: z.number().int().positive(),
  categoryId: z.number().int().positive().optional(),
  transactionDate: z.coerce.date().optional(),
  description: z.string().max(300).default(''),
});

const cashService = {
  // Buat periode kas
  async createPeriod({ data, userId }) {
    const parsed = periodSchema.parse(data);
    if (parsed.endDate < parsed.startDate) {
      throw ApiError.badRequest('endDate harus setelah startDate');
    }
    return prisma.cashPeriod.create({
      data: { ...parsed, createdByUserId: userId },
      include: { _count: { select: { cashLogs: true } } },
    });
  },

  // Tandai pembayaran kas anggota untuk periode tertentu (idempoten: jika sudah ada, skip)
  async memberPay({ data, userId }) {
    const parsed = payCashSchema.parse({
      ...data,
      transactionDate: data.transactionDate || new Date().toISOString(),
    });

    const [member, period, account] = await Promise.all([
      prisma.member.findUnique({ where: { id: parsed.memberId } }),
      prisma.cashPeriod.findUnique({ where: { id: parsed.periodId } }),
      prisma.account.findUnique({ where: { id: parsed.accountId } }),
    ]);
    if (!member) throw ApiError.badRequest('Anggota tidak ditemukan');
    if (!period) throw ApiError.badRequest('Periode kas tidak ditemukan');
    if (!account) throw ApiError.badRequest('Akun tidak ditemukan');

    // Cek apakah sudah bayar di periode ini
    const existing = await prisma.cashLog.findUnique({
      where: { memberId_periodId: { memberId: parsed.memberId, periodId: parsed.periodId } },
    });
    if (existing) {
      throw ApiError.conflict('Anggota sudah tercatat bayar untuk periode ini');
    }

    // Ambil kategori Income default (atau cari kategori "Iuran Anggota")
    let categoryId = parsed.categoryId;
    if (!categoryId) {
      const cat = await prisma.category.findFirst({
        where: { OR: [{ name: { contains: 'Iuran' } }, { type: 'Income' }] },
        orderBy: { id: 'asc' },
      });
      if (!cat) throw ApiError.badRequest('Tidak ada kategori Income. Buat dulu.');
      categoryId = cat.id;
    }

    // Buat transaksi Income (akan update saldo via transactionService)
    const transaction = await transactionService.create({
      data: {
        amount: parsed.amount,
        type: 'Income',
        transactionDate: parsed.transactionDate,
        description: parsed.description || `Kas ${period.name} - ${member.name}`,
        accountId: parsed.accountId,
        categoryId,
        memberId: parsed.memberId,
      },
      userId,
    });

    // Buat cashLog
    const cashLog = await prisma.cashLog.create({
      data: {
        memberId: parsed.memberId,
        transactionId: transaction.id,
        periodId: parsed.periodId,
        createdByUserId: userId,
      },
      include: { member: true, transaction: true, period: true },
    });

    return cashLog;
  },

  // Toggle (centang / hapus centang) pembayaran anggota untuk periode
  async togglePay({ memberId, periodId, userId }) {
    const existing = await prisma.cashLog.findUnique({
      where: { memberId_periodId: { memberId, periodId } },
    });

    if (existing) {
      // Hapus centang → hapus cashLog + transaksi terkait (reverse saldo)
      await transactionService.remove({ id: existing.transactionId });
      return { paid: false };
    }
    // Tidak ada auto-create di sini karena butuh amount & accountId.
    // Gunakan endpoint POST /cash/pay untuk membuat pembayaran baru.
    throw ApiError.badRequest('Belum ada pembayaran. Gunakan POST /cash/pay dengan amount & accountId.');
  },
};

export default cashService;
export { periodSchema, payCashSchema };
