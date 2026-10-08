import asyncHandler from '../utils/asyncHandler.js';
import authService, { registerSchema, loginSchema } from '../services/auth.service.js';
import ApiError from '../utils/ApiError.js';

const register = asyncHandler(async (req, res) => {
  const parsed = registerSchema.parse(req.body);
  const { user, token } = await authService.register(parsed);
  res.status(201).json({ success: true, message: 'Registrasi berhasil', data: { user, token } });
});

const login = asyncHandler(async (req, res) => {
  const parsed = loginSchema.parse(req.body);
  const { user, token } = await authService.login(parsed);
  res.json({ success: true, message: 'Login berhasil', data: { user, token } });
});

const me = asyncHandler(async (req, res) => {
  const user = await authService.me(req.user.id);
  res.json({ success: true, data: { user } });
});

export default { register, login, me };
