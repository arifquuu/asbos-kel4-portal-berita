FROM node:20-alpine

WORKDIR /app

# Salin manifest lebih dulu agar layer npm ci di-cache saat hanya kode yang berubah.
COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# Jalankan proses sebagai user non-root bawaan image Node (least privilege).
USER node

EXPOSE 3000
CMD ["npm", "start"]