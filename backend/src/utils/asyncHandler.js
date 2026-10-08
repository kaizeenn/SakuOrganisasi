// Wrapper untuk async handler agar error otomatis diteruskan ke middleware error.
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

export default asyncHandler;
