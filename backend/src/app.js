import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import config from './config/env.js';

// Routes
import authRoutes from './routes/auth.routes.js';
import userRoutes from './routes/user.routes.js';
import accountRoutes from './routes/account.routes.js';
import categoryRoutes from './routes/category.routes.js';
import eventRoutes from './routes/event.routes.js';
import memberRoutes from './routes/member.routes.js';
import transactionRoutes from './routes/transaction.routes.js';
import cashRoutes from './routes/cash.routes.js';
import dashboardRoutes from './routes/dashboard.routes.js';

import { errorHandler, notFound } from './middlewares/errorHandler.js';

const app = express();

// Security headers
app.use(helmet());

// CORS
app.use(
  cors({
    origin: config.corsOrigin === '*' ? true : config.corsOrigin.split(',').map((s) => s.trim()),
  })
);

// Body parser
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

// Logger
if (!config.isProd) {
  app.use(morgan('dev'));
}

// Health check
app.get('/', (_req, res) => {
  res.json({
    name: 'SakuOrganisasi API',
    version: '1.0.0',
    status: 'ok',
    docs: '/api',
    time: new Date().toISOString(),
  });
});

// Routes utama
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/accounts', accountRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/members', memberRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/cash', cashRoutes);
app.use('/api/dashboard', dashboardRoutes);

// Daftar endpoint (sederhana)
app.get('/api', (_req, res) => {
  res.json({
    success: true,
    endpoints: {
      auth: ['/POST /api/auth/register', 'POST /api/auth/login', 'GET /api/auth/me'],
      users: ['GET /api/users', 'POST /api/users', 'PATCH /api/users/:id', 'DELETE /api/users/:id'],
      accounts: ['GET /api/accounts', 'POST /api/accounts', 'GET/PATCH/DELETE /api/accounts/:id'],
      categories: ['GET /api/categories', 'POST /api/categories', 'GET/PATCH/DELETE /api/categories/:id'],
      events: ['GET /api/events', 'POST /api/events', 'GET/PATCH/DELETE /api/events/:id'],
      members: ['GET /api/members', 'POST /api/members', 'GET/PATCH/DELETE /api/members/:id'],
      transactions: ['GET /api/transactions', 'POST /api/transactions', 'GET/PATCH/DELETE /api/transactions/:id'],
      cash: [
        'GET /api/cash/periods', 'POST /api/cash/periods', 'GET/PATCH/DELETE /api/cash/periods/:id',
        'GET /api/cash/periods/:id/checklist', 'POST /api/cash/pay', 'GET /api/cash/logs', 'DELETE /api/cash/logs/:id',
      ],
      dashboard: ['GET /api/dashboard/summary', 'GET /api/dashboard/by-category', 'GET /api/dashboard/monthly-trend'],
    },
  });
});

// 404 & error handler (harus terakhir)
app.use(notFound);
app.use(errorHandler);

export default app;
