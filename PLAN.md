# BAR Weather Mod — Project Plan

A community mod for **Beyond All Reason** (BAR) that adds dynamic weather and a day/night cycle. Weather is **visible** (rain, snow, fog, storms, lighting, audio) and **creates opportunities**: it rewards players who read the forecast, use the terrain and adapt their army and economy.

---

## 1. Vision

- Weather changes during a match, and the map changes with it: fog pools in valleys, low ground turns to mud, a storm front rolls across the map.
- **Every weather type has winners, not just losers.** The forecast is a call to action ("storm in 60 s, push with ground now"), not a warning to brace.
- **Terrain matters.** Where you are matters as much as what the weather is. High ground, valleys, slopes and water all interact with weather.
- **Memorable moments.** Rare events like a blizzard or a sandstorm make games worth retelling.
- Plays to BAR's existing economy (wind, solar, tidal, geothermal, fusion), so energy choices become live decisions.

### Design pillars
1. **Opportunity over penalty:** each weather type rewards some play style. If a change only makes everything worse, redesign it.
2. **Visible over hidden:** effects show up in the world and UI (shrinking line-of-sight circles, updated range rings, mud trails). No invisible accuracy nerfs.
3. **Telegraphed:** a forecast, warnings before changes and before lightning strikes. Players can always plan around weather.
4. **Fair:** a deterministic synced simulation where the same rules apply to everyone. Terrain and positioning decide who benefits.
5. **Cheap:** negligible impact on simulation speed in 8v8 games with thousands of units.

---

## 2. Platform & distribution

BAR runs on the **Recoil engine** (a fork of Spring). Target engine version: **2026.07.04**. Mods are **Lua**:

| Layer | What it's for | Runs |
|---|---|---|
| **Gadget**, synced (`luarules/gadgets/`) | Game state and anything that affects gameplay | Identically on every client, so it must be deterministic |
| **Gadget**, unsynced half | Sending synced state to the renderer | Locally |
| **Widget** (`luaui/Widgets/`) | Visuals, audio, HUD, forecast, spectator tools | Locally per player |

**Distribution:** a community mod, packaged as a **dependent game archive** (`.sdd`/`.sdz` with `modinfo.lua` that `depend`s on BAR). It's hosted in custom lobbies and doesn't touch the core game. Each lobby turns it on and configures it through modoptions (§13).

The C++ and Unreal files in this repo are the **design reference only** (see §17). Everything gets ported to Lua.

### Findings from BAR's source (checked against `beyond-all-reason/Beyond-All-Reason` master)
- **Gadgets** load from `LuaRules/Gadgets/*.lua` in any archive (`VFS.ZIP_ONLY`), so a dependent archive can add new gadgets without overriding BAR files. **Widgets** load the same way from `LuaUI/Widgets/`.
- **Modoptions:** BAR's lobby options come from the game's root `modoptions.lua`. A dependent archive shipping its own `modoptions.lua` would *replace* BAR's whole list, so we don't. Settings are read with `Spring.GetModOptions()` and fall back to sensible defaults; the mod works without any lobby setup. BAR master has a new **module system** (`modules/<name>/` with `manifest.lua`, `gadgets/`, `widgets/`, `modoptions.lua`) whose `ModOptions()` merges module options. Once that's in a release and wired into the lobby, switching to `modules/weather/` gives us proper lobby options. ⚠️ Open item.
- **Debug commands** follow BAR's pattern: an unsynced chat action sends `Spring.SendLuaRulesMsg`, and synced `RecvLuaMsg` checks `Spring.IsCheatingEnabled()`.
- **Systems we can reuse instead of rebuilding:**
  - `luaui/Widgets/gfx_snow.lua` exposes `WG.snow` (`setSnowMap`, `setMultiplier`, `setColor`, `setOpacity`, `setSpeedMultiplier`, `setWindMultiplier`, ...). It can drive snow, and possibly rain (blue-grey, fast), in Phase 3.
  - `luarules/gadgets/map_nightmode.lua` already does night lighting (sun, grass, features, map edge) with a `NightMode` chat action. It's the starting point for Phase 6.
  - `luarules/gadgets/map_atmosphere_cegs.lua` and the Weather Brush (`cmd_weather_brush.lua`, `effects/terraform_weather_conditions.lua`) have weather CEGs we may reuse for lightning and storm effects.
