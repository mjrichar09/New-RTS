-- Shared weather configuration. Included by synced gadgets and unsynced widgets alike,
-- so it must stay pure data (no Spring calls).
--
-- Synced code must never iterate these tables with pairs(): use the ordered arrays
-- (Defs.TypeOrder) so every client walks them in the same order.

local Defs = {}

-- Ordered list of weather types; also the iteration order for any synced logic.
Defs.TypeOrder = { "clear", "overcast", "rain", "storm", "fog", "snow" }

-- Continuous atmosphere values per type. Effects and visuals blend between these
-- during a transition. Wind values are in the engine's wind units (same as map windMin/windMax).
-- favors / hurts are the player-facing "who wins" lines (PLAN.md section 5).
Defs.Types = {
	clear = {
		label = "Clear", precip = 0.0, cloud = 0.1, fog = 0.0, windMin = 0, windMax = 10,
		favors = "Air and artillery (golden window), solar",
		hurts = "Nobody",
	},
	overcast = {
		label = "Overcast", precip = 0.0, cloud = 0.7, fog = 0.1, windMin = 3, windMax = 15,
		favors = "Wind",
		hurts = "Solar (slightly)",
	},
	rain = {
		label = "Rain", precip = 0.6, cloud = 0.8, fog = 0.2, windMin = 5, windMax = 18,
		favors = "Bots, hover and amphibious units, tidal",
		hurts = "Vehicles on low ground (mud), solar",
	},
	storm = {
		label = "Storm", precip = 1.0, cloud = 1.0, fog = 0.3, windMin = 15, windMax = 30,
		favors = "Wind economy, ground pushes while enemy air is weak",
		hurts = "Air, solar, tall structures (lightning)",
	},
	fog = {
		label = "Fog", precip = 0.0, cloud = 0.5, fog = 0.9, windMin = 0, windMax = 4,
		favors = "Raiders, flankers, radar, whoever holds high ground",
		hurts = "Static defenses, long-range direct fire",
	},
	snow = {
		label = "Snow", precip = 0.5, cloud = 0.8, fog = 0.3, windMin = 2, windMax = 12,
		favors = "Defenders, turtles, builders who planned ahead",
		hurts = "Fast raiders, attacking up slopes",
	},
}

-- Night is a condition on top of the weather type (PLAN.md section 8).
Defs.Night = {
	label = "Night",
	favors = "Stealthy raids, scouts, holding fire",
	hurts = "Solar, unscouted armies",
}

-- Gameplay modifiers per condition (weather type or "night"), at full intensity. This is the
-- single source of truth: the effect gadgets (Phase 4+) apply these values and the HUD
-- describes them, so tooltips always match the real stats. Numbers are multipliers;
-- `true` marks an on/off mechanic.
Defs.Modifiers = {
	clear = { airLos = 1.1, solar = 1.1 },
	overcast = { solar = 0.8 },
	rain = { solar = 0.7, tidal = 1.15, airSpeed = 0.95, mud = true },
	storm = {
		solar = 0.4, airLos = 0.7, airSpeed = 0.8, botSpeed = 0.95, vehicleSpeed = 0.95,
		hoverSpeed = 0.9, shipSpeed = 0.9, lightning = true,
	},
	fog = { directRange = 0.85, valleyFog = true },
	snow = { solar = 0.8, botSpeed = 0.9, vehicleSpeed = 0.85, hoverSpeed = 0.95, slopePenalty = true },
	night = { los = 0.75, solar = 0, fireReveal = true },
}

-- Display order and owning system for each modifier. A modifier only counts as live when its
-- system's gadget is running and has set Defs.SystemParam(system) to 1.
Defs.ModifierOrder = {
	"los", "airLos", "directRange", "airSpeed", "botSpeed", "vehicleSpeed", "hoverSpeed", "shipSpeed",
	"solar", "tidal", "mud", "valleyFog", "slopePenalty", "lightning", "fireReveal",
}
Defs.ModifierInfo = {
	los = { system = "vision", label = "Line of sight" },
	airLos = { system = "vision", label = "Air line of sight" },
	directRange = { system = "combat", label = "Long-range direct-fire range" },
	airSpeed = { system = "movement", label = "Aircraft speed" },
	botSpeed = { system = "movement", label = "Bot speed" },
	vehicleSpeed = { system = "movement", label = "Vehicle speed" },
	hoverSpeed = { system = "movement", label = "Hover speed" },
	shipSpeed = { system = "movement", label = "Ship speed" },
	solar = { system = "economy", label = "Solar output" },
	tidal = { system = "economy", label = "Tidal output" },
	mud = { system = "terrain", label = "Mud slows vehicles on low, flat ground" },
	valleyFog = { system = "terrain", label = "Valley fog: units below the fog line see half as far" },
	slopePenalty = { system = "terrain", label = "Steep slopes slow ground units" },
	lightning = { system = "lightning", label = "Lightning strikes tall, valuable structures" },
	fireReveal = { system = "nightReveal", label = "Firing reveals the shooter" },
}

-- Hours are night when outside [sunriseHour, sunsetHour).
function Defs.IsNight(hours)
	return hours < Defs.DayNight.sunriseHour or hours >= Defs.DayNight.sunsetHour
end

-- Relative transition weights: from -> { to = weight }. Filtered by climate at runtime,
-- then renormalised, so weights only need to make sense relative to each other.
Defs.Transitions = {
	clear = { overcast = 50, fog = 20, rain = 15, snow = 15 },
	overcast = { clear = 35, rain = 30, snow = 20, storm = 10, fog = 5 },
	rain = { overcast = 40, storm = 25, fog = 20, clear = 15 },
	storm = { rain = 50, overcast = 35, snow = 15 },
	fog = { clear = 50, overcast = 30, rain = 20 },
	snow = { overcast = 45, clear = 25, fog = 15, storm = 15 },
}

