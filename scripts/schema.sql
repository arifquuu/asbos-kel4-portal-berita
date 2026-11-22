CREATE TABLE IF NOT EXISTS kategori (
  id SERIAL PRIMARY KEY,
  nama VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS berita (
  id SERIAL PRIMARY KEY,
  judul VARCHAR(255) NOT NULL,
  ringkasan TEXT,
  isi TEXT NOT NULL,
  penulis VARCHAR(100) NOT NULL,
  kategori_id INT REFERENCES kategori(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO kategori (nama) VALUES
  ('Akademik'),
  ('Kemahasiswaan'),
  ('Teknologi'),
  ('Pengumuman')
ON CONFLICT (nama) DO NOTHING;

INSERT INTO berita (judul, ringkasan, isi, penulis, kategori_id)
SELECT
  'Contoh Berita: Persiapan Pengumpulan Proyek Akhir Semester 5',
  'Data purwarupa awal untuk memverifikasi pembacaan artikel dari PostgreSQL.',
  'Ini adalah artikel purwarupa untuk menguji alur web server Nginx, container Docker, dan koneksi database PostgreSQL pada proyek Kelompok 4.',
  'Tim Kelompok 4',
  id
FROM kategori
WHERE nama = 'Akademik'
  AND NOT EXISTS (SELECT 1 FROM berita);