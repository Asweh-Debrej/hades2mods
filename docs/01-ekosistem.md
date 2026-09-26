# 01 · Ekosistem modding Hades II

Versi di bawah ini dicek pada 2026-09-25 lewat API Thunderstore. Cek ulang sebelum menaikkan dependency.

## Distribusi: Thunderstore (r2modman), bukan Nexus

Komunitas Hades II memakai **Thunderstore**. r2modman dan Thunderstore Mod Manager hanyalah aplikasi yang mengunduh dari sana. Mod format lama (Nexus/ModImporter) **tidak kompatibel**. "Rilis ke r2modman" artinya publish paket ke komunitas `hades-ii` di Thunderstore.

## Loader: Hell2Modding

| | |
| --- | --- |
| Paket | `Hell2Modding-Hell2Modding` (1.0.112) |
| File | `d3d12.dll` di folder `Ship/` game (r2modman memasangnya otomatis) |
| Basis | ReturnOfModding (RoM) + lovely-lib (patch Lua) |
| Overlay | ImGui, dibuka dengan tombol **Insert** (console log, menu mod) |
| Log | `<profil>/ReturnOfModding/LogOutput.log` |

Hell2Modding memuat setiap plugin dari `ReturnOfModding/plugins/<Namespace>-<Nama>/main.lua`. Urutan load mengikuti dependency di `manifest.json`. Setiap plugin mendapat global `rom` (API loader) dan `_PLUGIN` (info plugin).

## Library standar (dipakai hampir semua mod)

| Paket | Versi | Fungsi |
| --- | --- | --- |
| `LuaENVY-ENVY` | 1.2.1 | Environment privat per plugin; menyediakan `public`, `import`. (`SGG_Modding-ENVY` sudah deprecated.) |
| `SGG_Modding-ModUtil` | 4.0.1 | Wrap/override fungsi game, `once_loaded.game`, util. |
| `SGG_Modding-ReLoad` | 1.0.3 | Hot reload: memisahkan kode "sekali" (ready) dan "setiap reload" (reload). |
| `SGG_Modding-Chalk` | 2.1.2 | Config `.cfg` yang bisa diedit di r2modman, dibuat dari `config.lua`. |
| `SGG_Modding-SJSON` | 1.0.2 | Baca/tulis/hook file `.sjson` (data animasi, teks, GUI). Tambahkan hanya kalau dipakai. |

Karena hampir semua user sudah memasang library ini lewat mod lain, bergantung padanya tidak membuat download terasa berat.

## Tool dev (hanya di profil Dev)

| Paket/tool | Kegunaan |
| --- | --- |
| `SGG_Modding-Hades2GameDef` | Definisi luaCATS seluruh global game → autocomplete di VS Code |
| `SGG_Modding-SeerSuite` | Object browser + script console di overlay |
| `PonyWarrior-PonyMenu` | Menu cheat/test: ambil boon, pom, resource dengan cepat |
| `tcli` (Thunderstore CLI) | `tcli build` / `tcli publish` (dipasang oleh `tools/setup.ps1`) |
| `deppth2`, Fmod Bank Tools, HadesMapper | Aset: texture `.pkg`, audio `.bank`, map. Belum dibutuhkan. |

## Sumber resmi

- Wiki: <https://sgg-modding.github.io/Hades2ModWiki/>, terutama *Creating Mods* dan *Hell2Modding Docs*
- Template: <https://github.com/SGG-Modding/Hades2ModTemplate> (basis semua paket di workspace ini, v0.10.0)
- Loader: <https://github.com/SGG-Modding/Hell2Modding>
- Library: <https://github.com/SGG-Modding> (ModUtil, ReLoad, Chalk, SJSON-Plugin, SeerSuite), <https://github.com/LuaENVY/ENVY>
- Thunderstore: <https://thunderstore.io/c/hades-ii/>
- Discord Hades Modding: <https://discord.gg/KuMbyrN>
- **Script game sendiri**: `reference/game-scripts/` (junction ke `Content/Scripts`). Ini sumber kebenaran untuk nama fungsi dan data.
