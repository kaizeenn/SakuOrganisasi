import app from './app.js';
import config from './config/env.js';
import prisma from './config/prisma.js';

async function start() {
  try {
    // Cek koneksi database
    await prisma.$connect();
    console.log('✓ Database terhubung');

    const server = app.listen(config.port, () => {
      console.log(`✓ Server berjalan di http://localhost:${config.port} (${config.nodeEnv})`);
      console.log(`  API base: http://localhost:${config.port}/api`);
      console.log(`  Health:   http://localhost:${config.port}/`);
    });

    // Graceful shutdown
    const shutdown = async (signal) => {
      console.log(`\n${signal} diterima. Menutup server...`);
      server.close(async () => {
        await prisma.$disconnect();
        console.log('✓ Server ditutup dengan bersih.');
        process.exit(0);
      });
      // Force exit setelah 10 detik
      setTimeout(() => process.exit(1), 10000).unref();
    };

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  } catch (err) {
    console.error('Gagal start server:', err);
    process.exit(1);
  }
}

start();
