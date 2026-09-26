# Hades II Modding Workspace

Studio modding Hades II milik `AswehDebrej`. Target rilis: Thunderstore (r2modman).

## Peta

| Folder | Isi |
| --- | --- |
| `docs/` | Panduan hasil riset: [ekosistem](docs/01-ekosistem.md), [anatomi mod](docs/02-anatomi-mod.md), [API](docs/03-api-cheatsheet.md), [workflow dev](docs/04-workflow-dev.md), [rilis](docs/05-rilis-thunderstore.md), [konvensi](docs/06-konvensi.md), [riset pom caps](docs/research/pom-level-caps.md) |
| `tools/` | Script PowerShell: `setup`, `new-package`, `link`, `build`, `test`, `icons`, `tail-log` |
| `tests/` | Uji offline (Lua 5.2 via Python `lupa`) terhadap script game asli |
| `dev/` | Paket khusus development yang tidak dirilis: `pom-cap-scanner` |
| `mods/` | Satu repo git per family mod (di-gitignore di sini) |
| `mods/limitless-poms/` | **Limitless Poms**: satu mod (layout template resmi); boon per god di `src/gods.lua`, pengaturan di `src/config.lua` |
| `reference/` | Junction read-only ke `Content/Scripts` dan `Content/Game` milik game (dibuat `setup.ps1`) |
| `workspace.json` | Path game, folder r2modman, profil dev, namespace |

## Quickstart

```powershell
tools\setup.ps1          # tcli, definisi Lua, reference/, .luarc.json
tools\test.ps1           # uji offline
tools\link.ps1           # hubungkan semua paket ke profil r2modman "Dev"
# r2modman > profil Dev > Start modded   (Insert = overlay Hell2Modding)
```

Detail lengkap: [docs/04-workflow-dev.md](docs/04-workflow-dev.md).
