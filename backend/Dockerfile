# Backend SakuOrganisasi — Node.js + Express + Prisma (MySQL)
FROM node:22-alpine

WORKDIR /app

# Install dependencies (termasuk prisma dev-dep untuk generate)
COPY package.json ./
RUN npm install --no-audit --no-fund

# Copy prisma schema & generate client
COPY prisma ./prisma
RUN npx prisma generate

# Copy source
COPY src ./src
COPY scripts ./scripts

ENV NODE_ENV=production
ENV PORT=9000
EXPOSE 9000

CMD ["node", "src/server.js"]
