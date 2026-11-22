# Portal Berita Mahasiswa (Kelompok 4)

Repositori proyek akhir (Project-Based Learning) mata kuliah **Administrasi Sistem Berbasis Open Source (ASBOS)**, Semester 5, Tahun Akademik 2026/2027, Program Studi Sistem Informasi, Universitas Tanjungpura.

* **Dosen Pengampu:** Dian Prawira, M.Eng.
* **Tema Aplikasi:** Portal Berita Mahasiswa (Kelompok 4)
* **Sistem Operasi Target:** Ubuntu Server 24.04 LTS

## Anggota Kelompok dan Pembagian Peran

| Anggota | Peran | Ruang Lingkup |
| :--- | :--- | :--- |
| Fadjri | System Administrator & Security | Fase 1 (Server Hardening, SSH, UFW), Fase 2 (PostgreSQL, `backup_db.sh`, cron), Fase 6 (`analyze_log.sh`) |
| Arifqu | DevOps & Platform | Aplikasi Purwarupa Node.js, Fase 3 (Docker & Nginx Reverse Proxy), Fase 4 (CI/CD GitHub Actions), Fase 5 (Ansible IaC) |

## Arsitektur Sistem

```text
Pengguna (HTTP 80 / HTTPS 443)
        |
        v
   UFW Firewall (Default Deny; hanya port SSH 2244, 80, 443)
        |
        v
Nginx di Host (Reverse Proxy)
        |  proxy_pass ke 127.0.0.1:3000
        v
Docker Container: Node.js + Express + EJS (port 3000)
        |  koneksi jaringan lokal
        v
PostgreSQL di Host (port 5432, terisolasi dari publik)
        |
        v
Cronjob 02:00 -> /opt/scripts/backup_db.sh -> arsip .tar.gz
```

## Struktur Repositori

* `app/`: kode aplikasi purwarupa Portal Berita Mahasiswa (`server.js`, template `views/`, stylesheet `public/`, `Dockerfile`, `.dockerignore`, `.env.example`).
* `nginx/`: berkas konfigurasi Reverse Proxy Nginx (`portal-berita.conf`).
* `ansible/`: berkas inventaris (`inventory.ini`) dan playbook otomatisasi server replika (`playbook.yml`).
* `.github/workflows/`: konfigurasi pipeline CI/CD GitHub Actions (`deploy.yml`).
* `scripts/`: skema basis data (`schema.sql`) serta skrip Bash pemeliharaan server (`backup_db.sh` dan `analyze_log.sh`).
* `docker-compose.yml`: konfigurasi container produksi di VPS (port terikat ke `127.0.0.1:3000:3000`).
* `docker-compose.local.yml`: konfigurasi uji coba lokal lengkap dengan container PostgreSQL sementara.

## Menjalankan Uji Coba Lokal

Prasyarat: Docker dan Docker Compose sudah terpasang dan berjalan.

```bash
docker compose -f docker-compose.local.yml up --build
```

Setelah container sehat, aplikasi dapat diakses melalui:

* Beranda: `http://localhost:3001`
* Form tulis berita: `http://localhost:3001/tambah`
* Pemeriksaan status layanan dan koneksi database: `http://localhost:3001/health`

Untuk menghentikan dan membersihkan container lokal:

```bash
docker compose -f docker-compose.local.yml down -v
```

## Otomatisasi dan Keamanan

* **CI/CD (`.github/workflows/deploy.yml`):** setiap `push` ke branch `main` menjalankan pemeriksaan sintaks Node.js dan uji build Docker image (`build-and-check`), lalu melakukan penarikan kode dan pembaruan container di VPS melalui SSH port kustom menggunakan GitHub Secrets.
* **Infrastructure as Code (`ansible/playbook.yml`):** mengotomatiskan instalasi Nginx, pembuatan user sistem `monitoring`, pembuatan sertifikat SSL self-signed jika belum tersedia, dan distribusi konfigurasi Nginx dari repositori lokal.
* **Keamanan kredensial:** berkas `.env` dan kunci privat SSH tidak disimpan di dalam repositori ini. Gunakan `app/.env.example` sebagai acuan konfigurasi lingkungan di server dan simpan kredensial deployment di GitHub Secrets.