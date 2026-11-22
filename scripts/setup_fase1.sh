#!/bin/bash
# Inisialisasi dan hardening server VPS Ubuntu 24.04 (Fase 1)
# Portal Berita Mahasiswa - Kelompok 4

set -eo pipefail

# Pembaruan repositori dan paket sistem
apt update && apt upgrade -y
hostnamectl set-hostname portal-berita-vps

# Pembuatan akun non-root
for user in fadjri arifqu dianprawira; do
    if ! id "$user" &>/dev/null; then
        adduser --disabled-password --gecos "" "$user"
    fi
    usermod -aG sudo "$user"
done

# Akses sudo tanpa password agar eksekusi Ansible dan pengujian dosen tidak terhambat
cat << 'EOF' > /etc/sudoers.d/asbos-admins
fadjri ALL=(ALL) NOPASSWD:ALL
arifqu ALL=(ALL) NOPASSWD:ALL
dianprawira ALL=(ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/asbos-admins
visudo -cf /etc/sudoers.d/asbos-admins

# Registrasi SSH public key tiap user
mkdir -p /home/fadjri/.ssh
cat << 'EOF' > /home/fadjri/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIElErKKB32A1TCKKiLM7q9yBfWIdbapqcE4Zioh5ychF fadjri@portal-berita
EOF
chmod 700 /home/fadjri/.ssh
chmod 600 /home/fadjri/.ssh/authorized_keys
chown -R fadjri:fadjri /home/fadjri/.ssh

mkdir -p /home/arifqu/.ssh
cat << 'EOF' > /home/arifqu/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL7mwvdGPo5Lj65VVwUd3eFTIuSh3QiA6NqJ5fyqrxpI arifqu@portal-berita
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7Xj3KMlS16omqICTvfN54unKaqv9jX4XyhC2BYp9gi github-actions-deploy
EOF
chmod 700 /home/arifqu/.ssh
chmod 600 /home/arifqu/.ssh/authorized_keys
chown -R arifqu:arifqu /home/arifqu/.ssh

mkdir -p /home/dianprawira/.ssh
cat << 'EOF' > /home/dianprawira/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZuNUaTJTKxscUs9BtGt8yzn5/fjDJuMsy19Jmzjt8y wiradianxiv@mti.gadjahmada.edu
EOF
chmod 700 /home/dianprawira/.ssh
chmod 600 /home/dianprawira/.ssh/authorized_keys
chown -R dianprawira:dianprawira /home/dianprawira/.ssh

# Struktur direktori aplikasi dan pencadangan
mkdir -p /var/www/portal-berita
mkdir -p /opt/scripts
mkdir -p /var/backups/postgresql

chown -R arifqu:www-data /var/www/portal-berita
chmod -R 775 /var/www/portal-berita
chmod 700 /var/backups/postgresql

# Hardening SSH ke port 2244 dan nonaktifkan password/root
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 01-hardening.conf dibaca pertama (first-match-wins) agar menimpa konfigurasi cloud bawaan
cat << 'EOF' > /etc/ssh/sshd_config.d/01-hardening.conf
Port 2244
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
KbdInteractiveAuthentication no
UsePAM yes
EOF

for conf in /etc/ssh/sshd_config.d/*cloud*.conf; do
    if [ -f "$conf" ]; then
        sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' "$conf"
    fi
done

sshd -t

# Penanganan socket activation Ubuntu 24.04
if systemctl is-active --quiet ssh.socket; then
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

sleep 2
ss -tulnp | grep ':2244 '

# Konfigurasi firewall UFW setelah SSH port 2244 aktif
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow 2244/tcp comment 'SSH Port'
ufw allow 80/tcp comment 'Nginx HTTP'
ufw allow 443/tcp comment 'Nginx HTTPS'
ufw --force enable

echo "Setup Fase 1 selesai."
echo "Penting: Uji koneksi dari terminal baru dengan:"
echo "  ssh -p 2244 fadjri@<IP_VPS>"
echo "  ssh -p 2244 root@<IP_VPS> (pastikan ditolak)"
