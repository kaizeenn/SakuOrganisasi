import ApiError from '../utils/ApiError.js';

// Zod error → 400
// Prisma known error codes → mapping friendly
const errorHandler = (err, _req, res, _next) => {
  let statusCode = err.statusCode || 500;
  let message = err.message || 'Internal Server Error';
  let details = err.details || null;

  // Zod validation error
  if (err.name === 'ZodError' && Array.isArray(err.issues)) {
    statusCode = 400;
    message = 'Validasi gagal';
    details = err.issues.map((i) => ({
      path: i.path.join('.'),
      message: i.message,
    }));
  }

  // Prisma errors
  if (err.code === 'P2002') {
    statusCode = 409;
    message = 'Data sudah ada (unique constraint violation)';
    details = err.meta?.target || null;
  } else if (err.code === 'P2025') {
    statusCode = 404;
    message = 'Resource tidak ditemukan';
  } else if (err.code === 'P2003') {
    statusCode = 400;
    message = 'Foreign key constraint gagal: referensi tidak valid';
  }

  if (statusCode >= 500) {
    console.error('[ERROR]', err);
  }

  return res.status(statusCode).json({
    success: false,
    message,
    ...(details ? { details } : {}),
    ...(process.env.NODE_ENV !== 'production' && statusCode >= 500
      ? { stack: err.stack }
      : {}),
  });
};

// 404 handler untuk route tidak ditemukan
const notFound = (_req, _res, next) => {
  next(new ApiError(404, 'Endpoint tidak ditemukan'));
};

export { errorHandler, notFound };
export default errorHandler;
