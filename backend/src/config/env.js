import dotenv from 'dotenv';

dotenv.config();

const config = {
  port: Number(process.env.PORT || 3000),
  nodeEnv: process.env.NODE_ENV || 'development',
  isProd: process.env.NODE_ENV === 'production',
  corsOrigin: process.env.CORS_ORIGIN || '*',
  jwt: {
    secret: process.env.JWT_SECRET || 'dev-secret-change-me',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },
  bcryptSaltRounds: Number(process.env.BCRYPT_SALT_ROUNDS || 10),
};

export default config;
