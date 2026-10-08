import { PrismaClient } from '@prisma/client';
import config from '../config/env.js';

// Log query di development untuk debugging
const prisma = new PrismaClient({
  log: config.nodeEnv === 'development' ? ['warn', 'error'] : ['error'],
});

export default prisma;
