import asyncHandler from '../utils/asyncHandler.js';
import prisma from '../config/prisma.js';
import ApiError from '../utils/ApiError.js';
import cashService, { periodSchema, payCashSchema } from '../services/cash.service.js';

// ===== Periode Kas =====

const listPeriods = asyncHandler(async (req, res) => {
  const { status } = req.query;
  const where = status ? { status } : {};
  const periods = await prisma.cashPeriod.findMany({
    where,
    orderBy: { startDate: 'desc' },
    include: { _count: { select: { cashLogs: true } } },
  });
  res.json({ success: true, data: { periods } });
});

const getPeriod = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const period = await prisma.cashPeriod.findUnique({
    where: { id },
    include: { cashLogs: { include: { member: true, transaction: true } } },
  });
  if (!period) throw ApiError.notFound('Periode kas tidak ditemukan');
  res.json({ success: true, data: { period } });
});

const createPeriod = asyncHandler(async (req, res) => {
  const period = await cashService.createPeriod({ data: req.body, userId: req.user.id });
  res.status(201).json({ success: true, message: 'Periode kas dibuat', data: { period } });
});

const updatePeriod = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const parsed = periodSchema.partial().parse(req.body);
  if (parsed.endDate && parsed.startDate && parsed.endDate < parsed.startDate) {
    throw ApiError.badRequest('endDate harus setelah startDate');
  }
  const period = await prisma.cashPeriod.update({ where: { id }, data: parsed });
  res.json({ success: true, message: 'Periode kas diperbarui', data: { period } });
});

const deletePeriod = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const count = await prisma.cashLog.count({ where: { periodId: id } });
  if (count > 0) {
    throw ApiError.badRequest(`Tidak bisa hapus: masih ada ${count} catatan pembayaran pada periode ini`);
  }
  await prisma.cashPeriod.delete({ where: { id } });
  res.json({ success: true, message: 'Periode kas dihapus' });
});

// ===== Checklist pembayaran per periode =====
// GET /cash/periods/:id/checklist → daftar semua anggota + status bayar
const getChecklist = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const period = await prisma.cashPeriod.findUnique({ where: { id } });
  if (!period) throw ApiError.notFound('Periode kas tidak ditemukan');

  const [members, cashLogs] = await Promise.all([
    prisma.member.findMany({ orderBy: { name: 'asc' } }),
    prisma.cashLog.findMany({ where: { periodId: id }, include: { transaction: true } }),
  ]);

  const logMap = new Map(cashLogs.map((cl) => [cl.memberId, cl]));

  const checklist = members.map((m) => {
    const log = logMap.get(m.id);
    return {
      memberId: m.id,
      memberName: m.name,
      phoneNumber: m.phoneNumber,
      paid: !!log,
      amount: log?.transaction?.amount ?? 0,
      transactionId: log?.transactionId ?? null,
      cashLogId: log?.id ?? null,
      paidAt: log?.transaction?.transactionDate ?? null,
    };
  });

  const totalPaid = checklist.reduce((sum, c) => sum + c.amount, 0);
  const paidCount = checklist.filter((c) => c.paid).length;

  res.json({
    success: true,
    data: {
      period,
      checklist,
      summary: {
        totalMembers: members.length,
        paidCount,
        unpaidCount: members.length - paidCount,
        totalCollected: totalPaid,
      },
    },
  });
});

// ===== CashLog =====

const listLogs = asyncHandler(async (req, res) => {
  const { periodId, memberId } = req.query;
  const where = {};
  if (periodId) where.periodId = Number(periodId);
  if (memberId) where.memberId = Number(memberId);

  const logs = await prisma.cashLog.findMany({
    where,
    include: { member: true, transaction: true, period: true, createdBy: { select: { id: true, name: true } } },
    orderBy: { id: 'desc' },
  });
  res.json({ success: true, data: { cashLogs: logs } });
});

// Anggota membayar kas (buat transaksi + cashLog)
const pay = asyncHandler(async (req, res) => {
  const parsed = payCashSchema.parse({
    ...req.body,
    transactionDate: req.body.transactionDate || new Date().toISOString(),
  });
  const cashLog = await cashService.memberPay({ data: parsed, userId: req.user.id });
  res.status(201).json({ success: true, message: 'Pembayaran kas tercatat', data: { cashLog } });
});

// Hapus catatan pembayaran (juga menghapus transaksi terkait + reverse saldo)
const deleteLog = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const log = await prisma.cashLog.findUnique({ where: { id } });
  if (!log) throw ApiError.notFound('Catatan kas tidak ditemukan');

  const { transactionService } = await import('../services/transaction.service.js');
  await transactionService.remove({ id: log.transactionId });
  res.json({ success: true, message: 'Catatan kas dihapus & saldo dikembalikan' });
});

export default {
  listPeriods,
  getPeriod,
  createPeriod,
  updatePeriod,
  deletePeriod,
  getChecklist,
  listLogs,
  pay,
  deleteLog,
};
