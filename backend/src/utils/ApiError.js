export class ApiError extends Error {
  constructor(statusCode, message, details = null) {
    super(message);
    this.statusCode = statusCode;
    this.details = details;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }

  static badRequest(message = 'Bad Request', details = null) {
    return new ApiError(400, message, details);
  }

  static unauthorized(message = 'Unauthorized') {
    return new ApiError(401, message);
  }

  static forbidden(message = 'Forbidden: akses ditolak') {
    return new ApiError(403, message);
  }

  static notFound(message = 'Resource tidak ditemukan') {
    return new ApiError(404, message);
  }

  static conflict(message = 'Resource sudah ada (konflik)') {
    return new ApiError(409, message);
  }
}

export default ApiError;
