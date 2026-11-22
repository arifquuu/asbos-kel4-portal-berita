require('dotenv').config();
const express = require('express');
const path = require('path');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || 'v1.0';

const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME || 'portal_berita_db',
    user: process.env.DB_USER || 'berita_user',
    password: process.env.DB_PASS || '',
});

// Baca IP asli klien dari header X-Forwarded-For yang dikirim Nginx reverse proxy.
app.set('trust proxy', 1);
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.urlencoded({ extended: true }));

function renderError(res, statusCode, pesan) {
    return res.status(statusCode).render('error', {
        statusCode,
        pesan,
        appVersion: APP_VERSION,
    });
}

app.get('/', async (req, res) => {
    try {
        const kategoriId = req.query.kategori ? Number(req.query.kategori) : null;
        const kategoriRes = await pool.query('SELECT id, nama FROM kategori ORDER BY nama ASC');

        let beritaQuery = `
      SELECT b.id, b.judul, b.ringkasan, b.penulis, b.created_at, k.nama AS nama_kategori
      FROM berita b
      LEFT JOIN kategori k ON b.kategori_id = k.id
    `;
        const params = [];

        if (kategoriId && !Number.isNaN(kategoriId)) {
            beritaQuery += ' WHERE b.kategori_id = $1';
            params.push(kategoriId);
        }
        beritaQuery += ' ORDER BY b.created_at DESC';

        const beritaRes = await pool.query(beritaQuery, params);
        res.render('index', {
            daftarBerita: beritaRes.rows,
            daftarKategori: kategoriRes.rows,
            kategoriAktif: kategoriId && !Number.isNaN(kategoriId) ? kategoriId : null,
            appVersion: APP_VERSION,
        });
    } catch (err) {
        console.error('Error mengambil daftar berita:', err.message);
        renderError(res, 500, 'Gagal memuat berita dari database. Periksa koneksi PostgreSQL atau coba lagi.');
    }
});

app.get('/berita/:id', async (req, res) => {
    const beritaId = Number(req.params.id);
    if (!Number.isInteger(beritaId) || beritaId <= 0) {
        return renderError(res, 400, 'ID berita tidak valid.');
    }

    try {
        const { rows } = await pool.query(
            `SELECT b.*, k.nama AS nama_kategori
       FROM berita b
       LEFT JOIN kategori k ON b.kategori_id = k.id
       WHERE b.id = $1`,
            [beritaId]
        );
        if (rows.length === 0) {
            return renderError(res, 404, 'Berita yang diminta tidak ditemukan.');
        }
        res.render('detail', { berita: rows[0], appVersion: APP_VERSION });
    } catch (err) {
        console.error('Error mengambil detail berita:', err.message);
        renderError(res, 500, 'Terjadi kesalahan saat mengambil detail berita dari database.');
    }
});

app.get('/tambah', async (req, res) => {
    try {
        const kategoriRes = await pool.query('SELECT id, nama FROM kategori ORDER BY nama ASC');
        res.render('tambah', { daftarKategori: kategoriRes.rows, appVersion: APP_VERSION });
    } catch (err) {
        console.error('Error memuat form:', err.message);
        renderError(res, 500, 'Gagal memuat daftar kategori untuk form tambah berita.');
    }
});

app.post('/tambah', async (req, res) => {
    const { judul, ringkasan, isi, penulis, kategori_id } = req.body;
    if (!judul || !isi || !penulis) {
        return renderError(res, 400, 'Judul, penulis, dan isi berita wajib diisi.');
    }
    try {
        // Gunakan parameterized query untuk mencegah SQL injection.
        await pool.query(
            `INSERT INTO berita (judul, ringkasan, isi, penulis, kategori_id)
       VALUES ($1, $2, $3, $4, $5)`,
            [judul.trim(), (ringkasan || '').trim(), isi.trim(), penulis.trim(), Number(kategori_id) || null]
        );
        res.redirect('/');
    } catch (err) {
        console.error('Error menyimpan berita:', err.message);
        renderError(res, 500, 'Gagal menyimpan berita ke database. Pastikan database aktif dan coba lagi.');
    }
});

app.get('/health', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.status(200).json({ status: 'ok', database: 'connected', version: APP_VERSION });
    } catch (err) {
        res.status(500).json({ status: 'error', database: 'disconnected', version: APP_VERSION });
    }
});

app.use((req, res) => {
    renderError(res, 404, 'Halaman yang kamu akses tidak tersedia.');
});

// Bind ke 0.0.0.0 di dalam container agar dapat diteruskan oleh port mapping host 127.0.0.1:3000.
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Portal Berita Mahasiswa (${APP_VERSION}) berjalan di port ${PORT}`);
});