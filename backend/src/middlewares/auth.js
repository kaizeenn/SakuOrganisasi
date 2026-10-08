import jwt from 'jsonwebtoken';
import config from '../config/env.js';
import ApiError from '../utils/ApiError.js';
import prisma from '../config/prisma.js';

// Verifikasi JWT dari header Authorization: Bearer <token>
// dan lampirkan user ke req.user (tanpa passwordHash).
const authenticate = async (req, _res, next) => {
  try {
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');

    if (!scheme || scheme.toLowerCase() !== 'bearer' || !token) {
      throw new ApiError(401, 'Token tidak ditemukan. Kirim header: Authorization: Bearer <token>');
    }

    let payload;
    try {
      payload = jwt.verify(token, config.jwt.secret);
    } catch (e) {
      throw new ApiError(401, 'Token tidak valid atau sudah kedaluwarsa');
    }

    const userId = payload?.sub;
    if (!userId) throw new ApiError(401, 'Token tidak valid (missing sub)');

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, name: true, username: true, isActive: true },
    });

    if (!user) throw new ApiError(401, 'User tidak ditemukan');
    if (!user.isActive) throw new ApiError(403, 'Akun nonaktif. Hubungi admin.');

    req.user = user;
    next();
  } catch (err) {
    next(err);
  }
};

export default authenticate;
