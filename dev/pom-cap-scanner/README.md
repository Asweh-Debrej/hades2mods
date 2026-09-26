# Pom Cap Scanner (dev-only, tidak dirilis)

Menjawab "boon mana saja yang level-nya mentok, dan di level berapa?" langsung dari data game.

Untuk setiap boon god dan setiap rarity, scanner menaikkan level satu per satu (sampai `max_level`, default 25). Boon dianggap mentok di level terakhir sebelum nilai tooltip-nya (`ExtractData`) berhenti berubah. Aturan ini sama persis dengan yang dipakai game untuk menentukan boon mana yang boleh ditawarkan Pom of Power (`GetAllUpgradeableGodTraits`).

## Pemakaian

1. `tools\link.ps1 -Package Pom_Cap_Scanner`, lalu jalankan game (profil Dev) dan load save.
2. Tekan **Insert**, lalu pilih menu **Pom Cap Scanner → Scan all god boons**.
3. Hasil muncul di jendela **Pom caps** (centang *Only capped boons* untuk memfilter). Laporan markdown ditulis ke `ReturnOfModding/plugins_data/AswehDebrej-Pom_Cap_Scanner/pom-caps.md`.

Kolom rarity berisi level mentok; `-` berarti masih naik sampai `max_level`. Kolom verdict:

- `never (BlockStacking)`: boon tidak bisa di-Pom sama sekali.
- `never (nothing scales)`: tidak ada nilai yang naik per level.
- `capped (min clamp / max clamp)`: berhenti karena clamp `MinimumSourceValue`/`MaximumValue`.
- `unlimited`: tidak mentok.

## Perbandingan dengan vanilla

Kalau Limitless Poms terpasang, setiap scan otomatis dijalankan dua kali: sekali dengan mod, dan sekali lagi dengan semua perpanjangan dimatikan sementara (`core.run_vanilla`, config tidak disentuh).

- Sel rarity yang berubah ditulis `vanilla > mod`, misalnya `4 > 12`.
- Centang *Only boons changed by Limitless Poms* untuk melihat hanya boon yang diubah mod. Seharusnya hanya boon di `src/gods.lua` Limitless Poms yang muncul.
- **Pelanggaran**: boon atau rarity yang di vanilla tidak bisa di-Pom (cap 1, `never (...)`) tapi menjadi bisa dengan mod. Barisnya ditandai `!! NOW UPGRADEABLE`, dan status menampilkan jumlahnya. Angkanya harus selalu **0**.

Catatan: scanner memakai rarity multiplier tetap dan `ForceMin` supaya tidak memakai RNG run. Meski begitu, lebih aman menjalankannya di hub, bukan di tengah run.
