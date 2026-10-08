import { z } from 'zod';
import asyncHandler from '../utils/asyncHandler.js';
import prisma from '../config/prisma.js';
import ApiError from '../utils/ApiError.js';

const accountSchema = z.object({
  name: z.string().min(1).max(100),
  type: z.enum(['Bank', 'E-Wallet', 'Cash']),
  initialBalance: z.number().int().min(0).default(0),
  currentBalance: z.number().int().min(0).default(0),
  iconKey: z.string().max(50).default('default'),
});

const list = asyncHandler(async (req, res) => {
  const accounts = await prisma.account.findMany({ orderBy: { id: 'asc' } });
  res.json({ success: true, data: { accounts } });
});

const get = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const account = await prisma.account.findUnique({ where: { id } });
  if (!account) throw ApiError.notFound('Akun tidak ditemukan');
  res.json({ success: true, data: { account } });
});

const create = asyncHandler(async (req, res) => {
  const parsed = accountSchema.parse(req.body);
  const account = await prisma.account.create({ data: parsed });
  res.status(201).json({ success: true, message: 'Akun dibuat', data: { account } });
});

const update = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const parsed = accountSchema.partial().parse(req.body);
  const account = await prisma.account.update({ where: { id }, data: parsed });
  res.json({ success: true, message: 'Akun diperbarui', data: { account } });
});

const remove = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  // Cek apakah masih dipakai transaksi
  const txCount = await prisma.transaction.count({
    where: { OR: [{ accountId: id }, { transferAccountId: id }] },
  });
  if (txCount > 0) {
    throw ApiError.badRequest(
      `Tidak bisa hapus akun: masih terkait ${txCount} transaksi. Pindahkan histori dulu.`
    );
  }
  await prisma.account.delete({ where: { id } });
  res.json({ success: true, message: 'Akun dihapus' });
});

export default { list, get, create, update, remove };
