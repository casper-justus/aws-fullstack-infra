FROM node:18-alpine

RUN apk add --no-cache curl

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production 2>/dev/null || npm install --only=production

COPY src/ ./src/
COPY server.js ./

EXPOSE 8000

USER node

CMD ["node", "server.js"]
