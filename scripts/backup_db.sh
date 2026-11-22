#!/bin/bash
# ==============================================================================
# Skrip Backup Otomatis Database PostgreSQL (Portal Berita Mahasiswa)
# Penanggung Jawab: Fadjri (Role 1 - System Administrator & Security Lead)
# Lokasi: /opt/scripts/backup_db.sh
# ==============================================================================

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

echo "==========================================" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Memulai backup database: ${DB_NAME}" >> "$LOG_FILE"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Menjalankan pg_dump..." >> "$LOG_FILE"
if pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$SQL_FILE"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ekspor SQL berhasil: ${SQL_FILE}" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: pg_dump gagal!" >> "$LOG_FILE"
    rm -f "$SQL_FILE"
    exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mengompresi file ke .tar.gz..." >> "$LOG_FILE"
tar -czf "$TAR_FILE" -C "$BACKUP_DIR" "${FILENAME}.sql"
rm -f "$SQL_FILE"

if [ -f "$TAR_FILE" ] && [ -s "$TAR_FILE" ]; then
    FILE_SIZE=$(du -h "$TAR_FILE" | cut -f1)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup BERHASIL: ${TAR_FILE} (${FILE_SIZE})" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Status: SUCCESS" >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: File arsip tidak ditemukan atau kosong!" >> "$LOG_FILE"
    rm -f "$TAR_FILE"
    exit 1
fi

# Rotasi backup: simpan 7 hari terakhir
find "$BACKUP_DIR" -type f -name "${DB_NAME}-*.tar.gz" -mtime +7 -delete 2>/dev/null || true

echo "==========================================" >> "$LOG_FILE"
exit 0
