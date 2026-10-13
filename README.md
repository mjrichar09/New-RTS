# BAR Weather

A community mod for [Beyond All Reason](https://www.beyondallreason.info) that adds dynamic weather and a day/night cycle with real gameplay effects. See [PLAN.md](PLAN.md) for the full design and roadmap.

**Status:** Phases 1–2 are done: weather cycles in game, with a top-bar weather panel, forecast, "who is favored" tooltip and warnings before each change. There are no gameplay or visual effects yet.

Every weather type and its planned effects are listed in [docs/WEATHER_EFFECTS.md](docs/WEATHER_EFFECTS.md) (regenerate with `python tools/gen_effects_table.py` after editing `weather_defs.lua`).

## Layout

```
mod/BAR-Weather.sdd/          the game archive (depends on BAR)
  modinfo.lua
  luarules/configs/weather_defs.lua   all weather data and tuning, incl. the modifier table
  luarules/gadgets/weather_core.lua   synced simulation + /luarules weather commands
  luaui/configs/weather_hud_logic.lua HUD text and announcement rules (no drawing)
  luaui/Widgets/gui_weather_hud.lua   top-bar weather panel, tooltip, warning banners
  luaui/Widgets/gui_weather_debug.lua raw-state overlay (off by default; enable with F11)
tests/                        offline tests (stubbed engine API, Lua 5.1)
tools/                        lobby-free skirmish launcher
reference/                    the original C++/Unreal drafts (design notes only)
```

## Trying it in game

Targets Recoil engine **2026.07.04**.

1. Set `depend` in `mod/BAR-Weather.sdd/modinfo.lua` to the exact name of your installed BAR version.
2. Copy or symlink `mod/BAR-Weather.sdd` into the `games/` folder of BAR's data directory.
3. Start a skirmish with "BAR Weather" as the game. The lobby may not list it, so the easiest way is to skip the lobby: `powershell -ExecutionPolicy Bypass -File tools\run_skirmish.ps1` starts the engine directly with `tools/skirmish.txt` (you vs SimpleAI on Theta Crystals). Pass `-DataDir` if BAR isn't installed at `M:\BAR\Beyond-All-Reason`.
4. In game:
   - `/luarules weather status` shows the current state and forecast.
   - `/cheat` then `/luarules weather set storm` or `/luarules weather next` to force changes.

## Settings (modoptions)

Until lobby options are wired up (see PLAN.md §2), these are read from the start script with the defaults below:

| Key | Values | Default |
|---|---|---|
| `weather_mode` | off / cosmetic / light / full | full |
| `weather_climate` | auto / temperate / arid / arctic / marsh | auto |
| `weather_first_change` | minutes | 6 |
| `weather_volatility` | low / normal / high | normal |
| `weather_daynight` | 0 / 1 | 1 |
| `weather_daylength` | minutes | 20 |
| `weather_effect_scale` | 0.25–1.5 | 1.0 |

## Map makers

Add `mapconfig/weather.lua` to your map:

```lua
return {
	climate = "arctic", -- temperate | arid | arctic | marsh
	start = "snow",     -- starting weather (must be allowed by the climate)
}
```

## Running the tests

```
pip install lupa
python tests/run_tests.py
```

Or with a standalone Lua 5.1 from the repo root: `lua tests/weather_core_test.lua`.
