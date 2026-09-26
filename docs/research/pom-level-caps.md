# Riset · Kenapa level boon "mentok" di Pom of Power

Dicek pada Hades II 1.0 (script terpasang, 2026-09-25). Path relatif ke `reference/game-scripts/`.

## Mekanisme

1. **Pom hanya menawarkan boon yang nilainya berubah.** `GetAllUpgradeableGodTraits(stackNum)` (`TraitLogic.lua:1673`) menghitung trait pada level +1, lalu membandingkan `ExtractData` (angka di tooltip, sudah dibulatkan) dengan level sekarang. Kalau semuanya sama, boon tidak ditawarkan.
2. **Nilai per level** dihitung oleh `GetProcessedValue(ramp, args, key)` (`TraitLogic.lua:213`):
   - level 1 = `BaseValue × rarityMultiplier`
   - level berikutnya menambah `AbsoluteStackValues[i]`. Kalau `i` melewati panjang daftar, entri **terakhir** dipakai berulang, dan nilai ini tidak dikali rarity.
   - setiap langkah dilewatkan ke `ProcessValue` (`TraitLogic.lua:349`): pembulatan (`DecimalPlaces`, default 2), lalu clamp `MaximumValue` dan `MinimumSourceValue`.
3. Akibatnya, nilai yang terjepit clamp berhenti berubah. Kalau itu satu-satunya nilai yang naik per level, boon **mentok**.
4. `BlockStacking = true` membuat boon tidak bisa di-Pom sama sekali (`GetAllUpgradeableGodTraits` langsung melewatinya).

Contoh: Volcanic Strike (`TraitData_Hephaestus.lua:45`)

```lua
Cooldown = { BaseValue = 12, MinimumSourceValue = 2, AbsoluteStackValues = { [1] = -2, [2] = -1 } }
-- rarity: Common 1.0, Rare 10/12, Epic 8/12, Heroic 6/12
-- Heroic: 6 → 4 → 3 → 2 → (mentok di level 4)    Common: 12 → 10 → 9 → … → 2 (mentok di level 10)
```

## Boon yang benar-benar mentok (diverifikasi dengan fungsi asli game, 2026-09-26)

Level mentok = level terakhir yang nilainya masih berubah, per rarity Common / Rare / Epic / Heroic.

| God | Boon (nama internal) | Nilai yang mentok | Level mentok vanilla |
| --- | --- | --- | --- |
| Hephaestus | Volcanic Strike (`HephaestusWeaponBoon`) | Cooldown ledakan, min 2 dtk | 10 / 8 / 6 / 4 (Heroic: 6→4→3→2) |
| Hephaestus | Volcanic Flourish (`HephaestusSpecialBoon`) | Cooldown ledakan, min 2 dtk | 12 / 10 / 8 / 6 |
| Hephaestus | Smithy Rush (`HephaestusSprintBoon`) | Cooldown ledakan, min 2 dtk | 9 / 8 / 7 / 6 |
| Zeus | Ionic Gain (`ZeusManaBoon`) | *Reappearance Time* orb Magick, min 2 dtk | 9 / 8 / 7 / 6 (10→9→…→2) |
| Hera | Born Gain (`HeraManaBoon`) | *Magick Primed* (Magick yang dikunci), min 5 | 15 / 13 / 11 / 9 (20→18→17→…→5) |

Semuanya bertipe "nilai turun lalu mentok di `MinimumSourceValue`", jadi Limitless Poms menanganinya dengan satu mekanisme yang sama.

## Salah kira dari grep awal (BUKAN batas level)

