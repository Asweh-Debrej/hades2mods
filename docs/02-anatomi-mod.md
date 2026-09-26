# 02 · Anatomi sebuah mod

## Paket (repo) → yang terpasang di game

```
<paket>/                          terpasang di profil r2modman sebagai:
├─ thunderstore.toml   ─ tcli ─►  manifest.json  (nama, versi, dependency → urutan load)
├─ README.md, CHANGELOG.md, LICENSE, icon.png (256×256)
├─ src/                ───────►  ReturnOfModding/plugins/<Namespace>-<Nama>/
│  ├─ main.lua                   entry point (boilerplate template)
│  ├─ ready.lua                  jalan SEKALI
│  ├─ reload.lua                 jalan ulang setiap hot reload
│  ├─ ready_late.lua / reload_late.lua   sama, tapi setelah SEMUA mod lain dimuat
│  ├─ config.lua                 default config (Chalk)
│  └─ def.lua                    dokumentasi API publik (hanya untuk library)
└─ data/  (opsional)   ───────►  ReturnOfModding/plugins_data/<Namespace>-<Nama>/   (.pkg, .bank, sjson baru)
```

GUID sebuah mod adalah `<Namespace>-<Nama>`, misalnya `AswehDebrej-Limitless_Poms`. **Namespace dan nama tidak bisa diganti setelah rilis.**

## Alur `main.lua` (boilerplate template)

1. `rom.mods['LuaENVY-ENVY'].auto()`: semua global yang kamu definisikan menjadi **privat** untuk plugin ini. Tersedia `public` (terlihat mod lain lewat `rom.mods[GUID]`) dan `import 'file.lua'`.
2. `game = rom.game` dan `import_as_fallback(game)`: global game (`TraitData`, `CurrentRun`, `GetProcessedValue`, …) bisa dipanggil langsung. Menulis `game.X` membuatnya lebih eksplisit.
3. Mengambil library: `modutil`, `chalk`, `reload` (plus `sjson` kalau dipakai).
4. `config = chalk.auto 'config.lua'` membuat/mengupdate `<profil>/ReturnOfModding/config/<GUID>.cfg`.
5. `modutil.once_loaded.game(...)` menunggu sampai script game selesai dimuat, lalu `loader.load("early", on_ready, on_reload)`.
6. `rom.mods.on_all_mods_loaded(...)`: tahap `late` untuk integrasi dengan mod lain.

## Aturan emas ready vs reload

| File | Kapan jalan | Isinya |
| --- | --- | --- |
| `ready.lua` | sekali | **Memasang hook**: `modutil.mod.Path.Wrap`, `sjson.hook`, `OnControlPressed`, `rom.gui.add_*` |
| `reload.lua` | pertama kali + setiap file berubah | **Definisi** fungsi dan data yang dipanggil oleh hook |

Hook di `ready.lua` sebaiknya hanya memanggil fungsi global yang didefinisikan di `reload.lua`. Dengan begitu, saat `reload.lua` diedit dan disimpan, logika baru langsung aktif tanpa hook terpasang dua kali. Contoh nyata: `mods/limitless-poms/src/ready.lua` + `reload.lua`.

Urutan pada load pertama: `on_ready` (ready.lua) → `on_reload` (reload.lua). Jadi kode yang *dieksekusi langsung* di ready.lua tidak boleh bergantung pada isi reload.lua. Yang boleh adalah *memanggilnya dari dalam hook*, karena hook baru jalan belakangan.

## Config (Chalk)

```lua
-- config.lua
return {
  enabled = true;
  Hephaestus = {        -- tabel bersarang = section tersendiri di .cfg / config editor r2modman
    step_fraction = 0.25;
  };
}, {                    -- tabel kedua = deskripsi di file .cfg (strukturnya sama)
  enabled = 'Master switch.';
  Hephaestus = { step_fraction = 'Share removed per extra Pom.' };
}
```

Tanpa kunci `version`, Chalk mempertahankan nilai yang sudah diubah pemain dan hanya menambahkan kunci baru dari default. Pakai `version` hanya kalau memang perlu *memaksa* default baru menimpa nilai lama pemain. Nilai config dibaca lewat wrapper (`config.Hephaestus.step_fraction`), jadi cukup dibaca saat dipakai supaya perubahan di config editor langsung berlaku.

⚠️ Deskripsi harus diberikan sebagai **nilai return kedua dari `config.lua`**. Jangan oper lewat argumen `chalk.auto(file, nil, descript)`: di Chalk 2.1.2 posisi argumennya bergeser, sehingga argumen itu terbaca sebagai nama section.

## `_PLUGIN` (per plugin)

`guid`, `version`, `plugins_mod_folder_path`, `plugins_data_mod_folder_path` (tempat file yang ditulis mod, misalnya laporan), `config_mod_folder_path`.
