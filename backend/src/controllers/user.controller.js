import { z } from 'zod';
import asyncHandler from '../utils/asyncHandler.js';
import prisma from '../config/prisma.js';
import ApiError from '../utils/ApiError.js';

const userCreateSchema = z.object({
  name: z.string().min(2).max(100),
  username: z.string().min(3).max(40).regex(/^[a-zA-Z0-9._-]+$/, 'Username hanya boleh huruf, angka, titik, underscore, strip'),
  password: z.string().min(6).max(72),
  isActive: z.boolean().default(true),
});

const userUpdateSchema = z.object({
  name: z.string().min(2).max(100).optional(),
  username: z.string().min(3).max(40).regex(/^[a-zA-Z0-9._-]+$/).optional(),
  password: z.string().min(6).max(72).optional(),
  isActive: z.boolean().optional(),
});

// List semua user
const list = asyncHandler(async (req, res) => {
  const users = await prisma.user.findMany({
    select: { id: true, name: true, username: true, isActive: true, createdAt: true, updatedAt: true },
    orderBy: { id: 'asc' },
  });
  res.json({ success: true, data: { users } });
});

// Buat user baru
const create = asyncHandler(async (req, res) => {
  const parsed = userCreateSchema.parse(req.body);
  const exists = await prisma.user.findUnique({ where: { username: parsed.username } });
  if (exists) throw ApiError.conflict('Username sudah dipakai');

  const bcrypt = await import('bcryptjs');
  const cfg = (await import('../config/env.js')).default;
  const passwordHash = await bcrypt.default.hash(parsed.password, cfg.bcryptSaltRounds);

  const user = await prisma.user.create({
    data: {
      name: parsed.name,
      username: parsed.username,
      passwordHash,
      isActive: parsed.isActive,
    },
    select: { id: true, name: true, username: true, isActive: true, createdAt: true },
  });
  res.status(201).json({ success: true, message: 'User dibuat', data: { user } });
});

const update = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) throw ApiError.badRequest('ID tidak valid');

  const parsed = userUpdateSchema.parse(req.body);

  const target = await prisma.user.findUnique({ where: { id } });
  if (!target) throw ApiError.notFound('User tidak ditemukan');

  const data = { ...parsed };
  if (parsed.password) {
    const bcrypt = await import('bcryptjs');
    const cfg = (await import('../config/env.js')).default;
    data.passwordHash = await bcrypt.default.hash(parsed.password, cfg.bcryptSaltRounds);
    delete data.password;
  }

  const user = await prisma.user.update({
    where: { id },
    data,
    select: { id: true, name: true, username: true, isActive: true, updatedAt: true },
  });
  res.json({ success: true, message: 'User diperbarui', data: { user } });
});

// Soft delete: nonaktifkan, jangan hapus permanen (jaga audit trail)
const remove = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) throw ApiError.badRequest('ID tidak valid');

  if (id === req.user.id) throw ApiError.badRequest('Tidak bisa menghapus akun sendiri');

  const target = await prisma.user.findUnique({ where: { id } });
  if (!target) throw ApiError.notFound('User tidak ditemukan');

  await prisma.user.update({ where: { id }, data: { isActive: false } });
  res.json({ success: true, message: 'User dinonaktifkan (soft delete)' });
});

export default { list, create, update, remove };
