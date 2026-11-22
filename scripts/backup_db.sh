#!/bin/bash
# Pencadangan otomatis PostgreSQL harian ke arsip tar.gz
# Kelompok 4 - Portal Berita Mahasiswa

set -eo pipefail

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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mulai backup database: ${DB_NAME}" >> "$LOG_FILE"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

if pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$SQL_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ekspor dump SQL selesai: ${SQL_FILE}" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gagal: pg_dump bermasalah" >> "$LOG_FILE"
    rm -f "$SQL_FILE"
    exit 1
fi

tar -czf "$TAR_FILE" -C "$BACKUP_DIR" "${FILENAME}.sql"
rm -f "$SQL_FILE"

if [ -f "$TAR_FILE" ] && [ -s "$TAR_FILE" ]; then
    FILE_SIZE=$(du -h "$TAR_FILE" | cut -f1)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Arsip dibuat: ${TAR_FILE} (${FILE_SIZE}) - STATUS: SUCCESS" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gagal: berkas tar.gz kosong atau tidak terbentuk" >> "$LOG_FILE"
    rm -f "$TAR_FILE"
    exit 1
fi

# Rotasi backup: pertahankan data 7 hari terakhir
find "$BACKUP_DIR" -type f -name "${DB_NAME}-*.tar.gz" -mtime +7 -delete 2>/dev/null || true

exit 0
