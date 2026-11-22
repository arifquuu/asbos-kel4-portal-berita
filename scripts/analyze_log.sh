#!/bin/bash
# ==============================================================================
# Skrip Analisis Log Server (Pemantauan Keamanan & Akses Web)
# Penanggung Jawab: Fadjri (Role 1 - System Administrator & Security Lead)
# Lokasi: /opt/scripts/analyze_log.sh
# Output: /var/log/laporan_anomali.txt
# ==============================================================================

OUTPUT_FILE="/var/log/laporan_anomali.txt"
AUTH_LOG="/var/log/auth.log"
NGINX_LOG="/var/log/nginx/access.log"

cat << 'EOF' > "$OUTPUT_FILE"
================================================================================
                    LAPORAN ANALISIS LOG & ANOMALI SERVER
                   Kelompok 4 - Portal Berita Mahasiswa
================================================================================
EOF
echo "Waktu Pembuatan Laporan : $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$OUTPUT_FILE"
echo "Host Server             : $(hostname)" >> "$OUTPUT_FILE"
echo "Pemeriksa (Role 1)      : Fadjri (System Administrator & Security Lead)" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 1. Top 5 IP Percobaan Gagal Login SSH (/var/log/auth.log)
echo "--- [1] TOP 5 ALAMAT IP GAGAL LOGIN SSH (/var/log/auth.log) ---" >> "$OUTPUT_FILE"
echo "Format: [Jumlah Percobaan Gagal] [Alamat IP Penyerang]" >> "$OUTPUT_FILE"
echo "-----------------------------------------------------------------" >> "$OUTPUT_FILE"

if [ -f "$AUTH_LOG" ]; then
    # Filter pola kegagalan SSH, ekstrak token setelah 'from', lalu validasi IPv4
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
        echo "Tidak ditemukan catatan percobaan gagal login SSH pada log saat ini (Aman)." >> "$OUTPUT_FILE"
    fi
else
    echo "PERINGATAN: Berkas $AUTH_LOG tidak ditemukan! (Pastikan rsyslog terpasang)." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "-----------------------------------------------------------------" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 2. Top 5 IP Akses Web Terbanyak (/var/log/nginx/access.log)
echo "--- [2] TOP 5 ALAMAT IP AKSES WEB TERBANYAK (/var/log/nginx/access.log) ---" >> "$OUTPUT_FILE"
echo "Format: [Jumlah Request] [Alamat IP Klien]" >> "$OUTPUT_FILE"
echo "-----------------------------------------------------------------" >> "$OUTPUT_FILE"

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
        echo "Belum ada catatan lalu lintas HTTP/HTTPS pada log Nginx." >> "$OUTPUT_FILE"
    fi
else
    echo "PERINGATAN: Berkas $NGINX_LOG belum ada (Nginx belum aktif/belum di-generate)." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"
echo "Laporan selesai dibuat secara otomatis oleh /opt/scripts/analyze_log.sh" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"

cat "$OUTPUT_FILE"