- **AI policy:** BAR requires disclosure of AI-written code in PRs and bans AI-generated media (art, audio). That only matters if code is ever upstreamed, but keep it in mind for the optional weather units' art.

### Hard rules for synced code
- No `os.time`, `os.clock` or local randomness. Use the synced `math.random`.
- Gameplay never depends on unsynced or widget state.
- Share state with widgets through `Spring.SetGameRulesParam` / `Spring.GetGameRulesParam`.
- Spread per-unit work across frames. Never touch every unit in a single frame.

---

## 3. Architecture

```
┌──────────────────────────── SYNCED (gadgets) ───────────────────────────┐
│ weather_core.lua      state machine, pacing, intensity, forecast queue, │
│                       day/night clock, rare events                      │
│ weather_stormcell.lua moving storm cell (position, radius, velocity)    │
│ weather_terrain.lua   per-unit terrain context: fog line, mud, slope    │
│ weather_effects_vision.lua    LOS/airLOS per unit (weather+terrain)     │
│ weather_effects_movement.lua  max speed per movetype (weather+terrain)  │
│ weather_effects_economy.lua   wind, solar, tidal                        │
│ weather_effects_combat.lua    fog range penalty, night fire-reveal      │
│ weather_lightning.lua         telegraphed, targeted strikes             │
│ weather_control.lua           optional weather station / control units  │
│                                                                         │
│ publishes GameRulesParams: weather_type, intensity, precip, cloud, fog, │
│ fog_height, time_of_day, next_type, next_eta, cell_x/z/r, event, ...    │
└─────────────────────────────────────────────────────────────────────────┘
                          │ GameRulesParams (read-only)
┌─────────────────────────── UNSYNCED (widgets) ──────────────────────────┐
│ gui_weather_hud.lua         current weather, forecast, modifier tooltip │
│ gui_weather_feedback.lua    live LOS/range rings, mud & storm overlays  │
│ gfx_weather_atmosphere.lua  sky, sun, height fog layer, day/night       │
│ gfx_weather_precip.lua      GPU rain/snow/sand particles, storm cell    │
│ gfx_weather_lightning.lua   pre-strike glow, flash, bolt, thunder delay │
│ snd_weather_ambience.lua    crossfaded loops, warning stingers          │
│ gui_weather_spectator.lua   weather timeline, replay event markers      │
└─────────────────────────────────────────────────────────────────────────┘
```

### Weather data model

One shared definition replaces the five conflicting `WeatherData` structs in the old code.

```lua
-- weather_defs.lua (shared config; map configs can override, see §12)
WeatherTypes = {
  clear    = { precip = 0.0, cloud = 0.1, fog = 0.0, windMin = 0,  windMax = 10 },
  overcast = { precip = 0.0, cloud = 0.7, fog = 0.1, windMin = 3,  windMax = 15 },
  rain     = { precip = 0.6, cloud = 0.8, fog = 0.2, windMin = 5,  windMax = 18, mud = true },
  storm    = { precip = 1.0, cloud = 1.0, fog = 0.3, windMin = 15, windMax = 30, lightning = true },
  fog      = { precip = 0.0, cloud = 0.5, fog = 0.9, windMin = 0,  windMax = 4,  valleyFog = true },
  snow     = { precip = 0.5, cloud = 0.8, fog = 0.3, windMin = 2,  windMax = 12, slopePenalty = true },
}
```

- **Intensity (0–1)** ramps over a transition period (default ~45 s), so effects and visuals blend instead of snapping.
- **Transitions:** a Markov table (ported from `WeatherStateMachine.cpp`), filtered by the map's climate profile.

---

## 4. Pacing

