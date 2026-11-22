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

echo "=== [2/6] Membuat Akun Pengguna Non-Root (Least Privilege) ==="
for user in fadjri arifqu dianprawira; do
    if id "$user" &>/dev/null; then
        echo "User $user sudah ada, melewati..."
    else
        echo "Membuat user: $user"
        adduser --disabled-password --gecos "" "$user"
    fi
    usermod -aG sudo "$user"
done

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

# 3. Kunci Dosen (Pak Dian Prawira)
mkdir -p /home/dianprawira/.ssh
cat << 'EOF' > /home/dianprawira/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZuNUaTJTKxscUs9BtGt8yzn5/fjDJuMsy19Jmzjt8y wiradianxiv@mti.gadjahmada.edu
EOF
chmod 700 /home/dianprawira/.ssh
chmod 600 /home/dianprawira/.ssh/authorized_keys
chown -R dianprawira:dianprawira /home/dianprawira/.ssh

echo "=== [4/6] Menyiapkan Struktur Direktori ==="
mkdir -p /var/www/portal-berita
mkdir -p /opt/scripts
mkdir -p /var/backups/postgresql

chown -R arifqu:www-data /var/www/portal-berita
chmod -R 775 /var/www/portal-berita
chmod 700 /var/backups/postgresql

echo "=== [5/6] Mengonfigurasi Firewall UFW (Default Deny) ==="
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 2244/tcp comment 'SSH Custom Port'
ufw allow 80/tcp comment 'Nginx HTTP'
ufw allow 443/tcp comment 'Nginx HTTPS'
ufw --force enable

echo "=== [6/6] Hardening Layanan SSH (Port 2244, Nonaktifkan Root & Password) ==="
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

cat << 'EOF' > /etc/ssh/sshd_config.d/99-hardening.conf
Port 2244
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
EOF

if [ -f /etc/ssh/sshd_config.d/50-cloud-init.conf ]; then
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config.d/50-cloud-init.conf
fi

if systemctl is-active --quiet ssh.socket; then
    mkdir -p /etc/systemd/system/ssh.socket.d
    cat << 'EOF' > /etc/systemd/system/ssh.socket.d/listen.conf
[Socket]
ListenStream=
ListenStream=2244
EOF
    systemctl daemon-reload
    systemctl restart ssh.socket
fi

systemctl restart ssh || systemctl restart sshd

echo ""
echo "=========================================================================="
echo "           FASE 1 SELESAI! PERHATIAN ATURAN EMAS ANTI-TERKUNCI:           "
echo "=========================================================================="
echo "1. JANGAN TUTUP TERMINAL INI DULU!"
echo "2. Buka terminal baru di laptopmu dan tes login:"
echo "   ssh -p 2244 fadjri@<IP_VPS>"
echo "3. Tes penolakan root:"
echo "   ssh -p 2244 root@<IP_VPS>   (Harus ditolak: Permission denied)"
echo "=========================================================================="
