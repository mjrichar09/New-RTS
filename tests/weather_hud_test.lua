-- Offline tests for luaui/configs/weather_hud_logic.lua (the Weather HUD's text and
-- announcement rules), including announcements driven by the real core gadget.
-- Run from the repo root:  lua tests/weather_hud_test.lua   (or python tests/run_tests.py)

local MOD_ROOT = MOD_ROOT or "mod/BAR-Weather.sdd"
local FPS = 30

local Defs = dofile(MOD_ROOT .. "/luarules/configs/weather_defs.lua")
local Hud = dofile(MOD_ROOT .. "/luaui/configs/weather_hud_logic.lua").Setup(Defs)

WEATHER_TEST_LIB = true
local Core = dofile((MOD_ROOT:gsub("mod/BAR%-Weather%.sdd$", "")) .. "tests/weather_core_test.lua")
WEATHER_TEST_LIB = nil

--------------------------------------------------------------------------------
-- Helpers
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

local function contains(haystack, needle)
	return string.find(haystack, needle, 1, true) ~= nil
end

-- Builds the HUD state from GameRulesParams, the same way gui_weather_hud.lua does.
local function stateFromParams(params, frame)
	local P = Defs.Params
	local s = {
		frame = frame,
		type = params[P.type],
		prevType = params[P.prevType],
		blend = params[P.blend] or 1,
		climate = params[P.climate],
		dayNight = params[P.dayNight] == 1,
		timeOfDay = params[P.timeOfDay] or 12,
		effectScale = params[P.effectScale] or 1,
		windMin = params[P.windMin],
		windMax = params[P.windMax],
		forecast = {},
		active = {},
	}
	for i = 1, Defs.Pacing.forecastLength do
		local t, f = params[Defs.NextTypeParam(i)], params[Defs.NextFrameParam(i)]
		if t and t ~= "" and f and f >= 0 then
			s.forecast[#s.forecast + 1] = { type = t, frame = f }
		end
	end
	return s
end

local function baseState(overrides)
	local s = {
		frame = 0, type = "rain", prevType = "rain", blend = 1, climate = "temperate",
		dayNight = true, timeOfDay = 12, effectScale = 1, windMin = 5, windMax = 18,
		forecast = { { type = "storm", frame = 90 * FPS } }, active = {},
	}
	for k, v in pairs(overrides or {}) do
		s[k] = v
	end
	return s
end

-- Simulates a match and feeds the announcer the way the widget does (every 0.25 s).
local function announcementsForMatch(seed, minutes)
	local sim = Core.loadGadget({ seed = seed })
	sim.gadget:Initialize()
	local changes = {}
	sim.GG.Weather.AddListener(function(st)
		changes[#changes + 1] = { type = st.type, frame = st.changeFrame }
	end)
	local announcer = Hud.NewAnnouncer(Defs.Pacing.warningSeconds)
	local events = {}
	local step = math.floor(FPS / 4)
	for n = 0, minutes * 60 * FPS do
		sim.frame = n
		sim.gadget:GameFrame(n)
		if n % step == 0 then
			for _, e in ipairs(announcer:Update(stateFromParams(sim.params, n), FPS)) do
				e.frame = n
				events[#events + 1] = e
			end
		end
	end
	return events, changes
end

--------------------------------------------------------------------------------
-- Defs consistency
--------------------------------------------------------------------------------

test("every weather type has a label, favors/hurts lines and a modifier entry", function()
	for _, name in ipairs(Defs.TypeOrder) do
		local t = Defs.Types[name]
		expect(t.label and t.favors and t.hurts, name .. " is missing label/favors/hurts")
		expect(Defs.Modifiers[name], name .. " has no Modifiers entry")
	end
	expect(Defs.Night.favors and Defs.Night.hurts and Defs.Modifiers.night, "night is incomplete")
end)

test("every modifier key is described and listed in display order", function()
	local ordered = {}
	for _, key in ipairs(Defs.ModifierOrder) do
		expect(Defs.ModifierInfo[key], key .. " has no ModifierInfo")
		ordered[key] = true
	end
	for condition, mods in pairs(Defs.Modifiers) do
		for key in pairs(mods) do
			expect(ordered[key], condition .. "." .. key .. " is missing from ModifierOrder")
		end
	end
end)

--------------------------------------------------------------------------------
-- Formatting
--------------------------------------------------------------------------------

test("ETA and clock formatting", function()
	expect(Hud.FormatEta(90 * FPS, FPS) == "1:30", Hud.FormatEta(90 * FPS, FPS))
	expect(Hud.FormatEta(5, FPS) == "0:00", "sub-second ETA")
	expect(Hud.FormatEta(-100, FPS) == "0:00", "negative ETA")
	expect(Hud.FormatClock(14.5) == "14:30", Hud.FormatClock(14.5))
	expect(Hud.FormatClock(6) == "06:00", Hud.FormatClock(6))
end)

test("modifiers format as rounded percentages, scaled by effect scale", function()
	expect(Hud.FormatModifier("solar", 0.7) == "Solar output -30%", Hud.FormatModifier("solar", 0.7))
	expect(Hud.FormatModifier("airSpeed", 0.95) == "Aircraft speed -5%", Hud.FormatModifier("airSpeed", 0.95))
	expect(Hud.FormatModifier("tidal", 1.15) == "Tidal output +15%", Hud.FormatModifier("tidal", 1.15))
	expect(Hud.FormatModifier("solar", 0) == "Solar output: none", Hud.FormatModifier("solar", 0))
	expect(Hud.FormatModifier("solar", 0.7, 0.5) == "Solar output -15%", Hud.FormatModifier("solar", 0.7, 0.5))
	expect(Hud.FormatModifier("mud", true) == Defs.ModifierInfo.mud.label, "flag modifier")
end)

--------------------------------------------------------------------------------
-- Tooltip
--------------------------------------------------------------------------------

test("tooltip never lists modifiers whose system is not running", function()
	local s = baseState()
	local lines, pending = Hud.ModifierLines(s)
	expect(#lines == 0, "listed inactive modifiers")
	expect(pending > 0, "no pending modifiers counted for rain")
	local text = Hud.TooltipText(s, FPS)
	expect(contains(text, "not active in this version"), "missing inactive note")
	expect(not contains(text, "Solar output"), "showed an inactive solar modifier")
end)

test("tooltip lists modifiers once their system is running", function()
	local s = baseState({ active = { economy = true } })
	local lines = Hud.ModifierLines(s)
	local text = Hud.TooltipText(s, FPS)
	expect(#lines == 2, "expected solar + tidal, got " .. #lines)
	expect(contains(text, "Solar output -30%"), "missing solar line")
	expect(contains(text, "Wind 5-18"), "missing wind range")
	expect(contains(text, "not active"), "should still note movement/terrain are pending")
end)

test("tooltip shows who is favored, the forecast and the clock", function()
	local text = Hud.TooltipText(baseState(), FPS)
	expect(contains(text, Defs.Types.rain.favors), "missing favors")
	expect(contains(text, Defs.Types.rain.hurts), "missing hurts")
	expect(contains(text, "Storm in 1:30"), "missing forecast entry")
	expect(contains(text, "12:00 (day)"), "missing clock")
	expect(Hud.TooltipTitle(baseState()) == "Weather: Rain", Hud.TooltipTitle(baseState()))
end)

test("night adds its own favors line and tags modifiers by condition", function()
	local s = baseState({ timeOfDay = 22, active = { economy = true } })
	local text = Hud.TooltipText(s, FPS)
	expect(contains(text, Defs.Night.favors), "missing night favors")
	expect(contains(text, "(Night)"), "night modifiers not tagged")
	expect(contains(text, "(night)"), "clock not marked night")
	expect(Hud.TooltipTitle(s) == "Weather: Rain at night", Hud.TooltipTitle(s))
end)

test("night is ignored when the day/night cycle is off", function()
	local s = baseState({ timeOfDay = 22, dayNight = false })
	expect(#Hud.Conditions(s) == 1, "night counted with day/night off")
	expect(not contains(Hud.TooltipText(s, FPS), "(night)"), "clock shown with day/night off")
end)

test("tooltip shows blend progress while a new type arrives", function()
	local text = Hud.TooltipText(baseState({ prevType = "overcast", blend = 0.4 }), FPS)
	expect(contains(text, "Arriving: 40% (from Overcast)"), text)
end)

--------------------------------------------------------------------------------
-- Announcements (unit)
--------------------------------------------------------------------------------

test("announcer: forecast once, warning once, then the change", function()
	local a = Hud.NewAnnouncer(30)
	local s = baseState({ frame = 0, forecast = { { type = "storm", frame = 100 * FPS } } })
	local e = a:Update(s, FPS)
	expect(#e == 1 and e[1].kind == "forecast" and e[1].type == "storm", "no initial forecast")
	expect(#a:Update(s, FPS) == 0, "repeated forecast")

	s.frame = 69 * FPS
	expect(#a:Update(s, FPS) == 0, "warned too early")
	s.frame = 70 * FPS + 1
	e = a:Update(s, FPS)
	expect(#e == 1 and e[1].kind == "warning" and e[1].seconds == 29, "no warning at 30 s")
	s.frame = 80 * FPS
	expect(#a:Update(s, FPS) == 0, "warned twice")

	s.frame = 100 * FPS
	s.type, s.prevType = "storm", "rain"
	s.forecast = { { type = "rain", frame = 400 * FPS } }
	e = a:Update(s, FPS)
	expect(#e == 2 and e[1].kind == "change" and e[1].type == "storm", "no change event")
	expect(e[2].kind == "forecast" and e[2].type == "rain", "no forecast for the following change")
end)

test("announcer: a change forced with less than 30 s notice still gets a warning, not a forecast", function()
	local a = Hud.NewAnnouncer(30)
	a:Update(baseState(), FPS)
	local e = a:Update(baseState({ forecast = { { type = "fog", frame = 20 * FPS } } }), FPS)
	expect(#e == 1 and e[1].kind == "warning", "expected only a warning")
end)

test("announcer: banners only for warnings and changes", function()
	expect(Hud.EventBanner({ kind = "forecast", type = "storm", seconds = 90 }) == nil, "forecast banner")
	local title, subtitle = Hud.EventBanner({ kind = "warning", type = "storm", seconds = 30 })
	expect(title == "Storm in 30 s", tostring(title))
	expect(contains(subtitle, Defs.Types.storm.favors), "banner missing favors")
	expect(Hud.EventBanner({ kind = "change", type = "fog" }) == "Fog", "change banner")
	expect(Hud.EventMessage({ kind = "forecast", type = "rain", seconds = 95 }, FPS) == "[Weather] Forecast: Rain in 1:35", "forecast message")
end)

--------------------------------------------------------------------------------
-- Announcements driven by the real core gadget
--------------------------------------------------------------------------------

test("whole matches: every change is warned once, ~30 s ahead, and announced", function()
	for seed = 1, 10 do
		local events, changes = announcementsForMatch(seed, 40)
		expect(#changes >= 5, "too few changes (seed " .. seed .. ")")

		local warnings, changed = {}, {}
		local lastFrame = 40 * 60 * FPS
		for _, e in ipairs(events) do
			-- Ignore a warning for a change that falls after the simulated match ends.
			if e.kind == "warning" and e.frame + (e.seconds + 1) * FPS <= lastFrame then
				warnings[#warnings + 1] = e
			elseif e.kind == "change" then
				changed[#changed + 1] = e
			end
		end
		expect(#changed == #changes, string.format("%d changes, %d change events (seed %d)", #changes, #changed, seed))
		expect(#warnings == #changes, string.format("%d changes, %d warnings (seed %d)", #changes, #warnings, seed))
		for i, c in ipairs(changes) do
			local lead = (c.frame - warnings[i].frame) / FPS
			expect(warnings[i].type == c.type, "warned about the wrong type (seed " .. seed .. ")")
			expect(lead > 29 and lead <= 30, string.format("warning %.2f s ahead (seed %d)", lead, seed))
			expect(changed[i].type == c.type and changed[i].frame - c.frame < FPS / 4 + 1, "change announced late")
		end
	end
end)

test("whole matches: each change is forecast at least 90 s ahead", function()
	for seed = 1, 10 do
		local events, changes = announcementsForMatch(seed, 40)
		for _, c in ipairs(changes) do
			local forecastFrame
			for _, e in ipairs(events) do
				if e.kind == "forecast" and e.type == c.type and e.frame <= c.frame and e.frame + e.seconds * FPS + FPS >= c.frame then
					forecastFrame = forecastFrame or e.frame
				end
			end
			expect(forecastFrame, "change to " .. c.type .. " was never forecast (seed " .. seed .. ")")
			local lead = (c.frame - forecastFrame) / FPS
			expect(lead >= Defs.Pacing.minNoticeSeconds - 1, string.format("forecast only %.0f s ahead (seed %d)", lead, seed))
		end
	end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
