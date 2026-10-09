-- Text and announcement logic for the weather HUD (gui_weather_hud.lua), kept free of
-- drawing and Spring calls so it can be tested offline.
--
-- Functions take a `state` table that the widget builds from GameRulesParams:
--   frame, type, prevType, blend, climate, dayNight (bool), timeOfDay, effectScale,
--   windMin, windMax,
--   forecast = { { type = name, frame = startFrame }, ... },
--   active   = { [system] = true }   -- effect systems whose gadget is running

local Hud = {}

local COLOR_FAVORS = "\255\120\230\120"
local COLOR_HURTS = "\255\255\150\100"
local COLOR_DIM = "\255\170\170\170"
local COLOR_WHITE = "\255\255\255\255"

function Hud.Setup(defs)
	Hud.Defs = defs
	return Hud
end

function Hud.Label(typeName)
	local t = Hud.Defs.Types[typeName]
	return t and t.label or tostring(typeName)
end

function Hud.FormatEta(frames, fps)
	local seconds = math.max(0, math.floor(frames / fps))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Hud.FormatClock(hours)
	local h = math.floor(hours)
	local m = math.floor((hours - h) * 60)
	return string.format("%02d:%02d", h, m)
end

function Hud.IsNight(state)
	return state.dayNight and Hud.Defs.IsNight(state.timeOfDay or 12) or false
end