| Boon | Kenapa bukan batas |
| --- | --- |
| Aphrodite, Healthy Rebound (`DoorHealToFullBoon`) | `MaximumValue = 100` hanya batas **teks tooltip** heal 100%. Nilai yang naik per level (threshold) terus berubah. |
| Ares, Grievous Blow (`AresStatusDoubleDamageBoon`) | Peluang 200% damage dibatasi 100%, tapi baru tercapai di **level 78–87**. |
| Ares, Visceral Impact (`BloodDropRevengeBoon`) | Peluang Blood Drop ganda dibatasi 100%, baru tercapai di **level 29–37**. Batas peluang 100% memang wajar. |
| Chaos, Discovery (`ChaosHarvestBlessing`) | Blessing Chaos (`GodLoot = false`) memang **tidak bisa di-Pom** di vanilla, jadi di luar scope (lihat invarian di bawah). |
| Hestia, boon burn | `MinValue = 1` adalah batas bawah tambahan per level, jadi nilainya tetap naik. |
| Demeter, `ReserveManaHitShieldBoon` | Punya clamp minimum, tapi `BlockStacking`, jadi tidak bisa di-Pom sama sekali. Di luar scope. |

**BlockStacking** (tidak bisa di-Pom): base class `LegendaryTrait`, `SynergyTrait` (Duo), `UnityTrait` (sehingga semua Legendary dan Duo ikut); `HealthRewardBonusBoon`, `FocusRawDamageBoon` (Aphrodite); `MissingHealthCritBoon`, `LowHealthLifestealBoon` (Ares); `FocusCritBoon` (Artemis); `BoonGrowthBoon`, `ReserveManaHitShieldBoon` (Demeter); `ElementalRarityUpgradeBoon`, `ElementalDamageCapBoon`; `HephaestusManaBoon`, `HeavyArmorBoon`, `ManaToHealthBoon` (Hephaestus); `DamageShareRetaliateBoon`, `BoonDecayBoon` (Hera); `HermesCastDiscountBoon`, `LuckyBoon` (Hermes); `NarcissusA`; `RoomRewardBonusBoon` (Poseidon); `LimitedSwapBonusTrait`.

**Tidak berskala** (tidak ada nilai yang naik per level): tidak bisa dideteksi lewat grep. Pakai **Pom Cap Scanner** untuk daftar pasti per rarity. Scanner juga yang menjadi acuan final untuk tabel "benar-benar mentok" di atas.

## Keputusan desain Limitless Poms (v1)

- Target: clamp `MinimumSourceValue` pada nilai dengan `BaseValue` tetap. v1 hanya mencakup Hephaestus.
- **Invarian: yang dilepas hanya batas, bukan status "tidak bisa di-Pom".** Boon yang di vanilla tidak bisa naik level (`BlockStacking`, atau nilainya tidak berubah sama sekali per level) harus tetap begitu. Ini ditegakkan di tiga lapis:
  1. `extend_min_clamps` menolak trait `BlockStacking`.
  2. Sebuah nilai hanya diperpanjang kalau di vanilla nilai itu memang **sempat membaik** sebelum mentok. Nilai yang sudah di batas minimum sejak level 1 (misalnya karena rarity multiplier) dikembalikan persis seperti vanilla.
  3. Hanya trait yang terdaftar di `src/gods.lua` yang disentuh.

  Uji offline: 5 kasus di `tests/test_limitless_poms.py`. Uji di game: Pom Cap Scanner membandingkan vanilla dengan mod dan menandai `!! NOW UPGRADEABLE` kalau ada pelanggaran.
- Aturan: nilai vanilla dipakai selama masih turun. Setelah mentok, setiap level turun **maksimal 25% dari nilai sebelumnya** (`step_fraction`), dengan batas bawah `hard_floor` = 0.1.
- Karena tooltip membulatkan ke 1 desimal, Pom berhenti secara alami di sekitar **0.2 detik**: 2 → 1.5 → 1.1 → 0.9 → 0.6 → 0.5 → 0.4 → 0.3 → 0.2. Heroic Volcanic Strike mentok di level 12, bukan 4.
- Implementasi: satu `Path.Wrap` pada `GetProcessedValue`; ramp yang ditandai dihitung ulang (lihat `mods/limitless-poms/src/reload.lua`). Sudah diuji offline terhadap fungsi asli game (`tests/test_limitless_poms_core.py`).
- Berikutnya: Zeus (Ionic Gain) dan Hera (Born Gain), dengan aturan yang sama.
- Tidak akan dikerjakan: boon yang tidak bisa di-Pom di vanilla (`BlockStacking`, blessing Chaos, boon yang tidak berskala). Ini sesuai invarian.
