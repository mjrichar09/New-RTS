-- Offline tests for luarules/gadgets/weather_core.lua.
-- Stubs the parts of the Recoil/BAR API the gadget uses and simulates whole matches.
-- Run with any Lua 5.1 interpreter from the repo root:  lua tests/weather_core_test.lua
-- (or: python tests/run_tests.py, which uses lupa's Lua 5.1)

local MOD_ROOT = MOD_ROOT or "mod/BAR-Weather.sdd"
local FPS = 30

local function readDefs()
	return dofile(MOD_ROOT .. "/luarules/configs/weather_defs.lua")
end
local Defs = readDefs()

--------------------------------------------------------------------------------
-- Engine stub
--------------------------------------------------------------------------------

-- Seeded stand-in for the engine's synced math.random (Park-Miller). The C rand() behind
-- Lua 5.1's math.random gives near-identical first values for small seeds on Windows,
-- which would hide bugs in anything that depends on spread.
local function makeRandom(seed)
	local state = (seed * 7919 + 12345) % 2147483647
	local function nextUnit()
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	for _ = 1, 5 do -- decorrelate the first draws from the seed
		nextUnit()
	end
	return function(m, n)
		local r = nextUnit()
		if m == nil then
			return r
		end
		if n == nil then
			m, n = 1, m
		end
		return m + math.floor(r * (n - m + 1))
	end
end

-- opts: synced (bool), modoptions (table), mapName (string), seed (number), cheats (bool), mapConfig (table|nil)
local function loadGadget(opts)
	opts = opts or {}
	local sim = {
		frame = 0,
		params = {},
		removed = false,
		chatActions = {},
		sentMsgs = {},
		cheats = opts.cheats or false,
	}

	local env = setmetatable({}, { __index = _G })
	env.gadget = {}
	env.GG = {}
	env.LOG = { WARNING = "warning", ERROR = "error" }
	env.Game = { gameSpeed = FPS, mapName = opts.mapName or "Test Map v1" }

	env.VFS = {
		MAP = "map",
		Include = function(path)
			if path == "mapconfig/weather.lua" then
				return opts.mapConfig
			end
			local chunk = assert(loadfile(MOD_ROOT .. "/" .. path))
			setfenv(chunk, env)
			return chunk()
		end,
		FileExists = function(path)
			return path == "mapconfig/weather.lua" and opts.mapConfig ~= nil
		end,
	}

	env.Spring = {
		GetModOptions = function()
			return opts.modoptions or {}
		end,
		GetGameFrame = function()
			return sim.frame
		end,
		SetGameRulesParam = function(k, v)
			sim.params[k] = v
		end,
		GetGameRulesParam = function(k)
			return sim.params[k]
		end,
		IsCheatingEnabled = function()
			return sim.cheats
		end,
		SendLuaRulesMsg = function(msg)
			sim.sentMsgs[#sim.sentMsgs + 1] = msg
		end,
		Echo = function() end,
		Log = function() end,
	}

	env.gadgetHandler = {
		IsSyncedCode = function()
			return opts.synced ~= false
		end,
		RemoveGadget = function()
			sim.removed = true
		end,
		AddChatAction = function(_, cmd, fn)
			sim.chatActions[cmd] = fn
		end,
		RemoveChatAction = function(_, cmd)
			sim.chatActions[cmd] = nil
		end,
	}

	env.math = setmetatable({ random = makeRandom(opts.seed or 1) }, { __index = math })
	local chunk = assert(loadfile(MOD_ROOT .. "/luarules/gadgets/weather_core.lua"))
	setfenv(chunk, env)
	chunk()

	sim.gadget = env.gadget
	sim.GG = env.GG
	return sim
end

-- Runs a synced match for `minutes`, returning the change log and per-frame forecast observations.
local function runMatch(opts, minutes)
	local sim = loadGadget(opts)
	sim.gadget:Initialize()

	local changes = {}
	sim.GG.Weather.AddListener(function(state)
		changes[#changes + 1] = { type = state.type, frame = state.changeFrame }
	end)

	-- For each announced (type, frame) pair, the first frame it appeared in forecast slot 1.
	local firstAnnounced = {}
	local lastFrame = minutes * 60 * FPS
	for n = 0, lastFrame do
		sim.frame = n
		sim.gadget:GameFrame(n)
		local key = tostring(sim.params[Defs.NextTypeParam(1)]) .. "@" .. tostring(sim.params[Defs.NextFrameParam(1)])
		if not firstAnnounced[key] then
			firstAnnounced[key] = n
		end
	end
	return sim, changes, firstAnnounced
end

-- Lets other scripts reuse the stub (e.g. to print match timelines) without running the tests.
if WEATHER_TEST_LIB then
	return { loadGadget = loadGadget, runMatch = runMatch }
end

--------------------------------------------------------------------------------
-- Test runner
--------------------------------------------------------------------------------

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("PASS  " .. name)
	else
		failed = failed + 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

local function expect(cond, msg)
	if not cond then
		error(msg, 2)
	end
end

local function phaseFor(startFrame)
	local minute = startFrame / FPS / 60
	for _, p in ipairs(Defs.Pacing.phases) do
		if minute < p.untilMinute then
			return p
		end
	end
end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

local SEEDS = 20

test("first change happens between 6:00 and 8:00 by default", function()
	for seed = 1, SEEDS do
		local _, changes = runMatch({ seed = seed }, 10)
		expect(#changes >= 1, "no change in 10 minutes (seed " .. seed .. ")")
		local t = changes[1].frame / FPS
		expect(t >= 360 and t <= 480, string.format("first change at %.0fs (seed %d)", t, seed))
	end
end)

test("first change time varies across matches", function()
	local distinct, seen = 0, {}
	for seed = 1, SEEDS do
		local _, changes = runMatch({ seed = seed }, 9)
		local t = changes[1].frame
		if not seen[t] then
			seen[t] = true
			distinct = distinct + 1
		end
	end
	expect(distinct >= SEEDS / 2, "only " .. distinct .. " distinct first-change times in " .. SEEDS .. " matches")
end)

test("weather_first_change modoption moves the first change", function()
	local _, changes = runMatch({ seed = 3, modoptions = { weather_first_change = "10" } }, 13)
	local t = changes[1].frame / FPS
	expect(t >= 600 and t <= 720, string.format("first change at %.0fs", t))
end)

test("first change still gets 90s notice when weather_first_change is 0", function()
	local _, changes = runMatch({ seed = 5, modoptions = { weather_first_change = "0" } }, 4)
	expect(changes[1].frame / FPS >= 90, "first change at " .. changes[1].frame / FPS .. "s")
end)

test("state durations follow the pacing phases", function()
	for seed = 1, SEEDS do
		local _, changes = runMatch({ seed = seed }, 60)
		for i = 1, #changes - 1 do
			local p = phaseFor(changes[i].frame)
			local secs = (changes[i + 1].frame - changes[i].frame) / FPS
			expect(
				secs >= p.minMinutes * 60 and secs <= p.maxMinutes * 60,
				string.format("state %d lasted %.0fs, phase allows %d-%d min (seed %d)", i, secs, p.minMinutes, p.maxMinutes, seed)
			)
		end
	end
end)

test("high volatility shortens states", function()
	local _, changes = runMatch({ seed = 7, modoptions = { weather_volatility = "high" } }, 60)
	for i = 1, #changes - 1 do
		local p = phaseFor(changes[i].frame)
		local secs = (changes[i + 1].frame - changes[i].frame) / FPS
		expect(secs <= p.maxMinutes * 60 * 0.75 + 1, string.format("state lasted %.0fs", secs))
	end
end)

test("every change was forecast in slot 1 at least 90s ahead", function()
	for seed = 1, SEEDS do
		local _, changes, firstAnnounced = runMatch({ seed = seed }, 60)
		for i, c in ipairs(changes) do
			local seen = firstAnnounced[c.type .. "@" .. c.frame]
			expect(seen ~= nil, string.format("change %d (%s) was never forecast (seed %d)", i, c.type, seed))
			local notice = (c.frame - seen) / FPS
			expect(notice >= 90, string.format("change %d only had %.0fs notice (seed %d)", i, notice, seed))
		end
	end
end)

test("weather never repeats the same type back to back", function()
	for seed = 1, SEEDS do
		local _, changes = runMatch({ seed = seed }, 60)
		local prevType = "clear"
		for i, c in ipairs(changes) do
			expect(c.type ~= prevType, string.format("change %d repeated %s (seed %d)", i, c.type, seed))
			prevType = c.type
		end
	end
end)

test("auto climate from map name restricts weather types (arid)", function()
	for seed = 1, SEEDS do
		local sim, changes = runMatch({ seed = seed, mapName = "Desert Dunes v2" }, 60)
		expect(sim.params.weather_climate == "arid", "climate was " .. tostring(sim.params.weather_climate))
		for _, c in ipairs(changes) do
			expect(Defs.Climates.arid.allowed[c.type], "arid map got " .. c.type)
		end
	end
end)

test("arctic maps can snow, temperate maps cannot", function()
	local sawSnow = false
	for seed = 1, SEEDS do
		local _, arctic = runMatch({ seed = seed, mapName = "Glacier Pass" }, 60)
		for _, c in ipairs(arctic) do
			sawSnow = sawSnow or c.type == "snow"
		end
		local _, temperate = runMatch({ seed = seed, mapName = "Green Fields" }, 60)
		for _, c in ipairs(temperate) do
			expect(c.type ~= "snow", "temperate map got snow (seed " .. seed .. ")")
		end
	end
	expect(sawSnow, "arctic map never snowed across seeds")
end)

test("climate modoption overrides the map name", function()
	local sim = runMatch({ seed = 1, mapName = "Desert Dunes", modoptions = { weather_climate = "arctic" } }, 0)
	expect(sim.params.weather_climate == "arctic", "climate was " .. tostring(sim.params.weather_climate))
end)

test("map config sets climate and start weather", function()
	local sim = runMatch({ seed = 1, mapName = "Green Fields", mapConfig = { climate = "marsh", start = "fog" } }, 0)
	expect(sim.params.weather_climate == "marsh", "climate was " .. tostring(sim.params.weather_climate))
	expect(sim.params.weather_type == "fog", "start was " .. tostring(sim.params.weather_type))
end)

test("same seed gives an identical match (determinism)", function()
	local _, a = runMatch({ seed = 42 }, 60)
	local _, b = runMatch({ seed = 42 }, 60)
	expect(#a == #b, "different number of changes")
	for i = 1, #a do
		expect(a[i].type == b[i].type and a[i].frame == b[i].frame, "diverged at change " .. i)
	end
end)

test("atmosphere blends over the transition and lands on the target values", function()
	local sim, changes = runMatch({ seed = 2 }, 8)
	local c = changes[1]
	local target = Defs.Types[c.type]
	-- step through the transition
	for n = sim.frame + 1, c.frame + Defs.Pacing.transitionSeconds * FPS + FPS do
		sim.frame = n
		sim.gadget:GameFrame(n)
	end
	expect(sim.params.weather_blend == 1, "blend ended at " .. tostring(sim.params.weather_blend))
	expect(math.abs(sim.params.weather_fog - target.fog) < 1e-6, "fog did not reach target")
	expect(math.abs(sim.params.weather_wind_max - target.windMax) < 1e-6, "windMax did not reach target")
end)

test("mid-transition values are between the two states", function()
	local sim = loadGadget({ seed = 1, cheats = true })
	sim.gadget:Initialize()
	sim.frame = 100
	sim.gadget:RecvLuaMsg("$weather$set fog", 0)
	local half = 100 + math.floor(Defs.Pacing.transitionSeconds * FPS / 2)
	for n = 101, half do
		sim.frame = n
		sim.gadget:GameFrame(n)
	end
	local fog = sim.params.weather_fog
	expect(fog > Defs.Types.clear.fog and fog < Defs.Types.fog.fog, "fog mid-transition was " .. tostring(fog))
end)

test("day/night clock starts in the morning and wraps after a full day", function()
	local sim = runMatch({ seed = 1, modoptions = { weather_daylength = "20" } }, 0)
	expect(math.abs(sim.params.weather_time_of_day - Defs.DayNight.startHour) < 1e-6, "start hour wrong")
	local sim2 = runMatch({ seed = 1, modoptions = { weather_daylength = "20" } }, 20)
	expect(math.abs(sim2.params.weather_time_of_day - Defs.DayNight.startHour) < 0.01, "clock did not wrap after one day")
end)

test("debug commands are ignored without cheats", function()
	local sim = loadGadget({ seed = 1, cheats = false })
	sim.gadget:Initialize()
	local consumed = sim.gadget:RecvLuaMsg("$weather$set storm", 0)
	expect(consumed == true, "message not consumed")
	expect(sim.params.weather_type == "clear", "weather changed without cheats")
end)

test("debug set/next work with cheats and keep a valid forecast", function()
	local sim = loadGadget({ seed = 1, cheats = true })
	sim.gadget:Initialize()
	sim.frame = 300
	sim.gadget:RecvLuaMsg("$weather$set storm", 0)
	expect(sim.params.weather_type == "storm", "set failed")
	expect(sim.params[Defs.NextTypeParam(1)] ~= "storm", "forecast repeats current type")
	expect(sim.params[Defs.NextFrameParam(1)] > 300, "forecast not in the future")
	local forecast = sim.params[Defs.NextTypeParam(1)]
	sim.gadget:RecvLuaMsg("$weather$next", 0)
	expect(sim.params.weather_type == forecast, "next did not apply the forecast")
end)

test("unrelated LuaRules messages are not consumed", function()
	local sim = loadGadget({ seed = 1, cheats = true })
	sim.gadget:Initialize()
	expect(sim.gadget:RecvLuaMsg("$dev$:something", 0) == nil, "consumed someone else's message")
end)

test("mode off removes the gadget and publishes nothing", function()
	local sim = loadGadget({ seed = 1, modoptions = { weather_mode = "off" } })
	sim.gadget:Initialize()
	expect(sim.removed, "gadget not removed")
	expect(sim.params.weather_type == nil, "params were published")
end)

test("unsynced half registers /luarules weather and forwards set", function()
	local sim = loadGadget({ synced = false })
	sim.gadget:Initialize()
	local fn = sim.chatActions.weather
	expect(fn ~= nil, "chat action not registered")
	fn("weather", "weather set rain", { "set", "rain" }, 0)
	expect(sim.sentMsgs[1] == "$weather$set rain", "sent " .. tostring(sim.sentMsgs[1]))
	fn("weather", "weather set tornado", { "set", "tornado" }, 0)
	expect(#sim.sentMsgs == 1, "forwarded an invalid type")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