-- Which weather types each climate allows, and what a match starts with.
Defs.Climates = {
	temperate = { start = "clear", allowed = { clear = true, overcast = true, rain = true, storm = true, fog = true } },
	arid = { start = "clear", allowed = { clear = true, overcast = true, storm = true } },
	arctic = { start = "clear", allowed = { clear = true, overcast = true, fog = true, snow = true, storm = true } },
	marsh = { start = "clear", allowed = { clear = true, overcast = true, rain = true, fog = true, storm = true } },
}

-- "auto" climate: first matching substring of the lowercased map name wins.
-- A map's own mapconfig/weather.lua takes precedence over this.
Defs.MapClimatePatterns = {
	{ pattern = "snow", climate = "arctic" },
	{ pattern = "ice", climate = "arctic" },
	{ pattern = "frost", climate = "arctic" },
	{ pattern = "glacier", climate = "arctic" },
	{ pattern = "tundra", climate = "arctic" },
	{ pattern = "cold", climate = "arctic" },
	{ pattern = "desert", climate = "arid" },
	{ pattern = "dune", climate = "arid" },
	{ pattern = "sand", climate = "arid" },
	{ pattern = "mesa", climate = "arid" },
	{ pattern = "canyon", climate = "arid" },
	{ pattern = "swamp", climate = "marsh" },
	{ pattern = "marsh", climate = "marsh" },
	{ pattern = "bog", climate = "marsh" },
	{ pattern = "delta", climate = "marsh" },
}

-- Pacing (PLAN.md section 4).
Defs.Pacing = {
	-- First change happens somewhere in [firstChangeMinutes, firstChangeMinutes + firstChangeWindowSeconds].
	firstChangeMinutes = 6,
	firstChangeWindowSeconds = 120,
	-- No change may happen with less notice than this (also applied to the first change).
	minNoticeSeconds = 90,
	-- The HUD warns (banner + sound) this long before each change.
	warningSeconds = 30,
	-- Time for effects and visuals to blend from the previous state to the new one.
	transitionSeconds = 45,
	-- State durations (minutes) by game time; the first phase whose untilMinute is above
	-- the state's start time applies.
	phases = {
		{ untilMinute = 15, minMinutes = 4, maxMinutes = 7 },
		{ untilMinute = 30, minMinutes = 3, maxMinutes = 5 },
		{ untilMinute = math.huge, minMinutes = 2, maxMinutes = 4 },
	},
	-- Duration multiplier per volatility setting.
	volatility = { low = 1.3, normal = 1.0, high = 0.75 },
	-- How many upcoming states the forecast always knows about.
	forecastLength = 2,
}

Defs.DayNight = {
	startHour = 8, -- matches start in the morning
	sunriseHour = 6,
	sunsetHour = 18,
}

-- Modoption keys, accepted values and defaults (PLAN.md section 13).
Defs.Options = {
	mode = { key = "weather_mode", def = "full", values = { off = true, cosmetic = true, light = true, full = true } },
	climate = { key = "weather_climate", def = "auto", values = { auto = true, temperate = true, arid = true, arctic = true, marsh = true } },
	firstChange = { key = "weather_first_change", def = 6, min = 0, max = 60 },
	volatility = { key = "weather_volatility", def = "normal", values = { low = true, normal = true, high = true } },
	dayNight = { key = "weather_daynight", def = true },
	dayLength = { key = "weather_daylength", def = 20, min = 2, max = 120 },
	effectScale = { key = "weather_effect_scale", def = 1.0, min = 0.25, max = 1.5 },
}

-- Parses Spring.GetModOptions() output (all values arrive as strings) into typed settings.
function Defs.ReadOptions(modOptions)
	modOptions = modOptions or {}
	local settings = {}

	for name, opt in pairs(Defs.Options) do
		local raw = modOptions[opt.key]
		local value = opt.def
		if raw ~= nil and raw ~= "" then
			if opt.values then
				if opt.values[raw] then
					value = raw
				end
			elseif type(opt.def) == "boolean" then
				value = (raw == "1" or raw == "true" or raw == "on")
			else
				local n = tonumber(raw)
				if n then
					value = math.max(opt.min, math.min(opt.max, n))
				end
			end
		end
		settings[name] = value
	end

	return settings
end

-- GameRulesParam names shared between the core gadget and every consumer.
Defs.Params = {
	mode = "weather_mode",
	climate = "weather_climate",
	type = "weather_type",
	prevType = "weather_prev_type",
	blend = "weather_blend", -- 0..1 progress from prevType to type
	changeFrame = "weather_change_frame",
	precip = "weather_precip",
	cloud = "weather_cloud",
	fog = "weather_fog",
	windMin = "weather_wind_min",
	windMax = "weather_wind_max",
	effectScale = "weather_effect_scale",
	dayNight = "weather_daynight", -- 1 when the day/night cycle is enabled
	timeOfDay = "weather_time_of_day", -- hours, 0..24
	-- forecast entries: weather_next1_type / weather_next1_frame, weather_next2_type / ...
	nextTypePrefix = "weather_next",
	-- weather_fx_<system> = 1 while that effect system's gadget is applying modifiers
	systemPrefix = "weather_fx_",
}

function Defs.SystemParam(system)
	return Defs.Params.systemPrefix .. system
end

function Defs.NextTypeParam(i)
	return Defs.Params.nextTypePrefix .. i .. "_type"
end

function Defs.NextFrameParam(i)
	return Defs.Params.nextTypePrefix .. i .. "_frame"
end

return Defs
