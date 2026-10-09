local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Weather Core",
		desc = "Simulates match weather and the day/night clock; publishes state as GameRulesParams and GG.Weather",
		author = "mjrichar09",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -100, -- before the weather effect gadgets
		enabled = true,
	}
end

local Defs = VFS.Include("luarules/configs/weather_defs.lua")
local settings = Defs.ReadOptions(Spring.GetModOptions())

local PACKET_HEADER = "$weather$"
local PACKET_HEADER_LENGTH = #PACKET_HEADER

if gadgetHandler:IsSyncedCode() then
	--------------------------------------------------------------------------------
	-- SYNCED
	--------------------------------------------------------------------------------

	local spGetGameFrame = Spring.GetGameFrame
	local spSetGameRulesParam = Spring.SetGameRulesParam
	local mathRandom = math.random
	local mathMin = math.min
	local mathFloor = math.floor

	local FPS = Game.gameSpeed or 30
	local PUBLIC = { public = true }
	local P = Defs.Params

	local climate -- resolved climate name
	local allowed -- set of weather types allowed by the climate

	local current -- current weather type name
	local prev -- type we are blending from
	local changeFrame = 0 -- frame the current type started
	local transitionFrames = Defs.Pacing.transitionSeconds * FPS
	local queue = {} -- forecast: array of { type = name, frame = startFrame }

	local listeners = {}
	local snapshot = {} -- last published state, handed out through GG.Weather.GetState()

	--------------------------------------------------------------------------------
	-- Setup helpers
	--------------------------------------------------------------------------------

	-- Optional map-maker hook (PLAN.md section 12). For now only climate and start are read.
	local function loadMapConfig()
		local path = "mapconfig/weather.lua"
		if VFS.FileExists(path, VFS.MAP) then
			local ok, cfg = pcall(VFS.Include, path, nil, VFS.MAP)
			if ok and type(cfg) == "table" then
				return cfg
			end
			Spring.Log("Weather Core", LOG.WARNING, "Ignoring invalid " .. path)
		end
		return nil
	end

	local function resolveClimate(mapCfg)
		if settings.climate ~= "auto" then
			return settings.climate
		end
		if mapCfg and Defs.Climates[mapCfg.climate] then
			return mapCfg.climate
		end
		local mapName = string.lower(Game.mapName or "")
		for _, rule in ipairs(Defs.MapClimatePatterns) do
			if string.find(mapName, rule.pattern, 1, true) then
				return rule.climate
			end
		end
		return "temperate"
	end

	--------------------------------------------------------------------------------
	-- Simulation
	--------------------------------------------------------------------------------

	-- Picks the type that follows fromType. Iterates Defs.TypeOrder (never pairs) to stay synced.
	local function pickNext(fromType)
		local weights = Defs.Transitions[fromType] or {}
		local total = 0
		for _, name in ipairs(Defs.TypeOrder) do
			if name ~= fromType and allowed[name] and weights[name] then
				total = total + weights[name]
			end
		end

		if total > 0 then
			local roll = mathRandom() * total
			for _, name in ipairs(Defs.TypeOrder) do
				if name ~= fromType and allowed[name] and weights[name] then
					roll = roll - weights[name]
					if roll <= 0 then
						return name
					end
				end
			end
		end

		-- No allowed transition defined: fall back to any other allowed type.
		local options = {}
		for _, name in ipairs(Defs.TypeOrder) do
			if name ~= fromType and allowed[name] then
				options[#options + 1] = name
			end
		end
		if #options == 0 then
			return fromType
		end
		return options[mathRandom(#options)]
	end

	-- How long a state starting at startFrame lasts, in frames (PLAN.md section 4).
	local function rollDuration(startFrame)
		local minute = startFrame / FPS / 60
		local phase
		for _, p in ipairs(Defs.Pacing.phases) do
			phase = p
			if minute < p.untilMinute then
				break
			end
		end
		local mult = Defs.Pacing.volatility[settings.volatility] or 1
		local minSec = mathFloor(phase.minMinutes * 60 * mult)
		local maxSec = mathFloor(phase.maxMinutes * 60 * mult)
		return mathRandom(minSec, maxSec) * FPS
	end

	local function fillQueue()
		while #queue < Defs.Pacing.forecastLength do
			local last = queue[#queue]
			queue[#queue + 1] = {
				type = pickNext(last.type),
				frame = last.frame + rollDuration(last.frame),
			}
		end
	end

	-- Replace the forecast with a fresh one where the next change starts at firstFrame.
	local function rebuildQueue(firstFrame)
		queue = { { type = pickNext(current), frame = firstFrame } }
		fillQueue()
	end

	local function lerp(a, b, t)
		return a + (b - a) * t
	end

	local function currentBlend(frame)
		if prev == current then
			return 1
		end
		return mathMin(1, (frame - changeFrame) / transitionFrames)
	end

	local function timeOfDay(frame)
		local dayFrames = settings.dayLength * 60 * FPS
		return (Defs.DayNight.startHour + (frame / dayFrames) * 24) % 24
	end

	--------------------------------------------------------------------------------
	-- Publishing
	--------------------------------------------------------------------------------

	local function publishForecast()
		snapshot.forecast = queue
		for i = 1, Defs.Pacing.forecastLength do
			local entry = queue[i]
			spSetGameRulesParam(Defs.NextTypeParam(i), entry and entry.type or "", PUBLIC)
			spSetGameRulesParam(Defs.NextFrameParam(i), entry and entry.frame or -1, PUBLIC)
		end
	end

	local function publishAtmosphere(frame)
		local blend = currentBlend(frame)
		local a, b = Defs.Types[prev], Defs.Types[current]

		snapshot.type = current
		snapshot.prevType = prev
		snapshot.blend = blend
		snapshot.changeFrame = changeFrame
		snapshot.precip = lerp(a.precip, b.precip, blend)
		snapshot.cloud = lerp(a.cloud, b.cloud, blend)
		snapshot.fog = lerp(a.fog, b.fog, blend)
		snapshot.windMin = lerp(a.windMin, b.windMin, blend)
		snapshot.windMax = lerp(a.windMax, b.windMax, blend)
		snapshot.timeOfDay = settings.dayNight and timeOfDay(frame) or 12

		spSetGameRulesParam(P.type, current, PUBLIC)
		spSetGameRulesParam(P.prevType, prev, PUBLIC)
		spSetGameRulesParam(P.blend, blend, PUBLIC)
		spSetGameRulesParam(P.changeFrame, changeFrame, PUBLIC)
		spSetGameRulesParam(P.precip, snapshot.precip, PUBLIC)
		spSetGameRulesParam(P.cloud, snapshot.cloud, PUBLIC)
		spSetGameRulesParam(P.fog, snapshot.fog, PUBLIC)
		spSetGameRulesParam(P.windMin, snapshot.windMin, PUBLIC)
		spSetGameRulesParam(P.windMax, snapshot.windMax, PUBLIC)
		spSetGameRulesParam(P.timeOfDay, snapshot.timeOfDay, PUBLIC)
	end

	local function notifyListeners()
		for i = 1, #listeners do
			listeners[i](snapshot)
		end
	end

	-- Switches to newType right now and publishes everything.
	local function changeWeather(newType, frame)
		prev = current
		current = newType
		changeFrame = frame
		publishAtmosphere(frame)
		publishForecast()
		notifyListeners()
	end

	--------------------------------------------------------------------------------
	-- Debug commands (from the unsynced half; cheats required)
	--------------------------------------------------------------------------------

	local function handleCommand(words, playerID)
		local frame = spGetGameFrame()
		local sub = words[1]

		if sub == "set" then
			local newType = words[2]
			if not Defs.Types[newType] then
				return
			end
			changeWeather(newType, frame)
			rebuildQueue(frame + rollDuration(frame))
			publishForecast()
		elseif sub == "next" then
			local entry = table.remove(queue, 1)
			changeWeather(entry.type, frame)
			rebuildQueue(frame + rollDuration(frame))
			publishForecast()
		end
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if string.sub(msg, 1, PACKET_HEADER_LENGTH) ~= PACKET_HEADER then
			return
		end
		if not Spring.IsCheatingEnabled() then
			return true
		end
		local words = {}
		for word in string.gmatch(string.sub(msg, PACKET_HEADER_LENGTH + 1), "%S+") do
			words[#words + 1] = word
		end
		handleCommand(words, playerID)
		return true
	end

	--------------------------------------------------------------------------------
	-- Call-ins
	--------------------------------------------------------------------------------

	function gadget:Initialize()
		if settings.mode == "off" then
			gadgetHandler:RemoveGadget()
			return
		end

		local mapCfg = loadMapConfig()
		climate = resolveClimate(mapCfg)
		allowed = Defs.Climates[climate].allowed

		local start = (mapCfg and allowed[mapCfg.start] and mapCfg.start) or Defs.Climates[climate].start
		current = start
		prev = start

		-- Works both at game start and on /luarules reload mid-game.
		local frame = spGetGameFrame()
		changeFrame = frame
		local firstFrame = settings.firstChange * 60 * FPS + mathRandom(0, Defs.Pacing.firstChangeWindowSeconds) * FPS
		firstFrame = math.max(firstFrame, frame + Defs.Pacing.minNoticeSeconds * FPS)
		rebuildQueue(firstFrame)

		spSetGameRulesParam(P.mode, settings.mode, PUBLIC)
		spSetGameRulesParam(P.climate, climate, PUBLIC)
		spSetGameRulesParam(P.effectScale, settings.effectScale, PUBLIC)
		spSetGameRulesParam(P.dayNight, settings.dayNight and 1 or 0, PUBLIC)
		publishAtmosphere(frame)
		publishForecast()

		GG.Weather = {
			Defs = Defs,
			Settings = settings,
			Climate = climate,
			-- Read-only view of the latest published state. Do not modify it.
			GetState = function()
				return snapshot
			end,
			-- fn(state) is called synchronously whenever the weather type changes.
			AddListener = function(fn)
				listeners[#listeners + 1] = fn
			end,
			RemoveListener = function(fn)
				for i = #listeners, 1, -1 do
					if listeners[i] == fn then
						table.remove(listeners, i)
					end
				end
			end,
		}
	end

	function gadget:Shutdown()
		GG.Weather = nil
	end

	function gadget:GameFrame(n)
		local entry = queue[1]
		if entry and n >= entry.frame then
			table.remove(queue, 1)
			fillQueue()
			changeWeather(entry.type, n)
			return
		end

		-- Blend smoothly during transitions; otherwise refresh once a second for the clock.
		local blending = prev ~= current and n - changeFrame <= transitionFrames
		if (blending and n % 10 == 0) or n % FPS == 0 then
			publishAtmosphere(n)
		end
	end
else
	--------------------------------------------------------------------------------
	-- UNSYNCED: /luarules weather <status|set <type>|next>
	--------------------------------------------------------------------------------

	local spGetGameRulesParam = Spring.GetGameRulesParam
	local P = Defs.Params

	local function printStatus()
		local frame = Spring.GetGameFrame()
		local FPS = Game.gameSpeed or 30
		Spring.Echo(string.format(
			"[Weather] %s (from %s, blend %.2f) | climate %s | precip %.2f cloud %.2f fog %.2f wind %.0f-%.0f | %02.0fh",
			tostring(spGetGameRulesParam(P.type)),
			tostring(spGetGameRulesParam(P.prevType)),
			spGetGameRulesParam(P.blend) or 0,
			tostring(spGetGameRulesParam(P.climate)),
			spGetGameRulesParam(P.precip) or 0,
			spGetGameRulesParam(P.cloud) or 0,
			spGetGameRulesParam(P.fog) or 0,
			spGetGameRulesParam(P.windMin) or 0,
			spGetGameRulesParam(P.windMax) or 0,
			spGetGameRulesParam(P.timeOfDay) or 0
		))
		for i = 1, Defs.Pacing.forecastLength do
			local nextType = spGetGameRulesParam(Defs.NextTypeParam(i))
			local nextFrame = spGetGameRulesParam(Defs.NextFrameParam(i)) or -1
			if nextType and nextType ~= "" then
				Spring.Echo(string.format("[Weather]   next %d: %s in %ds", i, nextType, math.floor((nextFrame - frame) / FPS)))
			end
		end
	end

	local function weatherCommand(_, _, words)
		local sub = words[1]
		if sub == nil or sub == "status" then
			printStatus()
		elseif sub == "set" and words[2] and Defs.Types[words[2]] then
			Spring.SendLuaRulesMsg(PACKET_HEADER .. "set " .. words[2])
		elseif sub == "next" then
			Spring.SendLuaRulesMsg(PACKET_HEADER .. "next")
		else
			Spring.Echo("[Weather] usage: /luarules weather status | set <" .. table.concat(Defs.TypeOrder, "|") .. "> | next  (set/next need /cheat)")
		end
		return true
	end

	function gadget:Initialize()
		if settings.mode == "off" then
			gadgetHandler:RemoveGadget()
			return
		end
		gadgetHandler:AddChatAction("weather", weatherCommand, "Weather status and debug controls")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("weather")
	end
end
