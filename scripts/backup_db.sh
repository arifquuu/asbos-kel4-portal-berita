#!/bin/bash
# ==============================================================================
# Skrip Backup Otomatis Database PostgreSQL (Portal Berita Mahasiswa)
# Mata Kuliah: Administrasi Sistem Berbasis Open Source (ASBOS) - Kelompok 4
# Penanggung Jawab: Fadjri (Role 1 - System Administrator & Security Lead)
# Lokasi di Server: /opt/scripts/backup_db.sh
# ==============================================================================

# Aturan Bash ketat: hentikan proses jika ada perintah yang gagal
set -eo pipefail

# --- Konfigurasi Variabel ---
DB_NAME="portal_berita_db"
DB_USER="berita_user"
DB_HOST="localhost"
DB_PORT="5432"

BACKUP_DIR="/var/backups/postgresql"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
FILENAME="${DB_NAME}-${TIMESTAMP}"
SQL_FILE="${BACKUP_DIR}/${FILENAME}.sql"
TAR_FILE="${BACKUP_DIR}/${FILENAME}.tar.gz"

LOG_FILE="/var/log/backup_db.log"

# Catat waktu mulai backup
echo "==========================================" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Memulai proses pencadangan database: ${DB_NAME}" >> "$LOG_FILE"

# 1. Pastikan direktori backup ada dan izinnya aman (700)
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

# 2. Eksekusi pg_dump (autentikasi otomatis menggunakan ~/.pgpass)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Menjalankan pg_dump..." >> "$LOG_FILE"
if pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$SQL_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ekspor SQL mentah berhasil dibuat: ${SQL_FILE}" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Gagal menjalankan pg_dump!" >> "$LOG_FILE"
    exit 1
fi

# 3. Kompresi hasil dump menjadi .tar.gz
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mengompresi file ke arsip .tar.gz..." >> "$LOG_FILE"
tar -czf "$TAR_FILE" -C "$BACKUP_DIR" "${FILENAME}.sql"

# Hapus file SQL mentah sementara agar menghemat ruang disk
rm -f "$SQL_FILE"

# 4. Verifikasi arsip backup
if [ -f "$TAR_FILE" ] && [ -s "$TAR_FILE" ]; then
    FILE_SIZE=$(du -h "$TAR_FILE" | cut -f1)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pencadangan BERHASIL: ${TAR_FILE} (${FILE_SIZE})" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Status: SUCCESS" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: File arsip tidak ditemukan atau kosong (0 byte)!" >> "$LOG_FILE"
    exit 1
fi

# 5. Rotasi Backup: Simpan hanya cadangan 7 hari terakhir (opsional & best-practice)
find "$BACKUP_DIR" -type f -name "${DB_NAME}-*.tar.gz" -mtime +7 -delete 2>/dev/null || true

echo "==========================================" >> "$LOG_FILE"
exit 0
