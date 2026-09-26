# 06 · Konvensi workspace

## Struktur

- `mods/<mod>/` = **satu repo git per mod**, dengan layout template resmi (`thunderstore.toml` dan `src/` di root repo, workflow Release bawaan template). Contoh: `limitless-poms`.
- Variasi dalam satu mod (misalnya per god) diatur lewat config, bukan dipecah jadi banyak paket.
- `dev/<tool>/` = paket khusus pengembangan yang tidak dirilis. Masuk repo workspace.
- Paket baru selalu dibuat lewat `tools\new-package.ps1`, supaya boilerplate dan versi dependency seragam.
- Bahasa: kode, komentar kode, README/CHANGELOG paket dalam **bahasa Inggris** (dibaca user Thunderstore). `docs/` dalam bahasa Indonesia.

## Penamaan

- Namespace: `AswehDebrej`. Nama paket memakai `Snake_Case_Dengan_Underscore` (underscore tampil sebagai spasi), misalnya `Limitless_Poms`.
- Global privat di dalam plugin memakai `snake_case` (`process_tagged_ramp`). API publik ditaruh di `public.*` dan didokumentasikan di `def.lua`.
- Penanda yang ditulis ke data game diberi nama mod (`LimitlessPoms`), supaya tidak bentrok dengan mod lain.

## Kompatibilitas dan keamanan

1. **Wrap, jangan Override.** Jalur yang tidak kita tangani harus langsung memanggil `base(...)`.
2. **Jangan mengonsumsi RNG tambahan.** Game memakai RNG ber-seed. Memanggil fungsi vanilla berkali-kali hanya aman kalau fungsi itu deterministik (contoh: Limitless Poms hanya memproses ramp dengan `BaseValue` tetap).
3. **State mod tidak masuk save** kecuali memang disengaja. Taruh di tabel `mod` hasil `modutil.mod.Mod.Register`, karena tabel itu diabaikan oleh save.
4. Ubah data sesempit mungkin: tandai tabel spesifik, jangan menimpa seluruh `TraitData`.
5. Hook dipasang di `ready*.lua`, logika ada di `reload*.lua` (bisa di-hot-reload).

## Untuk user

- User jarang membuka config: alurnya cari → baca deskripsi → download → main. **Default harus sudah enak dimainkan**, dan config hanya bonus.
- README paket: paragraf pertama menjelaskan masalahnya, disusul tabel "vanilla vs mod", lalu cara install. Config diletakkan di bagian akhir dan diberi label *optional*.
- Deskripsi Thunderstore (maksimal 250 karakter) harus memuat kata yang dicari user: "Pom", nama boon, nama god.
- Config hanya berisi hal yang memang ingin diatur pemain: on/off (master dan per god), besar langkah, dan batas bawah. Hal yang sudah ditentukan lewat pilihan download, seperti versi, tidak masuk config. Chalk juga tidak butuh kunci `version`.
- Semua pengaturan dibaca live saat dipakai, jadi perubahan di config editor langsung berlaku tanpa restart.

## Git

- Commit kecil dengan pesan yang jelas. Rilis dari branch `main` lewat workflow, jangan edit versi secara manual.
- `build/`, dan salinan `manifest.json`/`icon.png`/… di `src/` (hasil `tools\link.ps1`), di-gitignore.
