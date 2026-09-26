# 05 · Rilis ke Thunderstore (r2modman)

## Persiapan (sekali)

1. Login ke <https://thunderstore.io> (pakai akun GitHub), lalu buka **Settings → Teams → buat team `AswehDebrej`**. Nama team menjadi namespace dan **permanen**.
2. Di halaman team: **Service Accounts → buat baru**, lalu salin API token-nya (hanya ditampilkan sekali).
3. Buat repo GitHub untuk setiap mod, misalnya `Asweh-Debrej/limitless-poms` dari `mods/limitless-poms` (nama akun GitHub boleh berbeda dari namespace Thunderstore), lalu push.
4. Di repo GitHub: **Settings → Secrets and variables → Actions → New repository secret** `TCLI_AUTH_TOKEN` = token tadi.

## Checklist sebelum rilis

- [ ] `tools\test.ps1` lulus, dan sudah diuji di game.
- [ ] Pom Cap Scanner: "0 non-upgradeable boons made upgradeable", dan daftar *changed* hanya berisi boon di `gods.lua`.
- [ ] Paket hasil `tools\build.ps1` sudah dicoba lewat *Import local mod* di profil bersih.
- [ ] README (bahasa Inggris, untuk user) sudah menjelaskan apa yang berubah, cara install, dan bahwa config bersifat opsional.
- [ ] CHANGELOG: semua perubahan tercatat di bawah `## [Unreleased]`.
- [ ] `icon.png` dibuat lewat `tools\icons.ps1`.
- [ ] Deskripsi di `thunderstore.toml` maksimal 250 karakter dan memuat kata kunci yang biasa dicari user ("pom", nama boon, nama god).

## Menjalankan rilis

GitHub → **Actions → Release → Run workflow** (workflow asli dari template resmi):

- `tag`: versi `Major.Minor.Patch` (semver)
- centang **dry-run** dulu, lalu unduh artifact zip dan periksa isinya

Workflow otomatis: memutar `[Unreleased]` di CHANGELOG, menulis versi ke `thunderstore.toml`, `tcli build`, `tcli publish`, commit + tag `<versi>`, lalu membuat GitHub release. Setelah selesai, jalankan `git pull`. Versi yang sudah dipublish **tidak bisa ditarik**; perbaikan selalu lewat versi baru.

## Versi

- **Patch** (0.1.1): perbaikan bug tanpa mengubah perilaku yang diharapkan.
- **Minor** (0.2.0): boon/god baru, opsi config baru, atau perubahan balance.
- **Major** (1.0.0): perubahan besar yang tidak kompatibel (misalnya nama kunci config berubah).