-- Conditions currently in force, in display order: the weather type, then night.
function Hud.Conditions(state)
	local list = { state.type }
	if Hud.IsNight(state) then
		list[#list + 1] = "night"
	end
	return list
end

local function conditionLabel(condition)
	if condition == "night" then
		return Hud.Defs.Night.label
	end
	return Hud.Label(condition)
end

local function conditionInfo(condition)
	if condition == "night" then
		return Hud.Defs.Night
	end
	return Hud.Defs.Types[condition]
end

-- "Solar output x0.7", or just the label for on/off mechanics. effectScale stretches the
-- distance from 1.0 the same way the effect gadgets will (PLAN.md section 5).
function Hud.FormatModifier(key, value, effectScale)
	local info = Hud.Defs.ModifierInfo[key]
	if value == true then
		return info.label
	end
	local scaled = 1 + (value - 1) * (effectScale or 1)
	scaled = math.max(0, scaled)
	if scaled == 0 then
		return info.label .. ": none"
	end
	local percent = math.floor((scaled - 1) * 100 + 0.5)
	return string.format("%s %s%d%%", info.label, percent >= 0 and "+" or "", percent)
end

-- Returns the live modifier lines for the current conditions, and how many modifiers
-- exist in the design but are not applied yet (their system isn't running).
function Hud.ModifierLines(state)
	local lines, pending = {}, 0
	local conditions = Hud.Conditions(state)
	local tagged = #conditions > 1
	for _, condition in ipairs(conditions) do
		local mods = Hud.Defs.Modifiers[condition] or {}
		for _, key in ipairs(Hud.Defs.ModifierOrder) do
			local value = mods[key]
			if value ~= nil then
				if state.active and state.active[Hud.Defs.ModifierInfo[key].system] then
					local line = Hud.FormatModifier(key, value, state.effectScale)
					if tagged then
						line = line .. COLOR_DIM .. " (" .. conditionLabel(condition) .. ")"
					end
					lines[#lines + 1] = line
				else
					pending = pending + 1
				end
			end
		end
	end
	return lines, pending
end

function Hud.TooltipTitle(state)
	local title = "Weather: " .. Hud.Label(state.type)
	if Hud.IsNight(state) then
		title = title .. " at night"
	end
	return title
end

function Hud.TooltipText(state, fps)
	local out = {}
	local function add(line)
		out[#out + 1] = line
	end

	if state.prevType and state.prevType ~= state.type and (state.blend or 1) < 1 then
		add(string.format("%sArriving: %d%% (from %s)", COLOR_DIM, math.floor((state.blend or 0) * 100), Hud.Label(state.prevType)))
	end

	for _, condition in ipairs(Hud.Conditions(state)) do
		local info = conditionInfo(condition)
		if info then
			local prefix = condition == "night" and (conditionLabel(condition) .. ": ") or ""
			add(COLOR_FAVORS .. prefix .. "Favors: " .. COLOR_WHITE .. info.favors)
			add(COLOR_HURTS .. prefix .. "Hurts: " .. COLOR_WHITE .. info.hurts)
		end
	end

	local lines, pending = Hud.ModifierLines(state)
	if #lines > 0 then
		add("")
		add("Active effects:")
		for _, line in ipairs(lines) do
			add("  " .. COLOR_WHITE .. line)
		end
	end
	if state.active and state.active.economy and state.windMin then
		add(string.format("  %sWind %.0f-%.0f", COLOR_WHITE, state.windMin, state.windMax or state.windMin))
	end
	if pending > 0 then
		add("")
		add(COLOR_DIM .. "Gameplay effects are not active in this version yet.")
	end

	if state.forecast and #state.forecast > 0 then
		add("")
		add("Forecast:")
		for _, entry in ipairs(state.forecast) do
			local info = Hud.Defs.Types[entry.type]
			add(string.format(
				"  %s%s in %s%s",
				COLOR_WHITE,
				Hud.Label(entry.type),
				Hud.FormatEta(entry.frame - state.frame, fps),
				info and (COLOR_DIM .. ": favors " .. string.lower(info.favors)) or ""
			))
		end
	end

	add("")
	local footer = "Climate: " .. tostring(state.climate)
	if state.dayNight then
		footer = footer .. "  |  " .. Hud.FormatClock(state.timeOfDay or 12) .. (Hud.IsNight(state) and " (night)" or " (day)")
	end
	add(COLOR_DIM .. footer)

	return table.concat(out, "\n")
end

-- Tracks what has been announced and turns state updates into announcement events:
--   { kind = "forecast", type, seconds }  a new change entered forecast slot 1
--   { kind = "warning",  type, seconds }  the next change is warnSeconds or less away
--   { kind = "change",   type, prevType } the weather type just changed
function Hud.NewAnnouncer(warnSeconds)
	local announcer = { lastType = nil, lastForecastKey = nil, warnedKey = nil }

	function announcer:Update(state, fps)
		local events = {}
		if not state.type then
			return events
		end

		if self.lastType and state.type ~= self.lastType then
			events[#events + 1] = { kind = "change", type = state.type, prevType = self.lastType }
		end
		self.lastType = state.type

		local nextEntry = state.forecast and state.forecast[1]
		if nextEntry then
			local key = nextEntry.type .. "@" .. nextEntry.frame
			local framesLeft = nextEntry.frame - state.frame
			local seconds = math.floor(framesLeft / fps)
			if key ~= self.lastForecastKey then
				self.lastForecastKey = key
				if framesLeft > warnSeconds * fps then
					events[#events + 1] = { kind = "forecast", type = nextEntry.type, seconds = seconds }
				end
			end
			if key ~= self.warnedKey and framesLeft > 0 and framesLeft <= warnSeconds * fps then
				self.warnedKey = key
				events[#events + 1] = { kind = "warning", type = nextEntry.type, seconds = seconds }
			end
		end

		return events
	end

	return announcer
end

-- Console line for an announcement event.
function Hud.EventMessage(event, fps)
	if event.kind == "change" then
		return "[Weather] Now: " .. Hud.Label(event.type)
	elseif event.kind == "warning" then
		return string.format("[Weather] %s in %d seconds", Hud.Label(event.type), event.seconds)
	end
	return string.format("[Weather] Forecast: %s in %s", Hud.Label(event.type), Hud.FormatEta(event.seconds * fps, fps))
end

-- Banner title and subtitle for warnings and changes (forecast events only go to the console).
function Hud.EventBanner(event)
	local info = Hud.Defs.Types[event.type]
	local subtitle = info and ("Favors: " .. info.favors) or ""
	if event.kind == "change" then
		return Hud.Label(event.type), subtitle
	elseif event.kind == "warning" then
		return string.format("%s in %d s", Hud.Label(event.type), event.seconds), subtitle
	end
	return nil
end

return Hud
