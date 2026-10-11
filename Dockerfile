# NOTE: stage order matters. `app` is intentionally the LAST stage because
# platforms that build this Dockerfile without a --target flag (e.g. Railway)
# build the final stage by default, and the app server is what must be served.
# docker compose selects stages by name (target: app / target: browser), so
# this ordering does not affect local compose usage.
FROM node:24-bookworm-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:24-bookworm-slim AS browser
ENV NODE_ENV=production BROWSER_HOST=0.0.0.0 BROWSER_PORT=4311 PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev && npx playwright install --with-deps chromium && chmod -R a+rX /ms-playwright
COPY --from=build /app/dist/server ./dist/server
USER node
EXPOSE 4311
CMD ["node", "dist/server/browser/index.js"]

FROM node:24-bookworm-slim AS app
ENV NODE_ENV=production HOST=0.0.0.0 PORT=4310 DATABASE_PATH=/data/opendots.sqlite
WORKDIR /app
COPY package*.json ./
# NOTE: intentionally no `USER node` here. Hosted volume mounts (e.g. Railway)
# arrive root-owned at runtime, which masks any build-time chown of /data and
# makes SQLite fail with "unable to open database file" for a non-root user.
RUN npm ci --omit=dev && mkdir -p /data
COPY --from=build /app/dist ./dist
EXPOSE 4310
CMD ["node", "dist/server/server/index.js"]
