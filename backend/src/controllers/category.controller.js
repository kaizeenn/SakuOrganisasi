import { z } from 'zod';
import asyncHandler from '../utils/asyncHandler.js';
import prisma from '../config/prisma.js';
import ApiError from '../utils/ApiError.js';

const categorySchema = z.object({
  name: z.string().min(1).max(100),
  type: z.enum(['Income', 'Expense', 'Transfer']),
  iconKey: z.string().max(50).default('default'),
});

const list = asyncHandler(async (req, res) => {
  const { type } = req.query;
  const where = type ? { type } : {};
  const categories = await prisma.category.findMany({ where, orderBy: { id: 'asc' } });
  res.json({ success: true, data: { categories } });
});

const get = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const category = await prisma.category.findUnique({ where: { id } });
  if (!category) throw ApiError.notFound('Kategori tidak ditemukan');
  res.json({ success: true, data: { category } });
});

const create = asyncHandler(async (req, res) => {
  const parsed = categorySchema.parse(req.body);
  const category = await prisma.category.create({ data: parsed });
  res.status(201).json({ success: true, message: 'Kategori dibuat', data: { category } });
});

const update = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const parsed = categorySchema.partial().parse(req.body);
  const category = await prisma.category.update({ where: { id }, data: parsed });
  res.json({ success: true, message: 'Kategori diperbarui', data: { category } });
});

const remove = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const txCount = await prisma.transaction.count({ where: { categoryId: id } });
  if (txCount > 0) {
    throw ApiError.badRequest(`Tidak bisa hapus: masih dipakai ${txCount} transaksi`);
  }
  await prisma.category.delete({ where: { id } });
  res.json({ success: true, message: 'Kategori dihapus' });
});

export default { list, get, create, update, remove };