- **Calm opening:** the game starts clear (or the map's default), and the **first change can happen at 6:00 at the earliest**. Players can still run their rehearsed openings.
- **Rising volatility:** weather states get shorter as the game goes on.

  | Game time | State duration |
  |---|---|
  | 6–15 min | 4–7 min |
  | 15–30 min | 3–5 min |
  | 30+ min | 2–4 min |

- **Rare events** (§9) become possible after 12:00, with at most one every ~15 min.
- Every change is announced in the forecast at least **90 s** ahead, with a warning **30 s** before.
- All timings are modoptions (§13).

---

## 5. Who wins in each weather

This is the design core. Every row needs a real "rewards" column.

| Weather | Who suffers | Who it rewards | Key mechanics |
|---|---|---|---|
| **Clear** | n/a | Air and artillery get a "golden window"; solar | Air LOS 1.1×, solar 1.1× |
| **Overcast** | Solar (slightly) | Wind | Solar 0.8×, wind range up |
| **Rain** | Vehicles/tanks in low ground (mud), solar | Bots, hover, amphibious; tidal | Mud (§6), solar 0.7×, tidal +15% |
| **Storm** | Air, solar, tall structures (lightning) | Wind economy (big boost), ground pushes while enemy air is weak | Air speed 0.8×, air LOS 0.7×, wind 15–30, solar 0.4×, lightning (§5.4) |
| **Fog** | Static defenses, long-range direct fire | Raiders, flankers, radar investment, whoever holds high ground | Valley fog (§6), long-range direct-fire range −15% |
| **Snow** | Fast raiders, attackers on slopes | Defenders, turtles, builders who planned ahead | Ground speed scales with base speed (fast units lose more), slope penalty (§6), solar 0.8× |
| **Night** (day/night) | Solar, unscouted armies | Stealthy raids, scouts, players who hold fire | LOS 0.75×, solar 0, firing reveals the shooter (§5.5) |

All modifiers scale with intensity: `effective = 1 + (mod - 1) * intensity`. Starting values are conservative and get tuned in playtests (§16).

### 5.1 Vision (`Spring.SetUnitSensorRadius`)
- Weather and night set the base multiplier. Terrain then adjusts it per unit (valley fog, §6).
- Radar and sonar are **unaffected**, which makes radar investment the counter to fog and night.
- Scout-role units (high base LOS) lose less: they keep at least 0.85×.
- Re-apply on unit creation, weather change, terrain-context change, transport load/unload and upgrades.

### 5.2 Movement (`Spring.MoveCtrl.Set*MoveTypeData` → `maxSpeed`)
| Weather | Bots | Vehicles/tanks | Hover | Aircraft | Ships |
|---|---|---|---|---|---|
| Rain | 1.0× | 1.0× (0.8× in mud) | 1.0× | 0.95× | 1.0× |
| Storm | 0.95× | 0.95× (0.8× in mud) | 0.9× | 0.8× | 0.9× |
| Snow | 0.9×, scaled by base speed | 0.85×, scaled by base speed | 0.95× | 1.0× | 1.0× |

- Snow speed scaling: units faster than the median lose up to an extra 10%, so raiders suffer most.
- ⚠️ Must compose with BAR's existing speed modifiers. Cache each unit's base speed and apply one combined multiplier, never stacking repeatedly.

### 5.3 Economy
| Source | Rule | How |
|---|---|---|
| Wind generators | Weather sets the global wind range; inside the storm cell they get an extra bonus | `Spring.SetWind(min, max)`; bonus via `Spring.SetUnitResourcing` |
| Solar collectors | Output × per-weather multiplier; 0 at night | `Spring.SetUnitResourcing(unitID, "ume", value)` |
| Tidal | +15% in rain and storms | `Spring.SetTidal` (⚠️ verify it exists), or a per-unit resourcing bonus |
| Geothermal / fusion | Unaffected (the stable choice) | none |
| Metal extractors | Unaffected (keep metal stable) | none |

Changes to wind are capped relative to the map's own wind settings, so wind-heavy maps don't break.

### 5.4 Lightning (storms)
- **Targeted, not random:** strike chance is weighted by structure height and metal cost, within the storm area.
- **Telegraphed:** a visible charge glow on the target ~1.5 s before the strike, plus a sound cue.
- **Moderate damage:** it never one-shots anything above light structures.
- Separate on/off modoption.

### 5.5 Night stealth: firing reveals the shooter
- At night, a unit that fires is revealed to the enemy ally-teams for ~2 s.
- This makes holding fire, ambushes and night raids real choices.
- Implementation: detect fire through a weapon or projectile call-in and grant temporary LOS on the shooter (⚠️ verify the best approach: `SetUnitLosState`/`SetUnitLosMask` or a temporary revealer).

### 5.6 Combat
- Kept deliberately small. The only stat change is **fog: long-range direct-fire weapons lose 15% range**, shown on updated range rings. Artillery is excluded.
- No hidden accuracy or damage nerfs.

---

## 6. Terrain-aware weather

Cheap per-unit checks: compare unit height with ground and map heights, staggered so each unit is checked about once per second.

| Effect | Rule | Gameplay result |
|---|---|---|
| **Valley fog** | A fog line at `mapMinHeight + fogDepth × intensity`. Units **below** it get heavy LOS reduction (0.5×); units **above** keep near-full LOS | High ground is a fog-time objective; valleys become ambush zones |
| **Mud** | When it rains or storms, ground vehicles on low, flat terrain (below a height percentile, low slope) get the mud slow | Rain changes which routes are fast; bots and hover gain value |
| **Snow slopes** | In snow, an extra 0.85× speed on steep slopes (from the ground normal) | Attacking uphill in snow is costly, so defenders benefit |

**Limitation:** engine LOS is observer-based. Valley fog shrinks the vision of units *inside* the fog, but can't hide a unit from an observer on a hilltop. That matches real fog fairly well (hilltops see the tops of things), but it should be documented for players.

Visuals: a height-fog layer in the atmosphere widget matches the gameplay fog line exactly. A mud tint and darkened ground show in rain on low terrain.

---

## 7. Moving storm cell

Simple regional weather, replacing a full regional-weather system.

- When a storm starts, a single storm cell forms at a map edge and **drifts across the map with the wind direction**.
- Inside the cell: full storm effects (lightning, air penalties, wind bonus, heavy precipitation visuals).
- Outside the cell: rain or overcast at reduced intensity.
- The cell's position, radius and path are shown on the minimap and in the forecast, so players can see it heading for their base.
- Synced state is just center, radius and velocity, so it's cheap. Units sample "inside the cell or not" as part of the terrain checks.

---

## 8. Day/night cycle

- Configurable day length (default 20 min; ported from `TimeSystem.cpp`). The match starts in the morning.
- Night: LOS 0.75×, solar 0, fire-reveal (§5.5). Lighting shifts to a dim blue, and unit lights and muzzle flashes become more visible.
- Dawn and dusk are transitions, announced like weather changes.
- Runs alongside weather: a foggy night is the most dangerous time to be in a valley.

---

## 9. Rare events

Low frequency (§4) and announced dramatically. Each is filtered by climate.

| Event | Climate | Effect (short, ~2–3 min) |
|---|---|---|
| **Blizzard** | Arctic, temperate winter | Heavy snow effects, LOS 0.5×, air grounded or heavily slowed |
| **Sandstorm** | Arid | LOS 0.5× outside of radar coverage, solar 0.3×, wind high |
| **Aurora** | Arctic / night | Radar range +25% *or* radar jammed (alternates per event; announced) |
| **Calm before the storm** | Any | Wind drops to 0 for ~60 s, then a storm cell forms with extra-high winds |
| **Heatwave** | Arid, temperate | Solar 1.3×, but fusion and coal output −10% |

---

## 10. Optional weather units

Behind their own modoption, off by default.

| Unit | Tier | Effect |
|---|---|---|
| **Weather Station** | T1/T2 structure | Extends the forecast from 1–2 states to 3–4 for your ally-team, and shows the storm cell's path earlier |
| **Atmospheric Controller** | T3 structure | On a long cooldown, nudges the next weather state (e.g. pick from two options). The result is announced to everyone ~90 s ahead, so the opponent can react |

These are new units, so they need models and icons. Reusing existing BAR models with new textures is acceptable at first.

---

## 11. Visuals, audio & feedback

| Feature | Approach |
|---|---|
| Sky & sunlight | `Spring.SetSunLighting`, `Spring.SetAtmosphere`, lerped by intensity and time of day |
| Height fog | A fog layer in a shader, matching the gameplay fog line |
| Rain / snow / sand | GPU particles in a camera-attached volume; denser inside the storm cell |
| Storm cell | Dark cloud mass and rain curtain on the map and minimap |
| Lightning | Charge glow on the target → bolt + flash → thunder delayed by distance |
| Mud | Darkened ground tint on low terrain; slowed vehicles leave trails |
| Audio | Crossfaded ambience loops per weather; warning stingers for changes, events and lightning |
| Performance | Graphics presets (Off / Low / High); automatic reduction when FPS drops |

### Gameplay feedback (from the "visible over hidden" pillar)
- LOS circles and range rings shrink and grow live with the weather.
- Units affected by mud, snow, fog or night get a small status icon.
- Hovering a unit shows its weather-adjusted stats.

Players can turn visuals down, but **gameplay effects stay on** (they're synced), and the HUD always shows the real state.

---

## 12. Map-maker hooks

- An optional `mapconfig/weather.lua` in a map archive can override:
  - the climate profile and allowed weather types
  - the transition table
  - the starting weather
  - fog depth and the mud height percentile
  - storm cell spawn edges
  - allowed rare events
- The mod ships fallback profiles for popular maps, and an automatic profile for maps without one.
- A short doc and template help map authors opt in.

---

## 13. Configuration (modoptions)

| Option | Values | Default |
|---|---|---|
| `weather_mode` | cosmetic / light / full | full |
| `weather_climate` | auto / temperate / arid / arctic / marsh | auto |
| `weather_first_change` | minutes | 6 |
| `weather_volatility` | low / normal / high | normal |
| `weather_daynight` | on / off | on |
| `weather_daylength` | minutes | 20 |
| `weather_terrain` (valley fog, mud, slopes) | on/off | on |
| `weather_stormcell` | on/off | on |
| `weather_events` | off / rare / frequent | rare |
| `weather_lightning` | on/off | on |
| `weather_night_reveal` | on/off | on |
| `weather_units` (station/controller) | on/off | off |
| `weather_vision` / `_movement` / `_economy` / `_combat` | on/off | on |
| `weather_effect_scale` | 0.25–1.5 | 1.0 |

---

## 14. UI & spectators

- **Weather panel** (near the resource bar): icon, name, intensity, countdown, and the time-of-day indicator.
- **Forecast:** the next 1–2 states with ETAs (3–4 with a Weather Station), plus the storm cell path.
- **Tooltip:** the active modifiers and **who is favored right now** ("Fog: valleys −50% LOS · radar unaffected · good for raids").
- **Announcements:** a 30 s warning with a sound, and a big banner for rare events.
- **Spectator / caster widget:** a weather timeline across the match and markers on replays for weather changes, events and lightning strikes. This makes weather moments easy to show in casts.

---

## 15. Roadmap

### Phase 0: Setup & research
- [x] Set up a local BAR dev environment and run a game with the dependent `.sdd` archive (`mod/BAR-Weather.sdd`). BAR is installed at `M:\BAR\Beyond-All-Reason` (data in `data\`). `tools/run_skirmish.ps1` starts a skirmish without the lobby.
- [x] Pin the engine version: Recoil **2026.07.04**.
- [x] Set the real BAR archive name in `modinfo.lua` → `depend`: `Beyond All Reason test-31536-188afa8`. This is the *game* version, which is separate from the engine version.
- [x] Link the mod into BAR: junction `M:\BAR\Beyond-All-Reason\data\games\BAR-Weather.sdd` → `mod/BAR-Weather.sdd`.
- [x] Learn how BAR loads gadgets, widgets, modoptions and debug commands (see §2 findings).
- [ ] Read existing BAR gadgets that change speed, LOS and resourcing.
- [ ] Verify APIs: `SetWind`, `SetTidal`, `SetAtmosphere`, `SetSunLighting`, `MoveCtrl` speed setters, `SetUnitSensorRadius`, `SetUnitWeaponState` range, LOS-reveal options, and weapon-fire call-ins.
- [x] Move the old C++/Unreal files into `reference/`.

### Phase 1: Weather core
- [x] `weather_defs.lua` + `weather_core.lua`: state machine, climates, pacing (§4), intensity blend, forecast queue, day/night clock, GameRulesParams, `GG.Weather` API for effect gadgets.
- [x] Settings via `Spring.GetModOptions()` with defaults (lobby UI pending, see §2).
- [x] Map-maker hook: `mapconfig/weather.lua` (climate + start for now).
- [x] Debug commands: `/luarules weather status`, `/luarules weather set <type>`, `/luarules weather next` (set/next need `/cheat`).
- [x] Debug widget (`gui_weather_debug.lua`): on-screen state, forecast, console warnings.
- [x] Offline test suite (`tests/`): pacing, forecast notice, climates, determinism, blending, commands. 21 core tests passing (36 including the Phase 2 HUD tests).
- [ ] `/luarules weather event <name>` (comes with Phase 7 events).
- [ ] Climate tuning: arid is mostly clear ↔ overcast until sandstorms exist (Phase 7).
- **Done when:** weather cycles deterministically in a real multiplayer game with no desyncs, and the first change respects the 6-minute minimum. ✅ Verified in a local skirmish (engine 2026.07.04, BAR test-31536): the gadget loads, and the `status`/`set`/`next` commands and the debug overlay work. ⚠️ Still to check: the first natural change at ≥ 6:00, and no desyncs in a multiplayer game.

### Phase 2: HUD, forecast & feedback
- [x] Weather panel (`gui_weather_hud.lua`) at the right end of the top bar's free area: procedural icon, type, blend bar, clock, next change with its icon and countdown. Stops at the button strip's real left edge, since the strip can outgrow the share the top bar reserves for it. Checked in game: readable at 4K, tooltip good.
- [x] "Who is favored" tooltip: favors/hurts lines for the weather and night, forecast with ETAs, climate and clock. It lists modifiers only for effect systems that are running (each effect gadget sets `weather_fx_<system> = 1`), so it never advertises stats that aren't applied.
- [x] Announcements: forecast line in the console when a change enters the forecast, a banner + sound 30 s before, and a banner + sound on the change.
- [x] Modifier table moved into `weather_defs.lua` (`Defs.Modifiers`, `Defs.ModifierInfo`), the single source of truth for the Phase 4 gadgets and the tooltip.
- [x] HUD logic in `luaui/configs/weather_hud_logic.lua` with offline tests (`tests/weather_hud_test.lua`), including announcements driven by full simulated matches.
- Moved to Phase 4: live LOS/range rings and unit status icons. They show stat changes, so each one is built with the effect it shows.

### Phase 3: Visuals & audio
- [ ] Atmosphere and sun lerping, height fog layer, rain/snow particles, lightning visuals, ambience.
- [ ] Graphics presets and the FPS safeguard.
- **Done when:** it looks good with < 1 ms frame cost on mid-range hardware.

### Phase 4: Core gameplay effects
Each effect gadget reads `Defs.Modifiers` and sets `weather_fx_<system> = 1` while active, which makes its modifiers appear in the HUD tooltip.
- [ ] Vision, with live LOS circle feedback.
- [ ] Economy (wind, solar, tidal).
- [ ] Movement.
- [ ] Fog range penalty, with updated range rings.
- [ ] Unit status icons for units affected by mud, snow, fog or night (§11).
- **Done when:** the "who wins" table (§5) holds in practice, and tooltips match the actual stats.

### Phase 5: Terrain & storm cell
- [ ] `weather_terrain.lua`: valley fog, mud, snow slopes, with staggered per-unit checks.
- [ ] `weather_stormcell.lua` + minimap and forecast display.
- [ ] Targeted, telegraphed lightning.

### Phase 6: Day/night & night stealth
- [ ] Time-of-day clock, lighting, night modifiers, fire-reveal.

### Phase 7: Rare events & map-maker hooks
- [ ] Blizzard, sandstorm, aurora, calm before the storm, heatwave.
- [ ] `mapconfig/weather.lua` support, fallback profiles, author docs.

### Phase 8: Optional weather units
- [ ] Weather Station and Atmospheric Controller (models/icons, balance).

### Phase 9: Spectator tools, balance & release
- [ ] Spectator timeline and replay markers.
- [ ] Profile 8v8 large games and playtest against the metrics in §16.
- [ ] Player-facing guide ("what each weather does and who it favors"), then release and gather feedback.

---

## 16. Measuring fun & balance

Weather is working if it **changes decisions** without **deciding games**. Track these in playtests (from replays or a logging gadget):

- **Economy shift:** do wind/solar/tidal build ratios differ by weather and climate? If not, the economy effects are too weak.
- **Fight locations:** what share of fights happen in valleys vs on high ground during fog, and in mud vs off-road during rain? If it doesn't change, the terrain effects are too weak.
- **Timing:** do pushes cluster around forecast changes (e.g. ground pushes before storms)? That's the sign the forecast is used.
- **Win correlation:** does the player favored by the starting weather, or by any single event, win far more often than 50%? If so, it's too strong.
- **Player feedback:** after each test, ask "name a moment the weather mattered", and "was there a moment it felt unfair?"

---

## 17. What carries over from the existing code

| Existing file | What to keep |
|---|---|
| `WeatherStateMachine.cpp` | Markov transition table and minimum state duration → `weather_core.lua` |
| `WeatherSensitive.cpp`, `UnitsWeatherImpact.cpp`, `WeatherUpdateSystem.cpp` | Per-weather and per-unit-class modifier tables; lightning-vulnerability idea → targeted lightning; area-based updates idea → storm cell |
| `UnitVisionSystem.*`, `UnitVisionFogOfWarSystem.cpp`, `VisionTypes.h` | Vision formulas; elevation bonus → valley fog; night vision / fog lights → scout-role LOS floor and radar as the counter |
| `ResourceModule.*`, `PowerSystemsWeatherImpact.cpp` | Wind cut-in/out curve, solar cloud/heat/night formula, hydro rain bonus → tidal bonus |
| `TimeSystem.cpp` | Day length, sunrise/sunset, light curve |
| `UDataAssetWeather.cpp` | Per-weather config (VFX, audio, transition duration) → `weather_defs.lua` |
| `ObjectPooling.cpp` | Not needed: particles go on the GPU instead |
| `GameStateModule.cpp`, `ClassHierarchy.cpp`, `HealthComponents.cpp`, `BaseUnitArchitecture.cpp`, `ModuleDependencies.cpp`, `RTSCore.*`, `EventDrivenCommunication.cpp`, `WeatherSingleton.cpp`, `WeatherBroadcastSystem.*`, `WeatherEnums.cpp` | Unreal/generic RTS scaffolding with no direct use. Broadcasting is replaced by GameRulesParams |

---

## 18. Risks & open questions

- **Stacking with BAR's own modifiers:** speed and LOS changes from other gadgets could conflict. Mitigation: cache base values and apply one combined multiplier.
- **Keeping up with BAR updates:** BAR changes often. Keep hooks minimal, avoid overriding BAR files, and pin to tested BAR versions in `modinfo.lua`.
- **Wind economy swings:** cap wind changes relative to the map's settings.
- **Visual clarity:** fog, rain and night must never hide UI or make units unreadable. Cap visual density separately from gameplay values.
- **Night fire-reveal:** depends on what the engine allows for temporary LOS grants. There's a fallback if it's impractical (e.g. briefly reveal shooters on radar only).
- **Performance:** staggered terrain checks and batched re-application in 2000+ unit games.
- **New-unit art:** the optional weather units need models and icons. Reuse existing BAR assets at first.
- **AI:** BAR's AIs won't understand weather. Acceptable at first. Expose GameRulesParams so AI authors can use them later.

---

## 19. Next concrete step

Phase 0: set up the local BAR dev environment and a dependent `.sdd` archive containing a ~50-line `weather_core.lua`. It should hold clear until 6:00, then cycle weather types on a timer and print them. That proves the toolchain end to end.
