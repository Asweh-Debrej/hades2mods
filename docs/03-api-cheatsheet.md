# 03 · API cheatsheet

Referensi lengkap ada di wiki (*Hell2Modding Docs*) dan di `def.lua` setiap library, yang juga terbaca oleh autocomplete lewat `.luarc.json`.

## ModUtil (`modutil`)

```lua
-- Bungkus fungsi game: kode kamu + fungsi asli (WAJIB panggil base, kecuali memang ingin menggantinya)
modutil.mod.Path.Wrap('SetupMap', function(base, ...)
	before()
	local result = base(...)
	after()
	return result
end)

-- Ganti total (hindari: tidak kompatibel dengan mod lain yang mengubah fungsi yang sama)
modutil.mod.Path.Override('SomeFunction', function(...) end)
modutil.mod.Path.Restore('SomeFunction')

-- Namespace mod yang otomatis tidak ikut tersimpan di save
mod = modutil.mod.Mod.Register(_PLUGIN.guid)

-- Menunggu
modutil.once_loaded.game(fn)   -- script game sudah dimuat
modutil.once_loaded.save(fn)   -- save sudah di-load (sejak main menu)

-- Debug di layar
modutil.mod.Hades.PrintOverhead('teks')
```

Wrap dari beberapa mod pada fungsi yang sama akan dirangkai (stack), jadi aman. Override tidak aman.

## Hell2Modding (`rom`)

| API | Kegunaan |
| --- | --- |
| `rom.mods[GUID]` | `public` milik mod lain (API library) |
| `rom.mods.on_all_mods_loaded(fn)` | setelah semua mod dimuat |
| `rom.log.info/warning/error(...)` | tulis ke LogOutput.log + console overlay |
| `rom.paths.Content()`, `rom.paths.plugins_data()` | path folder game / data |
| `rom.path.combine(a, b, ...)`, `rom.path.create_directory(p)`, `rom.path.exists(p)` | util path |
| `rom.gui.add_to_menu_bar(fn)` / `add_imgui(fn)` / `add_always_draw_imgui(fn)` | UI ImGui di overlay |
| `rom.inputs.on_key_pressed{"Ctrl X", Name = '...', fn}` | keybind |
| `rom.on_import.post(fn)` | setelah game memuat file script tertentu |
| `rom.game.LoadPackages{Name = path}` | memuat `.pkg` kustom |
| `rom.data.reload_game_data()` | muat ulang data sjson |

⚠️ Di plugin yang memakai ENVY, ImGui **tidak** tersedia sebagai global. Ambil dari `rom`: `ImGui = rom.ImGui`, `ImGuiTableFlags = rom.ImGuiTableFlags` (juga `rom.ImGuiCol`, `rom.ImGuiStyleVar`, dan seterusnya). Contoh di wiki menulis `ImGui.*` tanpa prefix. Kalau lupa, callback ImGui akan error setiap frame selama overlay terbuka (ratusan error per detik).

ImGui: `ImGui.Begin/End`, `BeginMenu/MenuItem/EndMenu`, `BeginTable/TableSetupColumn/TableHeadersRow/TableNextRow/TableSetColumnIndex/EndTable`, `Text`, `Checkbox` (mengembalikan nilai baru). **Lua 5.2 tidak punya operator `|`.** Untuk menggabung flag, pakai `bit32.bor(a, b)`.

## SJSON (`sjson`)

```lua
local file = rom.path.combine(rom.paths.Content(), 'Game/Text/en/ShellText.en.sjson')
sjson.hook(file, function(data)          -- dijalankan saat game membaca file (sekali, di awal)
	for _, v in ipairs(data.Texts) do
		if v.Id == 'MainMenuScreen_PlayGame' then v.DisplayName = 'Main!' end
	end
end)
local data = sjson.decode_file(path)     -- baca saja
```

Untuk menambah file sjson **baru**, taruh di `data/Hell2Modding-SJSON/<subfolder Game>/<GUID>_Nama.sjson`. Nama file harus unik, tidak boleh sama dengan file vanilla.

## Data dan logika game yang sering dipakai

| Global | Isi |
| --- | --- |
| `TraitData[nama]` | definisi boon/trait (`TraitData_<God>.lua`) |
| `LootData[god].TraitIndex` | boon milik setiap god |
| `CurrentRun.Hero.Traits` | boon yang sedang dimiliki |
| `GetProcessedTraitData{ Unit, TraitName, Rarity, StackNum }` | trait yang sudah dihitung nilainya |
| `GetProcessedValue(ramp, args, key)` | hitung satu nilai ber-level (BaseValue, AbsoluteStackValues, rarity) |
| `ProcessValue(value, ramp)` | pembulatan + clamp `MinimumSourceValue`/`MaximumValue` |
| `AddTraitToHero`, `IncreaseTraitLevel`, `GetAllUpgradeableGodTraits` | tambah boon, naik level (Pom), daftar boon yang bisa di-Pom |

Nama tampilan boon ada di `reference/game-data/Text/en/TraitText.en.sjson`, dicari berdasarkan `Id` = nama internal.
