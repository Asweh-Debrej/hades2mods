"""Offline test of Limitless Poms against the game's real GetProcessedValue/ProcessValue.

Runs the mod's reload.lua in Lua 5.2 (same version as the game, via lupa) together with the
functions copied verbatim from the installed game's scripts. Run it with tools/test.ps1.
"""
import json
import os
import re
import sys

from lupa import lua52

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKSPACE = json.load(open(os.path.join(ROOT, "workspace.json"), encoding="utf-8"))
SCRIPTS = os.path.join(WORKSPACE["gamePath"], "Content", "Scripts")
SRC = os.path.join(ROOT, "mods", "limitless-poms", "src")


def extract_function(path, name):
    text = open(path, encoding="utf-8", errors="ignore").read()
    start = text.index(f"function {name}(")
    # top-level functions end at the first line that is exactly "end"
    end = re.compile(r"^end\s*$", re.M).search(text, start).end()
    return text[start:end]


lua = lua52.LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
TraitMultiplierData = { DefaultDiminishingReturnsMultiplier = 0.5, DefaultMinMultiplier = 0.1 }
CurrentRun = { Hero = {} }
function DeepCopyTable(t)
  if type(t) ~= 'table' then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = DeepCopyTable(v) end
  return c
end
""")
lua.execute("\n".join([
    extract_function(os.path.join(SCRIPTS, "UtilityLogic.lua"), "round"),
    extract_function(os.path.join(SCRIPTS, "TraitLogic.lua"), "ProcessValue"),
    extract_function(os.path.join(SCRIPTS, "TraitLogic.lua"), "GetProcessedValue"),
]))
lua.execute("""
function CollapseTableAsOrderedKeyValuePairs(t)
  local out = {}
  for k, v in pairs(t) do table.insert(out, { Key = k, Value = v }) end
  table.sort(out, function(a, b) return tostring(a.Key) < tostring(b.Key) end)
  return out
end
ProcessTraitDataBlacklist = {}
""")

# Plugin environment stubs (what ENVY / Hell2Modding / Chalk provide in game)
lua.execute("""
game = _G
public = {}
_PLUGIN = { guid = 'AswehDebrej-Limitless_Poms' }
warnings = {}
rom = { log = { warning = function(m) table.insert(warnings, m) end, info = print } }
TraitData = {
  -- copied from TraitData_Hephaestus / _Zeus / _Hera.lua
  HephaestusWeaponBoon  = { OnEnemyDamagedAction = { Args = { Cooldown = { BaseValue = 12, MinimumSourceValue = 2, AbsoluteStackValues = { -2, -1 } } } } },
  HephaestusSpecialBoon = { OnEnemyDamagedAction = { Args = { Cooldown = { BaseValue = 14, MinimumSourceValue = 2, AbsoluteStackValues = { -2, -1 } } } } },
  HephaestusSprintBoon  = { OnSprintAction = { Args = { Cooldown = { BaseValue = 10, MinimumSourceValue = 2, AbsoluteStackValues = { -1 } } } } },
  ZeusManaBoon = { SetupFunction = { Args = { Interval = { BaseValue = 10, MinimumSourceValue = 2, AbsoluteStackValues = { -1 } } } } },
  HeraManaBoon = { LastMomentManaRechargeArgs = { Amount = { BaseValue = 20, AsInt = true, MinimumSourceValue = 5, AbsoluteStackValues = { -2, -1 } } } },
  -- synthetic cases for the safeguards (registered through the "Test" group below)
  RandomBase    = { Args = { Value = { BaseMin = 3, BaseMax = 5, MinimumSourceValue = 1, AbsoluteStackValues = { -1 } } } },
  Growing       = { Args = { Value = { BaseValue = 20, MinimumSourceValue = 5, AbsoluteStackValues = { 5 } } } },
  Crossing      = { Args = { Value = { BaseValue = 2.5, MinimumSourceValue = 2, AbsoluteStackValues = { -1 } } } },
  NoClamp       = { Args = { Value = { BaseValue = 10, AbsoluteStackValues = { -1 } } } },
  FlatAtFloor   = { Args = { Value = { BaseValue = 2, MinimumSourceValue = 2, AbsoluteStackValues = { -1 } } } },
  RarityOnFloor = { Args = { Value = { BaseValue = 12, MinimumSourceValue = 2, AbsoluteStackValues = { -2, -1 } } } },
  Locked        = { BlockStacking = true, Args = { Value = { BaseValue = 12, MinimumSourceValue = 2, AbsoluteStackValues = { -1 } } } },
  Unregistered  = { Args = { Value = { BaseValue = 12, MinimumSourceValue = 2, AbsoluteStackValues = { -1 } } } },
}
vanilla_GetProcessedValue = GetProcessedValue
""")
# config.lua returns (defaults, descriptions); Chalk exposes the defaults as `config`
defaults = lua.execute(open(os.path.join(SRC, "config.lua"), encoding="utf-8").read())
lua.globals().config = defaults[0] if isinstance(defaults, tuple) else defaults
lua.execute("config.Test = { enabled = true, step_fraction = 0.25, minimum_seconds = 0.1 }")
gods_path = os.path.join(SRC, "gods.lua").replace("\\", "/")
lua.execute(f"""
function import(file)
  local gods = dofile('{gods_path}')
  gods.Test = {{ rule = 'fraction', boons = {{ 'RandomBase', 'Growing', 'Crossing', 'NoClamp', 'Missing', 'FlatAtFloor', 'RarityOnFloor', 'Locked' }} }}
  return gods
