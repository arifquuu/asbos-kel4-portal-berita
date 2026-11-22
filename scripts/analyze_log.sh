#!/bin/bash
# Analisis log server: percobaan gagal SSH dan statistik akses web
# Kelompok 4 - Portal Berita Mahasiswa

OUTPUT_FILE="/var/log/laporan_anomali.txt"
AUTH_LOG="/var/log/auth.log"
NGINX_LOG="/var/log/nginx/access.log"

cat << EOF > "$OUTPUT_FILE"
Laporan Analisis Log Server
Waktu: $(date '+%Y-%m-%d %H:%M:%S %Z')
Host : $(hostname)
Pemeriksa: Fadjri (Role 1 - System Administrator & Security Lead)

EOF

echo "Top 5 IP Gagal Login SSH (/var/log/auth.log):" >> "$OUTPUT_FILE"
if [ -f "$AUTH_LOG" ]; then
    SSH_FAILURES=$(grep -E 'Failed password|Invalid user|Failed publickey|Connection closed.*authenticating' "$AUTH_LOG" 2>/dev/null \
        | sed -n 's/.*from \([0-9.]*\).*/\1/p' \
        | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' \
        | grep -vE '^127\.|^0\.' \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -n 5)

    if [ -n "$SSH_FAILURES" ]; then
        echo "$SSH_FAILURES" >> "$OUTPUT_FILE"
    else
        echo "Tidak ada catatan kegagalan SSH yang terdeteksi." >> "$OUTPUT_FILE"
    fi
else
    echo "Berkas $AUTH_LOG belum tersedia." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "Top 5 IP Akses Web Nginx (/var/log/nginx/access.log):" >> "$OUTPUT_FILE"
if [ -f "$NGINX_LOG" ]; then
    WEB_ACCESS=$(awk '{print $1}' "$NGINX_LOG" 2>/dev/null \
        | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' \
        | sort \
        | uniq -c \
        | sort -nr \
        | head -n 5)

    if [ -n "$WEB_ACCESS" ]; then
        echo "$WEB_ACCESS" >> "$OUTPUT_FILE"
    else
        echo "Belum ada catatan akses HTTP/HTTPS." >> "$OUTPUT_FILE"
    fi
else
    echo "Berkas $NGINX_LOG belum tersedia." >> "$OUTPUT_FILE"
fi

cat "$OUTPUT_FILE"
