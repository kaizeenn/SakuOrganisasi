import asyncHandler from '../utils/asyncHandler.js';
import prisma from '../config/prisma.js';
import ApiError from '../utils/ApiError.js';
import transactionService, { transactionCreateSchema } from '../services/transaction.service.js';

const list = asyncHandler(async (req, res) => {
  const {
    type,
    accountId,
    categoryId,
    eventId,
    memberId,
    startDate,
    endDate,
    search,
    page = 1,
    limit = 50,
  } = req.query;

  const where = {};
  if (type) where.type = type;
  if (accountId) where.accountId = Number(accountId);
  if (categoryId) where.categoryId = Number(categoryId);
  if (eventId) where.eventId = Number(eventId);
  if (memberId) where.memberId = Number(memberId);
  if (startDate || endDate) {
    where.transactionDate = {};
    if (startDate) where.transactionDate.gte = new Date(startDate);
    if (endDate) where.transactionDate.lte = new Date(endDate);
  }
  if (search) where.description = { contains: search };

  const take = Math.min(Number(limit) || 50, 200);
  const skip = (Number(page) - 1) * take;

  const [items, total] = await Promise.all([
    prisma.transaction.findMany({
      where,
      include: {
        account: { select: { id: true, name: true } },
        transferAccount: { select: { id: true, name: true } },
        category: { select: { id: true, name: true, type: true } },
        event: { select: { id: true, name: true } },
        member: { select: { id: true, name: true } },
        createdBy: { select: { id: true, name: true } },
      },
      orderBy: { transactionDate: 'desc' },
      take,
      skip,
    }),
    prisma.transaction.count({ where }),
  ]);

  res.json({
    success: true,
    data: { transactions: items, pagination: { page: Number(page), limit: take, total, totalPages: Math.ceil(total / take) } },
  });
});

const get = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const transaction = await prisma.transaction.findUnique({
    where: { id },
    include: {
      account: true,
      transferAccount: true,
      category: true,
      event: true,
      member: true,
      createdBy: { select: { id: true, name: true } },
    },
  });
  if (!transaction) throw ApiError.notFound('Transaksi tidak ditemukan');
  res.json({ success: true, data: { transaction } });
});

const create = asyncHandler(async (req, res) => {
  const parsed = transactionCreateSchema.parse(req.body);
  const transaction = await transactionService.create({ data: parsed, userId: req.user.id });
  res.status(201).json({ success: true, message: 'Transaksi dibuat', data: { transaction } });
});

const update = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const transaction = await transactionService.update({ id, data: req.body, userId: req.user.id });
  res.json({ success: true, message: 'Transaksi diperbarui', data: { transaction } });
});

const remove = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  await transactionService.remove({ id });
  res.json({ success: true, message: 'Transaksi dihapus' });
});

export default { list, get, create, update, remove };
