FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY src ./src
USER node
ENV PORT=3000 TRUST_PROXY=1
EXPOSE 3000
# /health also checks the database connection.
HEALTHCHECK --interval=30s --timeout=8s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1
CMD ["node", "--no-warnings", "src/server.js"]
