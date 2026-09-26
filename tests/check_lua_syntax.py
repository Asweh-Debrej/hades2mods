"""Compiles every Lua file of every package with Lua 5.2 (the game's version) to catch syntax errors
before launching the game. Run it with tools/test.ps1."""
import glob
import os
import sys

from lupa import lua52

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lua = lua52.LuaRuntime()
compile_chunk = lua.eval("function(code, name) local f, err = load(code, '=' .. name) return err end")

files = [
    path
    for pattern in ("mods/*/src/*.lua", "mods/*/packages/*/src/*.lua", "dev/*/src/*.lua", "tools/templates/package/src/*.lua")
    for path in glob.glob(os.path.join(ROOT, pattern))
]
errors = []
for path in sorted(files):
    rel = os.path.relpath(path, ROOT)
    error = compile_chunk(open(path, encoding="utf-8").read(), rel)
    if error:
        errors.append(error)
        print(f"[FAIL] {error}")

print(f"{len(files)} Lua files checked, {len(errors)} with syntax errors")
sys.exit(1 if errors else 0)
