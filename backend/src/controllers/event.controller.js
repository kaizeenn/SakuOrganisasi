import { z } from 'zod';
import asyncHandler from '../utils/asyncHandler.js';
import prisma from '../config/prisma.js';
import ApiError from '../utils/ApiError.js';

const eventSchema = z.object({
  name: z.string().min(1).max(150),
  budgetLimit: z.number().int().min(0).default(0),
  status: z.enum(['Active', 'Finished']).default('Active'),
  startDate: z.coerce.date(),
  endDate: z.coerce.date().nullable().optional(),
});

const list = asyncHandler(async (req, res) => {
  const { status } = req.query;
  const where = status ? { status } : {};
  const events = await prisma.event.findMany({
    where,
    orderBy: { startDate: 'desc' },
    include: { _count: { select: { transactions: true } } },
  });
  res.json({ success: true, data: { events } });
});

const get = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const event = await prisma.event.findUnique({
    where: { id },
    include: { _count: { select: { transactions: true } } },
  });
  if (!event) throw ApiError.notFound('Event tidak ditemukan');
  res.json({ success: true, data: { event } });
});

const create = asyncHandler(async (req, res) => {
  const parsed = eventSchema.parse(req.body);
  const event = await prisma.event.create({ data: parsed });
  res.status(201).json({ success: true, message: 'Event dibuat', data: { event } });
});

const update = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const parsed = eventSchema.partial().parse(req.body);
  const event = await prisma.event.update({ where: { id }, data: parsed });
  res.json({ success: true, message: 'Event diperbarui', data: { event } });
});

const remove = asyncHandler(async (req, res) => {
  const id = Number(req.params.id);
  const txCount = await prisma.transaction.count({ where: { eventId: id } });
  if (txCount > 0) {
    throw ApiError.badRequest(`Tidak bisa hapus: masih ada ${txCount} transaksi pada event ini`);
  }
  await prisma.event.delete({ where: { id } });
  res.json({ success: true, message: 'Event dihapus' });
});

export default { list, get, create, update, remove };
