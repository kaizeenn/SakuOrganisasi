import asyncHandler from '../utils/asyncHandler.js';
import prisma from '../config/prisma.js';

const summary = asyncHandler(async (req, res) => {
  const { startDate, endDate } = req.query;

  // Default: bulan berjalan
  const now = new Date();
  const firstOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const start = startDate ? new Date(startDate) : firstOfMonth;
  const end = endDate ? new Date(endDate) : new Date();

  const dateRange = { gte: start, lte: end };

  const [accounts, incomeAgg, expenseAgg, txCount, memberCount, activePeriodCount] = await Promise.all([
    prisma.account.findMany({ select: { id: true, name: true, type: true, currentBalance: true } }),
    prisma.transaction.aggregate({
      _sum: { amount: true },
      where: { type: 'Income', transactionDate: dateRange },
    }),
    prisma.transaction.aggregate({
      _sum: { amount: true },
      where: { type: 'Expense', transactionDate: dateRange },
    }),
    prisma.transaction.count({ where: { transactionDate: dateRange } }),
    prisma.member.count(),
    prisma.cashPeriod.count({ where: { status: 'Active' } }),
  ]);

  const totalBalance = accounts.reduce((s, a) => s + a.currentBalance, 0);
  const totalIncome = incomeAgg._sum.amount ?? 0;
  const totalExpense = expenseAgg._sum.amount ?? 0;
  const netCashflow = totalIncome - totalExpense;

  res.json({
    success: true,
    data: {
      range: { startDate: start, endDate: end },
      totalBalance,
      totalIncome,
      totalExpense,
      netCashflow,
      transactionCount: txCount,
      memberCount,
      activeCashPeriodCount: activePeriodCount,
      accounts: accounts.map((a) => ({ id: a.id, name: a.name, type: a.type, balance: a.currentBalance })),
    },
  });
});

// Ringkasan per kategori (expense breakdown) untuk chart
const byCategory = asyncHandler(async (req, res) => {
  const { startDate, endDate, type = 'Expense' } = req.query;
  const now = new Date();
  const firstOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const start = startDate ? new Date(startDate) : firstOfMonth;
  const end = endDate ? new Date(endDate) : new Date();

  const rows = await prisma.transaction.groupBy({
    by: ['categoryId'],
    where: { type, transactionDate: { gte: start, lte: end } },
    _sum: { amount: true },
    _count: true,
  });

  const categoryIds = rows.map((r) => r.categoryId);
  const categories = await prisma.category.findMany({ where: { id: { in: categoryIds } } });
  const catMap = new Map(categories.map((c) => [c.id, c]));

  const data = rows
    .map((r) => ({
      category: catMap.get(r.categoryId)?.name ?? `#${r.categoryId}`,
      categoryId: r.categoryId,
      total: r._sum.amount ?? 0,
      count: r._count,
    }))
    .sort((a, b) => b.total - a.total);

  res.json({ success: true, data: { type, breakdown: data } });
});

// Ringkasan per bulan (12 bulan terakhir) untuk trend line
const monthlyTrend = asyncHandler(async (req, res) => {
  const now = new Date();
  const months = [];
  for (let i = 11; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const next = new Date(now.getFullYear(), now.getMonth() - i + 1, 1);
    const [inc, exp] = await Promise.all([
      prisma.transaction.aggregate({
        _sum: { amount: true },
        where: { type: 'Income', transactionDate: { gte: d, lt: next } },
      }),
      prisma.transaction.aggregate({
        _sum: { amount: true },
        where: { type: 'Expense', transactionDate: { gte: d, lt: next } },
      }),
    ]);
    months.push({
      label: d.toLocaleDateString('id-ID', { month: 'short', year: 'numeric' }),
      income: inc._sum.amount ?? 0,
      expense: exp._sum.amount ?? 0,
    });
  }
  res.json({ success: true, data: { trend: months } });
});

export default { summary, byCategory, monthlyTrend };
