import { z } from 'zod';
import asyncHandler from '../utils/asyncHandler.js';
import prisma from '../config/prisma.js';
import ApiError from '../utils/ApiError.js';

const memberSchema = z.object({
  name: z.string().min(1).max(150),
  phoneNumber: z.string().max(30).default(''),
});

const list = asyncHandler(async (req, res) => {
  const { search } = req.query;
  const where = search
    ? {
        OR: [
          { name: { contains: search } },
          { phoneNumber: { contains: search } },
        ],
      }
    : {};
  const members = await prisma.member.findMany({
    where,
    orderBy: { name: 'asc' },
    include: { _count: { select: { cashLogs: true } } },
  });
  res.json({ success: true, data: { members } });
});

const get = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const member = await prisma.member.findUnique({
    where: { id },
    include: { cashLogs: { include: { period: true }, orderBy: { id: 'desc' } } },
  });
  if (!member) throw ApiError.notFound('Anggota tidak ditemukan');
  res.json({ success: true, data: { member } });
});

const create = asyncHandler(async (req, res) => {
  const parsed = memberSchema.parse(req.body);
  const member = await prisma.member.create({ data: parsed });
  res.status(201).json({ success: true, message: 'Anggota dibuat', data: { member } });
});

const update = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const parsed = memberSchema.partial().parse(req.body);
  const member = await prisma.member.update({ where: { id }, data: parsed });
  res.json({ success: true, message: 'Anggota diperbarui', data: { member } });
});

const remove = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const cashCount = await prisma.cashLog.count({ where: { memberId: id } });
  if (cashCount > 0) {
    throw ApiError.badRequest(`Tidak bisa hapus: masih ada ${cashCount} catatan kas pada anggota ini`);
  }
  await prisma.member.delete({ where: { id } });
  res.json({ success: true, message: 'Anggota dihapus' });
});

export default { list, get, create, update, remove };
