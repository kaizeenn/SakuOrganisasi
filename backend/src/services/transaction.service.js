import { z } from 'zod';
import prisma from '../config/prisma.js';
import ApiError from '../utils/ApiError.js';

const transactionBaseSchema = z.object({
  amount: z.number().int().positive('Jumlah harus > 0'),
  type: z.enum(['Income', 'Expense', 'Transfer']),
  transactionDate: z.coerce.date(),
  description: z.string().max(500).default(''),
  proofImage: z.string().url().nullable().optional(),
  accountId: z.number().int().positive(),
  transferAccountId: z.number().int().positive().nullable().optional(),
  categoryId: z.number().int().positive(),
  eventId: z.number().int().positive().nullable().optional(),
  memberId: z.number().int().positive().nullable().optional(),
});

const transactionCreateSchema = transactionBaseSchema.refine((d) => {
  if (d.type === 'Transfer') return !!d.transferAccountId && d.transferAccountId !== d.accountId;
  return !d.transferAccountId;
}, {
  message: 'Transfer wajib punya transferAccountId dan tidak boleh sama dengan accountId',
  path: ['transferAccountId'],
});

const transactionUpdateSchema = transactionBaseSchema.partial();

// Update saldo akun sesuai tipe transaksi. Dijalankan dalam $transaction Prisma.
function applySaldoDelta(tx, { accountId, transferAccountId, amount, type, reverse = false }) {
  const dir = reverse ? -1 : 1;
  const ops = [];

  if (type === 'Income') {
    ops.push(tx.account.update({ where: { id: accountId }, data: { currentBalance: { increment: amount * dir } } }));
  } else if (type === 'Expense') {
    ops.push(tx.account.update({ where: { id: accountId }, data: { currentBalance: { decrement: amount * dir } } }));
  } else if (type === 'Transfer') {
    ops.push(tx.account.update({ where: { id: accountId }, data: { currentBalance: { decrement: amount * dir } } }));
    ops.push(tx.account.update({ where: { id: transferAccountId }, data: { currentBalance: { increment: amount * dir } } }));
  }
  return ops;
}

const transactionService = {
  async create({ data, userId }) {
    const parsed = transactionCreateSchema.parse(data);

    // Validasi referensi
    const [account, transferAccount, category] = await Promise.all([
      prisma.account.findUnique({ where: { id: parsed.accountId } }),
      parsed.transferAccountId ? prisma.account.findUnique({ where: { id: parsed.transferAccountId } }) : Promise.resolve(null),
      prisma.category.findUnique({ where: { id: parsed.categoryId } }),
    ]);
    if (!account) throw ApiError.badRequest('Akun tidak ditemukan');
    if (parsed.transferAccountId && !transferAccount) throw ApiError.badRequest('Akun transfer tidak ditemukan');
    if (!category) throw ApiError.badRequest('Kategori tidak ditemukan');

    const result = await prisma.$transaction(async (tx) => {
      const transaction = await tx.transaction.create({
        data: { ...parsed, createdByUserId: userId },
      });
      // Update saldo
      await Promise.all(applySaldoDelta(tx, { ...parsed, reverse: false }));
      return transaction;
    });

    return prisma.transaction.findUnique({
      where: { id: result.id },
      include: { account: true, transferAccount: true, category: true, event: true, member: true, createdBy: { select: { id: true, name: true } } },
    });
  },

  async update({ id, data, userId }) {
    const parsed = transactionUpdateSchema.parse(data);

    const existing = await prisma.transaction.findUnique({ where: { id } });
    if (!existing) throw ApiError.notFound('Transaksi tidak ditemukan');

    // Bangun data final untuk perhitungan saldo
    const finalAmount = parsed.amount ?? existing.amount;
    const finalType = parsed.type ?? existing.type;
    const finalAccountId = parsed.accountId ?? existing.accountId;
    const finalTransferAccountId = parsed.transferAccountId ?? existing.transferAccountId;

    // Validasi referensi baru
    if (parsed.accountId) {
      const a = await prisma.account.findUnique({ where: { id: parsed.accountId } });
      if (!a) throw ApiError.badRequest('Akun baru tidak ditemukan');
    }
    if (parsed.transferAccountId) {
      const a = await prisma.account.findUnique({ where: { id: parsed.transferAccountId } });
      if (!a) throw ApiError.badRequest('Akun transfer baru tidak ditemukan');
    }
    if (parsed.categoryId) {
      const c = await prisma.category.findUnique({ where: { id: parsed.categoryId } });
      if (!c) throw ApiError.badRequest('Kategori baru tidak ditemukan');
    }

    const result = await prisma.$transaction(async (tx) => {
      // 1. Reverse saldo transaksi lama
      await Promise.all(
        applySaldoDelta(tx, {
          accountId: existing.accountId,
          transferAccountId: existing.transferAccountId,
          amount: existing.amount,
          type: existing.type,
          reverse: true,
        })
      );
      // 2. Apply saldo transaksi baru
      await Promise.all(
        applySaldoDelta(tx, {
          accountId: finalAccountId,
          transferAccountId: finalType === 'Transfer' ? finalTransferAccountId : null,
          amount: finalAmount,
          type: finalType,
          reverse: false,
        })
      );
      // 3. Update record
      const updated = await tx.transaction.update({ where: { id }, data: parsed });
      return updated;
    });

    return prisma.transaction.findUnique({
      where: { id: result.id },
      include: { account: true, transferAccount: true, category: true, event: true, member: true, createdBy: { select: { id: true, name: true } } },
    });
  },

  async remove({ id }) {
    const existing = await prisma.transaction.findUnique({ where: { id } });
    if (!existing) throw ApiError.notFound('Transaksi tidak ditemukan');

    await prisma.$transaction(async (tx) => {
      // Reverse saldo
      await Promise.all(
        applySaldoDelta(tx, {
          accountId: existing.accountId,
          transferAccountId: existing.transferAccountId,
          amount: existing.amount,
          type: existing.type,
          reverse: true,
        })
      );
      // Hapus cashLog terkait (jika ada) lalu transaksi
      await tx.cashLog.deleteMany({ where: { transactionId: id } });
      await tx.transaction.delete({ where: { id } });
    });
  },
};

export default transactionService;
export { transactionCreateSchema, transactionUpdateSchema };
