# 04 · Workflow development

## Sekali saja

1. **r2modman → Hades II → buat profil `Dev`.** Pisahkan dari profil main supaya mod gameplay lain tidak mengganggu pengujian.
2. Di profil Dev, install **PonyMenu** (otomatis menarik semua library standar), **SeerSuite**, dan **Hades2GameDef**.
3. Jalankan profil Dev sekali lewat *Start modded*, lalu tutup lagi (supaya folder `ReturnOfModding` terbentuk).
4. `tools\setup.ps1` akan menginstal `tcli`, mengambil definisi Lua, membuat `reference/` dan `.luarc.json`. Jalankan ulang setiap kali memasang library baru.
5. VS Code: buka **folder root workspace**, lalu install ekstensi yang direkomendasikan (Lua by sumneko).

## Loop harian

```powershell
tools\link.ps1                 # junction semua paket ke profil Dev (ulang kalau thunderstore.toml berubah)
# r2modman > profil Dev > Start modded
tools\tail-log.ps1 -Match AswehDebrej   # ikuti log mod kita
```

- Edit `reload.lua` lalu simpan: ReLoad memuat ulang plugin tanpa restart game.
- Edit `ready.lua` atau `main.lua`: game perlu direstart, karena hook hanya dipasang sekali.
- Error Lua muncul di overlay (**Insert**) dan di `LogOutput.log`.
- Kalau hot reload tidak terpicu lewat junction, restart game saja. Alternatifnya, pakai symlink (butuh Developer Mode atau admin), lihat wiki bagian *Local Testing*.

## Uji tanpa membuka game

```powershell
tools\test.ps1    # syntax semua file Lua (Lua 5.2) + tests\test_*.py
```

`tests/test_limitless_poms.py` menjalankan `reload.lua` Limitless Poms bersama `GetProcessedValue` dan `ProcessValue` **yang diambil langsung dari script game terpasang**. Jadi kalau game update dan mengubah fungsi itu, tes ini akan ikut mendeteksinya.

## Uji di game

- **PonyMenu**: ambil boon tertentu dengan rarity tertentu, dan beri Pom berulang-ulang.
- **Pom Cap Scanner** (`dev/pom-cap-scanner`): Insert → *Pom Cap Scanner* → *Scan all god boons*. Laporannya ditulis ke `plugins_data/AswehDebrej-Pom_Cap_Scanner/pom-caps.md`. Scan otomatis membandingkan hasil vanilla dengan hasil mod. Wajib dicek sebelum rilis: **"0 non-upgradeable boons made upgradeable"**, dan daftar *changed* hanya berisi boon yang memang didaftarkan.
- **SeerSuite console**: jalankan Lua langsung, misalnya `print(TraitData.HephaestusWeaponBoon.OnEnemyDamagedAction.Args.Cooldown.MinimumSourceValue)`.

## Uji paket persis seperti rilis

```powershell
tools\build.ps1        # build/<GUID>-<versi>.zip untuk setiap paket
```

Buat profil r2modman kosong, lalu *Settings → Import local mod* untuk zip-nya. Ingat: import lokal **tidak** mengunduh dependency secara otomatis, jadi install PonyMenu dulu (untuk library standar).

## Ikon paket

```powershell
tools\icons.ps1 -Preview    # tulis icon.png setiap paket + .cache\icons-preview.png (256/64/32 px)
```

- Art Pom of Power (`Items\Loot\StackUpgrade`) dan simbol god (`GUI\Screens\BoonSelectSymbols\<God>`) di-extract dari `GUI.pkg` milik game-mu dengan deppth2, ke `.cache\game-textures` (di-gitignore, jangan di-commit). Hanya atlas yang dibutuhkan yang di-extract.
- Latar, bingkai emas, simbol ∞, dan teks (font Cinzel, lisensi OFL, di `tools\icons\fonts`) digambar oleh `tools\icons\make_icons.py`.
- Jenis ikon di `tools\icons\icons.json`: `brand` (Pom + ∞, plus satu medali per god di `gods`), `core` (dengan caption), dan `god` (satu god; warna tema diambil otomatis dari glow simbol god).
- **God baru di Limitless Poms**: tambahkan namanya ke daftar `gods` di entri `mods/limitless-poms`, lalu jalankan ulang. Nama god mengikuti nama file di `BoonSelectSymbols` (Zeus, Hera, Poseidon, Demeter, Apollo, Aphrodite, Ares, Artemis, Athena, Hestia, Hermes, Hephaestus, Chaos, …).
- Ikon memakai art Hades II (hak cipta Supergiant Games). Ini lazim untuk mod di komunitasnya, tapi jangan pakai untuk hal di luar mod.

## Tools

| Script | Fungsi |
| --- | --- |
| `tools\setup.ps1 [-ProfileName X]` | setup/refresh lingkungan dev |
| `tools\new-package.ps1` | paket baru dari skeleton (lihat contoh di header script) |
| `tools\link.ps1 [-Package *Nama*] [-Remove]` | junction `src/` (dan `data/`) ke profil |
| `tools\build.ps1 [-Package *Nama*]` | `tcli build` |
| `tools\test.ps1` | uji offline |
| `tools\icons.ps1 [-Preview]` | generate `icon.png` semua paket dari `tools\icons\icons.json` |
| `tools\tail-log.ps1 [-Match regex]` | ikuti log |

Semua path diatur di `workspace.json` (path game, folder r2modman, profil dev, namespace).