end
""")
lua.execute(open(os.path.join(SRC, "reload.lua"), encoding="utf-8").read())
# Same as ready.lua: modutil.mod.Path.Wrap('GetProcessedValue', ...)
lua.execute("""
local base = GetProcessedValue
GetProcessedValue = function(valueToRamp, args, key)
  if type(valueToRamp) == 'table' and valueToRamp[TAG] then
    return process_tagged_ramp(base, valueToRamp, args, key)
  end
  return base(valueToRamp, args, key)
end
""")

series = lua.eval("""function(ramp, rarity, levels, useVanilla)
  local f = useVanilla and vanilla_GetProcessedValue or GetProcessedValue
  local out = {}
  for level = 1, levels do
    out[level] = f(DeepCopyTable(ramp), { RarityMultiplier = rarity, StackNum = level }, 'Cooldown')
  end
  return out
end""")
nested = lua.eval("""function(traitName, rarity, level)
  -- goes through the parent tables like GetProcessedTraitData does (recursive branch)
  local copy = DeepCopyTable(TraitData[traitName])
  for key, value in pairs(copy) do
    if type(value) == 'table' then copy[key] = GetProcessedValue(value, { RarityMultiplier = rarity, StackNum = level }, key) end
  end
  return copy
end""")


def as_list(t):
    return [round(t[i], 4) for i in range(1, len(t) + 1)]


def ramp(expr):
    return lua.eval(expr)


failures = []


def check(label, got, expected):
    ok = got == expected
    print(f"[{'PASS' if ok else 'FAIL'}] {label}\n        got      {got}")
    if not ok:
        print(f"        expected {expected}")
        failures.append(label)


tagged = {k: v for k, v in lua.eval("public.tagged_traits()").items()}
check("the 5 boons from gods.lua are tagged once each",
      {k: tagged.get(k) for k in ("HephaestusWeaponBoon", "HephaestusSpecialBoon", "HephaestusSprintBoon", "ZeusManaBoon", "HeraManaBoon")},
      {"HephaestusWeaponBoon": 1, "HephaestusSpecialBoon": 1, "HephaestusSprintBoon": 1, "ZeusManaBoon": 1, "HeraManaBoon": 1})
check("warnings for untaggable/unknown/BlockStacking traits", len(list(lua.globals().warnings.values())), 4)

print("\nNon-pommable boons must stay non-pommable")
check("BlockStacking trait is refused (not tagged, flag untouched)",
      (lua.eval("TraitData.Locked.Args.Value[TAG]"), lua.eval("TraitData.Locked.BlockStacking")), (None, True))
check("Unregistered trait is never tagged", lua.eval("TraitData.Unregistered.Args.Value[TAG]"), None)
flat = ramp("TraitData.FlatAtFloor.Args.Value")
check("Value on its minimum from level 1 (never scales in vanilla) stays exactly vanilla",
      as_list(series(flat, 1.0, 12, False)), as_list(series(flat, 1.0, 12, True)))
on_floor = ramp("TraitData.RarityOnFloor.Args.Value")
check("Rarity that puts level 1 on the minimum stays exactly vanilla",
      as_list(series(on_floor, 1 / 6, 12, False)), as_list(series(on_floor, 1 / 6, 12, True)))
check("...while the same boon at a rarity that scales in vanilla is extended",
      as_list(series(on_floor, 1.0, 12, False))[-1] < 2, True)

print("\nHephaestus")
strike = ramp("TraitData.HephaestusWeaponBoon.OnEnemyDamagedAction.Args.Cooldown")
for label, rarity in [("Common", 1.0), ("Heroic", 6 / 12)]:
    vanilla = as_list(series(strike, rarity, 18, True))
    modded = as_list(series(strike, rarity, 18, False))
    first_cap = vanilla.index(2.0)
    check(f"Volcanic Strike {label}: identical to vanilla up to the vanilla cap (level {first_cap + 1})", modded[: first_cap + 1], vanilla[: first_cap + 1])
    after = modded[first_cap:]
    check(f"Volcanic Strike {label}: each level past the cap drops at most 25%",
          all(b <= a and b >= a * 0.75 - 0.01 for a, b in zip(after, after[1:])), True)
    check(f"Volcanic Strike {label}: never below minimum_seconds (0.2)", min(modded) >= 0.2, True)
check("Heroic Volcanic Strike exact sequence", as_list(series(strike, 0.5, 13, False)),
      [6.0, 4.0, 3.0, 2.0, 1.5, 1.13, 0.85, 0.64, 0.48, 0.36, 0.27, 0.2, 0.2])
check("Nested processing (recursive branch) reaches the wrap: Smithy Rush L12 (vanilla would be 2)",
      round(nested("HephaestusSprintBoon", 1.0, 12)["OnSprintAction"]["Args"]["Cooldown"], 4), 0.85)

print("\nZeus and Hera")
ionic = ramp("TraitData.ZeusManaBoon.SetupFunction.Args.Interval")
check("Ionic Gain Heroic: vanilla to 2s at L6, then -25% steps",
      as_list(series(ionic, 0.7, 12, False)), [7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.5, 1.13, 0.85, 0.64, 0.48, 0.36])
born = ramp("TraitData.HeraManaBoon.LastMomentManaRechargeArgs.Amount")
born_heroic = as_list(series(born, 0.7, 15, False))
check("Born Gain Heroic: vanilla to 5 at L9, then -1 per level down to 1", born_heroic, [14, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 1, 1])
born_common = as_list(series(born, 1.0, 21, False))
check("Born Gain Common: vanilla to 5 at L15, then 4, 3, 2, 1 (L19) and stays 1", born_common[14:], [5, 4, 3, 2, 1, 1, 1])
check("Born Gain never shows fractional Magick", all(float(v).is_integer() for v in born_heroic + born_common), True)

print("\nSafeguard cases")
check("Growing value (min clamp but increasing) stays vanilla",
      as_list(series(ramp("TraitData.Growing.Args.Value"), 1.0, 5, False)), as_list(series(ramp("TraitData.Growing.Args.Value"), 1.0, 5, True)))
check("Crossing value keeps vanilla clamp step, then extends",
      as_list(series(ramp("TraitData.Crossing.Args.Value"), 1.0, 4, False)), [2.5, 2.0, 1.5, 1.13])
check("Untagged ramp is untouched",
      as_list(series(ramp("TraitData.NoClamp.Args.Value"), 1.0, 5, False)), as_list(series(ramp("TraitData.NoClamp.Args.Value"), 1.0, 5, True)))
check("Long run converges on the Test group's minimum (0.1)", as_list(series(ramp("TraitData.Crossing.Args.Value"), 1.0, 30, False))[-1], 0.1)

print("\nrun_vanilla and live config")
run_vanilla = lua.eval("function(r) return public.run_vanilla(function() return GetProcessedValue(DeepCopyTable(r), { RarityMultiplier = 0.5, StackNum = 8 }, 'Cooldown') end) end")
check("run_vanilla returns the vanilla value (2) for Heroic Volcanic Strike L8", run_vanilla(strike), 2)
check("...and extension is active again afterwards", as_list(series(strike, 0.5, 8, False))[-1], 0.64)

lua.execute("config.Hephaestus.enabled = false")
check("Hephaestus.enabled=false restores vanilla for Hephaestus", as_list(series(strike, 0.5, 8, False)), as_list(series(strike, 0.5, 8, True)))
check("...while Zeus keeps working", as_list(series(ionic, 0.7, 8, False))[-1], 1.13)
lua.execute("config.Hephaestus.enabled = true; config.enabled = false")
check("master enabled=false restores vanilla for every god",
      (as_list(series(strike, 0.5, 8, False)), as_list(series(born, 0.7, 12, False))),
      (as_list(series(strike, 0.5, 8, True)), as_list(series(born, 0.7, 12, True))))
lua.execute("config.enabled = true; config.Hephaestus.step_fraction = 0.5; config.Hephaestus.minimum_seconds = 0.5")
check("Hephaestus.step_fraction / minimum_seconds apply live", as_list(series(strike, 0.5, 7, False)), [6.0, 4.0, 3.0, 2.0, 1.0, 0.5, 0.5])
lua.execute("config.Hephaestus.minimum_seconds = 5")
check("minimum_seconds above the vanilla limit is clamped to it (never worse than vanilla)",
      as_list(series(strike, 0.5, 7, False)), as_list(series(strike, 0.5, 7, True)))
lua.execute("config.Hephaestus.step_fraction = 0.25; config.Hephaestus.minimum_seconds = 0.2; config.max_extra_levels = 2")
check("max_extra_levels=2 stops two levels past the vanilla limit", as_list(series(strike, 0.5, 8, False)), [6.0, 4.0, 3.0, 2.0, 1.5, 1.13, 1.13, 1.13])
lua.execute("config.max_extra_levels = 0; config.Hera.step = 2; config.Hera.minimum = 2")
check("Hera.step / Hera.minimum apply live", as_list(series(born, 0.7, 12, False))[8:], [5, 3, 2, 2])

print("\nALL PASSED" if not failures else f"\n{len(failures)} FAILED: {failures}")
sys.exit(1 if failures else 0)
