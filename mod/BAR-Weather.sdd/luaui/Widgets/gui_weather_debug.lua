local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Weather Debug",
		desc = "Shows the raw weather state and forecast from Weather Core. Developer aid; the Weather HUD is the player-facing display.",
		author = "mjrichar09",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
	}
end

local Defs = VFS.Include("luarules/configs/weather_defs.lua")
local P = Defs.Params

local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetGameFrame = Spring.GetGameFrame
local spGetViewGeometry = Spring.GetViewGeometry
local FPS = Game.gameSpeed or 30

local FONT_SIZE = 14

local function label(typeName)
	local t = Defs.Types[typeName]
	return t and t.label or tostring(typeName)
end

local function formatClock(hours)
	local h = math.floor(hours)
	local m = math.floor((hours - h) * 60)
	return string.format("%02d:%02d", h, m)
end

local function formatEta(frames)
	local seconds = math.max(0, math.floor(frames / FPS))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function widget:DrawScreen()
	local current = spGetGameRulesParam(P.type)
	if not current then
		return
	end

	local frame = spGetGameFrame()
	local lines = {
		string.format("Weather: %s  (%.0f%%)", label(current), (spGetGameRulesParam(P.blend) or 1) * 100),
		string.format("Climate: %s", tostring(spGetGameRulesParam(P.climate))),
		string.format(
			"Precip %.2f  Cloud %.2f  Fog %.2f  Wind %.0f-%.0f",
			spGetGameRulesParam(P.precip) or 0,
			spGetGameRulesParam(P.cloud) or 0,
			spGetGameRulesParam(P.fog) or 0,
			spGetGameRulesParam(P.windMin) or 0,
			spGetGameRulesParam(P.windMax) or 0
		),
	}
	if spGetGameRulesParam(P.dayNight) == 1 then
		lines[#lines + 1] = "Time: " .. formatClock(spGetGameRulesParam(P.timeOfDay) or 12)
	end
	for i = 1, Defs.Pacing.forecastLength do
		local nextType = spGetGameRulesParam(Defs.NextTypeParam(i))
		local nextFrame = spGetGameRulesParam(Defs.NextFrameParam(i)) or -1
		if nextType and nextType ~= "" then
			lines[#lines + 1] = string.format("Next %d: %s in %s", i, label(nextType), formatEta(nextFrame - frame))
		end
	end

	local vsx, vsy = spGetViewGeometry()
	local x = vsx * 0.01
	local y = vsy * 0.70
	for i = 1, #lines do
		gl.Text(lines[i], x, y - (i - 1) * (FONT_SIZE + 4), FONT_SIZE, "o")
	end
end
