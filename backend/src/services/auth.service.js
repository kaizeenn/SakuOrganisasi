import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import prisma from '../config/prisma.js';
import config from '../config/env.js';
import ApiError from '../utils/ApiError.js';

export const registerSchema = z.object({
  name: z.string().min(2, 'Nama minimal 2 karakter').max(100),
  username: z.string().min(3, 'Username minimal 3 karakter').max(40).regex(/^[a-zA-Z0-9._-]+$/, 'Username hanya boleh huruf, angka, titik, underscore, strip'),
  password: z.string().min(6, 'Password minimal 6 karakter').max(72),
});

export const loginSchema = z.object({
  login: z.string().min(1, 'Username wajib diisi'),
  password: z.string().min(1, 'Password wajib diisi'),
});

function signToken(user) {
  return jwt.sign(
    { sub: user.id, username: user.username, name: user.name },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn }
  );
}

const authService = {
  async register({ name, username, password }) {
    const existsUsername = await prisma.user.findUnique({ where: { username } });
    if (existsUsername) throw ApiError.conflict('Username sudah dipakai');

    const passwordHash = await bcrypt.hash(password, config.bcryptSaltRounds);

    const user = await prisma.user.create({
      data: { name, username, passwordHash },
      select: { id: true, name: true, username: true, isActive: true, createdAt: true },
    });

    const token = signToken(user);
    return { user, token };
  },

  async login({ login, password }) {
    // Cari user berdasarkan username.
    const user = await prisma.user.findUnique({ where: { username: login } });
    if (!user) throw ApiError.unauthorized('Username atau password salah');

    if (!user.isActive) throw ApiError.forbidden('Akun nonaktif. Hubungi admin.');

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) throw ApiError.unauthorized('Username atau password salah');

    const safeUser = {
      id: user.id,
      name: user.name,
      username: user.username,
      isActive: user.isActive,
    };
    const token = signToken(safeUser);
    return { user: safeUser, token };
  },

  async me(userId) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, name: true, username: true, isActive: true, createdAt: true },
    });
    if (!user) throw ApiError.notFound('User tidak ditemukan');
    return user;
  },
};

export default authService;
