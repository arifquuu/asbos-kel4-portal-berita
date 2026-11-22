#!/bin/bash
# ==============================================================================
# Skrip Otomatisasi Fase 1: Server Hardening & Inisialisasi
# Kelompok 4 - Portal Berita Mahasiswa
# Penanggung Jawab: Fadjri (Role 1 - System Administrator & Security Lead)
# ==============================================================================

set -eo pipefail

echo "=== [1/6] Memperbarui Paket Sistem & Mengatur Hostname ==="
apt update && apt upgrade -y
hostnamectl set-hostname portal-berita-vps

echo "=== [2/6] Membuat Akun Pengguna Non-Root & Konfigurasi Sudoers ==="
for user in fadjri arifqu dianprawira; do
    if id "$user" &>/dev/null; then
        echo "User $user sudah ada, melewati pembuatan user..."
    else
        echo "Membuat user: $user"
        adduser --disabled-password --gecos "" "$user"
    fi
    usermod -aG sudo "$user"
done

# Solusi Celah Sudo: Konfigurasi hak akses sudo tanpa password untuk kelancaran Ansible & Evaluasi Dosen
echo "Mengonfigurasi hak akses sudoers di /etc/sudoers.d/asbos-admins..."
cat << 'EOF' > /etc/sudoers.d/asbos-admins
# Izin eksekusi sudo untuk administrator proyek ASBOS Kelompok 4 & Evaluasi Dosen
fadjri ALL=(ALL) NOPASSWD:ALL
arifqu ALL=(ALL) NOPASSWD:ALL
dianprawira ALL=(ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/asbos-admins

# Validasi sintaks sudoers agar tidak merusak sistem
if visudo -cf /etc/sudoers.d/asbos-admins; then
    echo "Sintaks sudoers VALID."
else
    echo "ERROR: Sintaks sudoers tidak valid! Menghapus file bermasalah..."
    rm -f /etc/sudoers.d/asbos-admins
    exit 1
fi

echo "=== [3/6] Memasang SSH Public Key (Izin 700 / 600) ==="
# 1. Kunci Fadjri
mkdir -p /home/fadjri/.ssh
cat << 'EOF' > /home/fadjri/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIElErKKB32A1TCKKiLM7q9yBfWIdbapqcE4Zioh5ychF fadjri@portal-berita
EOF
chmod 700 /home/fadjri/.ssh
chmod 600 /home/fadjri/.ssh/authorized_keys
chown -R fadjri:fadjri /home/fadjri/.ssh

# 2. Kunci Arifqu (termasuk kunci CI/CD deploy)
mkdir -p /home/arifqu/.ssh
cat << 'EOF' > /home/arifqu/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7mwvdGPo5Lj65VVwUd3eFTIuSh3QiA6NqJ5fyqrxpI arifqu@portal-berita
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7Xj3KMlS16omqICTvfN54unKaqv9jX4XyhC2BYp9gi github-actions-deploy
EOF
chmod 700 /home/arifqu/.ssh
chmod 600 /home/arifqu/.ssh/authorized_keys
chown -R arifqu:arifqu /home/arifqu/.ssh

# 3. Kunci Dosen (Pak Dian Prawira - Deliverable Wajib)
mkdir -p /home/dianprawira/.ssh
cat << 'EOF' > /home/dianprawira/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZuNUaTJTKxscUs9BtGt8yzn5/fjDJuMsy19Jmzjt8y wiradianxiv@mti.gadjahmada.edu
EOF
chmod 700 /home/dianprawira/.ssh
chmod 600 /home/dianprawira/.ssh/authorized_keys
chown -R dianprawira:dianprawira /home/dianprawira/.ssh

echo "=== [4/6] Menyiapkan Struktur Direktori Proyek ==="
mkdir -p /var/www/portal-berita
mkdir -p /opt/scripts
mkdir -p /var/backups/postgresql

chown -R arifqu:www-data /var/www/portal-berita
chmod -R 775 /var/www/portal-berita
chmod 700 /var/backups/postgresql

echo "=== [5/6] Konfigurasi Hardening SSH Terlebih Dahulu (Port 2244) ==="
# Backup file konfigurasi utama
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Menggunakan 01-hardening.conf agar dibaca pertama kali (first-match-wins)
cat << 'EOF' > /etc/ssh/sshd_config.d/01-hardening.conf
Port 2244
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
KbdInteractiveAuthentication no
UsePAM yes
EOF

# Netralkan override jika ada di cloud-init
for conf in /etc/ssh/sshd_config.d/*cloud*.conf; do
    if [ -f "$conf" ]; then
        sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' "$conf"
    fi
done

# Validasi sintaks SSH konfigurasi sebelum restart
if ! sshd -t; then
    echo "ERROR: Konfigurasi sshd tidak valid!"
    exit 1
fi

# Tangani systemd socket activation Ubuntu 24.04 secara presisi
if systemctl is-active --quiet ssh.socket; then
    echo "Menyesuaikan systemd ssh.socket ke port 2244..."
    mkdir -p /etc/systemd/system/ssh.socket.d
    cat << 'EOF' > /etc/systemd/system/ssh.socket.d/listen.conf
[Socket]
ListenStream=
ListenStream=2244
EOF
    systemctl stop ssh.service || true
    systemctl daemon-reload
    systemctl restart ssh.socket
else
    systemctl restart ssh || systemctl restart sshd
fi

# Tunggu sejenak dan verifikasi port 2244 benar-benar listening
sleep 2
if ! ss -tulnp | grep -q ':2244 '; then
    echo "PERINGATAN: Port 2244 belum terdeteksi aktif pada ss -tulnp!"
else
    echo "Port 2244 berhasil aktif dan mendengarkan koneksi."
fi

echo "=== [6/6] Mengaktifkan Firewall UFW (Langkah Terakhir setelah Port 2244 Aktif) ==="
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing

# Izinkan port esensial
ufw allow 2244/tcp comment 'SSH Custom Port'
ufw allow 80/tcp comment 'Nginx HTTP'
ufw allow 443/tcp comment 'Nginx HTTPS'

# Aktifkan UFW
ufw --force enable

echo ""
echo "=========================================================================="
echo "           FASE 1 SELESAI! PERHATIAN ATURAN EMAS ANTI-TERKUNCI:           "
echo "=========================================================================="
echo "1. JANGAN TUTUP TERMINAL ROOT PERTAMA INI!"
echo "2. Buka terminal baru di laptopmu dan uji login:"
echo "   ssh -p 2244 fadjri@<IP_VPS>"
echo "3. Setelah masuk sebagai fadjri, tes hak sudo:"
echo "   sudo whoami    (Harus menampilkan output: root)"
echo "4. Tes penolakan akses root:"
echo "   ssh -p 2244 root@<IP_VPS>   (Harus ditolak: Permission denied)"
echo "5. Jalankan audit layanan tak perlu:"
echo "   sudo ss -tulnp"
echo "   systemctl list-unit-files --type=service --state=enabled"
echo "=========================================================================="
