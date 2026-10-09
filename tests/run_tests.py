"""Runs the Lua tests under Lua 5.1 (the engine's Lua version) via lupa.

    pip install lupa
    python tests/run_tests.py

Use this if you don't have a standalone `lua5.1` on your PATH.
"""

import pathlib
import sys

import lupa.lua51 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent


def main() -> int:
    lua = lupa.LuaRuntime()
    lua.globals().MOD_ROOT = str(ROOT / "mod" / "BAR-Weather.sdd").replace("\\", "/")
    failed = False
    for test_file in sorted((ROOT / "tests").glob("*_test.lua")):
        print(f"== {test_file.name}")
        try:
            lua.execute(f'dofile("{test_file.as_posix()}")')
        except lupa.LuaError as err:
            print(err)
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
