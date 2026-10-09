local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Weather HUD",
		desc = "Weather panel in the top bar: current weather, intensity, time of day and forecast, a tooltip with who the weather favors, and warning banners before changes.",
		author = "mjrichar09",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local Defs = VFS.Include("luarules/configs/weather_defs.lua")
local Hud = VFS.Include("luaui/configs/weather_hud_logic.lua").Setup(Defs)
local P = Defs.Params

local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetGameFrame = Spring.GetGameFrame
local spGetMouseState = Spring.GetMouseState
local spPlaySoundFile = Spring.PlaySoundFile
local spEcho = Spring.Echo

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glColor = gl.Color
local glVertex = gl.Vertex
local glBeginEnd = gl.BeginEnd
local glLineWidth = gl.LineWidth
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_QUADS = GL.QUADS
local GL_LINES = GL.LINES

local floor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathCos = math.cos
local mathSin = math.sin
local mathPi = math.pi

local FPS = Game.gameSpeed or 30
local PANEL_WIDTH = 220 -- at widgetScale 1
local UPDATE_SECONDS = 0.25
local BANNER_SECONDS = 5
local BANNER_FADE_SECONDS = 1
local SOUND_WARNING = "beep6"
local SOUND_CHANGE = "beep4"

-- Systems that own at least one modifier, so we know which weather_fx_* params to read.
local SYSTEMS = {}
do
	local seen = {}
	for _, key in ipairs(Defs.ModifierOrder) do
		local system = Defs.ModifierInfo[key].system
		if not seen[system] then
			seen[system] = true
			SYSTEMS[#SYSTEMS + 1] = system
		end
	end
end

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = 1
local font
local RectRound, UiElement

local area = { 0, 0, 0, 0 }
local useSkew, skewTan = false, 0
local layoutDirty = true
local visible = false

local dlistGuishader, dlistBackground, dlistContent
local displayedSignature
local displayedTooltip
local banner -- { title, subtitle, started (os.clock seconds) }
local announcer = Hud.NewAnnouncer(Defs.Pacing.warningSeconds)
local state
local sinceUpdate = UPDATE_SECONDS
local clock = 0

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local function readState()
	local weatherType = spGetGameRulesParam(P.type)
	if not weatherType then
		return nil
	end
	local s = {
		frame = spGetGameFrame(),
		type = weatherType,
		prevType = spGetGameRulesParam(P.prevType),
		blend = spGetGameRulesParam(P.blend) or 1,
		climate = spGetGameRulesParam(P.climate),
		dayNight = spGetGameRulesParam(P.dayNight) == 1,
		timeOfDay = spGetGameRulesParam(P.timeOfDay) or 12,
		effectScale = spGetGameRulesParam(P.effectScale) or 1,
		windMin = spGetGameRulesParam(P.windMin),
		windMax = spGetGameRulesParam(P.windMax),
		forecast = {},
		active = {},
	}
	for i = 1, Defs.Pacing.forecastLength do
		local nextType = spGetGameRulesParam(Defs.NextTypeParam(i))
		local nextFrame = spGetGameRulesParam(Defs.NextFrameParam(i))
		if nextType and nextType ~= "" and nextFrame and nextFrame >= 0 then
			s.forecast[#s.forecast + 1] = { type = nextType, frame = nextFrame }
		end
	end
	for _, system in ipairs(SYSTEMS) do
		if spGetGameRulesParam(Defs.SystemParam(system)) == 1 then
			s.active[system] = true
		end
	end
	return s
end

--------------------------------------------------------------------------------
-- Icons (drawn from primitives; no art assets)
--------------------------------------------------------------------------------

local function disc(x, y, r, color)
	glColor(color)
	glBeginEnd(GL_TRIANGLE_FAN, function()
		glVertex(x, y)
		for i = 0, 20 do
			local a = i / 20 * 2 * mathPi
			glVertex(x + mathCos(a) * r, y + mathSin(a) * r)
		end
	end)
end

local function cloud(x, y, r, color)
	disc(x - r * 0.45, y - r * 0.1, r * 0.42, color)
	disc(x + r * 0.45, y - r * 0.1, r * 0.42, color)
	disc(x, y + r * 0.15, r * 0.52, color)
	glColor(color)
	glBeginEnd(GL_QUADS, function()
		glVertex(x - r * 0.45, y - r * 0.52)
		glVertex(x + r * 0.45, y - r * 0.52)
		glVertex(x + r * 0.45, y - r * 0.1)
		glVertex(x - r * 0.45, y - r * 0.1)
	end)
end

local function lines(segments, color, width)
	glColor(color)
	glLineWidth(width)
	glBeginEnd(GL_LINES, function()
		for i = 1, #segments, 4 do
			glVertex(segments[i], segments[i + 1])
			glVertex(segments[i + 2], segments[i + 3])
		end
	end)
	glLineWidth(1)
end

local function drawIcon(weatherType, night, x, y, r)
	local cloudY = y + r * 0.25
	if weatherType == "clear" then
		if night then
			disc(x, y, r * 0.6, { 0.85, 0.88, 1.0, 1 })
			disc(x + r * 0.28, y + r * 0.2, r * 0.5, { 0.08, 0.08, 0.1, 1 })
		else
			disc(x, y, r * 0.55, { 1.0, 0.85, 0.25, 1 })
		end
	elseif weatherType == "overcast" then
		cloud(x, y, r, { 0.75, 0.77, 0.8, 1 })
	elseif weatherType == "rain" then
		cloud(x, cloudY, r * 0.85, { 0.62, 0.66, 0.72, 1 })
		local segments = {}
		for i = -1, 1 do
			local lx = x + i * r * 0.35
			segments[#segments + 1] = lx
			segments[#segments + 1] = y - r * 0.35
			segments[#segments + 1] = lx - r * 0.12
			segments[#segments + 1] = y - r * 0.75
		end
		lines(segments, { 0.45, 0.7, 1.0, 1 }, 2 * widgetScale)
	elseif weatherType == "storm" then
		cloud(x, cloudY, r * 0.85, { 0.38, 0.4, 0.46, 1 })
		lines({
			x + r * 0.1, y - r * 0.2, x - r * 0.15, y - r * 0.5,
			x - r * 0.15, y - r * 0.5, x + r * 0.1, y - r * 0.5,
			x + r * 0.1, y - r * 0.5, x - r * 0.12, y - r * 0.85,
		}, { 1.0, 0.9, 0.3, 1 }, 2.5 * widgetScale)
	elseif weatherType == "fog" then
		local segments = {}
		for i = 0, 2 do
			local ly = y + r * (0.4 - i * 0.4)
			local inset = (i == 1) and 0 or r * 0.2
			segments[#segments + 1] = x - r * 0.75 + inset
			segments[#segments + 1] = ly
			segments[#segments + 1] = x + r * 0.75 - inset
			segments[#segments + 1] = ly
		end
		lines(segments, { 0.8, 0.82, 0.85, 1 }, 3 * widgetScale)
	elseif weatherType == "snow" then
		cloud(x, cloudY, r * 0.85, { 0.78, 0.8, 0.85, 1 })
		for i = -1, 1 do
			disc(x + i * r * 0.35, y - r * (0.5 + (i % 2) * 0.2), r * 0.09, { 1, 1, 1, 1 })
		end
	end
end

--------------------------------------------------------------------------------
-- Layout and drawing
--------------------------------------------------------------------------------

local function removeGuishader()
	if dlistGuishader then
		if WG.guishader then
			WG.guishader.RemoveDlist("weather_hud")
		end
		glDeleteList(dlistGuishader)
		dlistGuishader = nil
	end
end

local function updateLayout()
	if not WG.topbar or not WG.topbar.GetFreeArea then
		return false
	end
	local free = WG.topbar.GetFreeArea()
	local nextScale = free[5] or 1
	local topbarH = free[4] - free[2]
	local nextSkew, nextTan, vPad = false, 0, 0
	if WG.topbar.GetSkewConfig then
		local cfg = WG.topbar.GetSkewConfig()
		nextSkew, nextTan = cfg.useSkew, cfg.skewTan or 0
		if nextSkew then
			vPad = floor(topbarH * (1 - cfg.smallElementHeightFraction))
		end
	end
	-- Right end of the free area, so we never overlap widgets that fill it from the left.
	-- The free area only reserves a fixed share for the button strip, which sizes to its
	-- buttons (e.g. Save in single player) and can grow past it, so stop at its real edge.
	local x2 = free[3]
	if WG.topbar.GetButtonsPosition then
		local buttons = WG.topbar.GetButtonsPosition()
		if buttons then
			x2 = mathMin(x2, buttons[1] - floor((WG.FlowUI.elementMargin or 0) + 0.5))
		end
	end
	local x1 = mathMax(free[1], x2 - floor(PANEL_WIDTH * nextScale))
	local y1, y2 = free[2] + vPad, free[4]

	if layoutDirty or nextScale ~= widgetScale or nextSkew ~= useSkew or nextTan ~= skewTan
		or x1 ~= area[1] or y1 ~= area[2] or x2 ~= area[3] or y2 ~= area[4] then
		widgetScale, useSkew, skewTan = nextScale, nextSkew, nextTan
		area[1], area[2], area[3], area[4] = x1, y1, x2, y2
		layoutDirty = false

		removeGuishader()
		dlistGuishader = glCreateList(function()
			if useSkew then
				local skewOffset = (area[4] - area[2]) * skewTan
				glBeginEnd(GL_QUADS, function()
					glVertex(area[1] - skewOffset, area[2])
					glVertex(area[3] - skewOffset, area[2])
					glVertex(area[3], area[4])
					glVertex(area[1], area[4])
				end)
			else
				RectRound(area[1], area[2], area[3], area[4], 5.5 * widgetScale, 0, 0, 1, 1)
			end
		end)
		if WG.guishader then
			WG.guishader.InsertDlist(dlistGuishader, "weather_hud")
		end

		if dlistBackground then
			glDeleteList(dlistBackground)
		end
		dlistBackground = glCreateList(function()
			local H = area[4] - area[2]
			local skew = useSkew and { blx = -(H * skewTan), brx = -(H * skewTan) } or nil
			UiElement(area[1], area[2], area[3], area[4], 0, 0, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, skew)
		end)
		displayedSignature = nil
	end
	return true
end

-- Right edge of the (possibly skewed) panel at height y.
local function rightEdgeAt(y)
	if not useSkew then
		return area[3]
	end
	return area[3] - (area[4] - y) * skewTan
end

local function drawContent(s)
	local H = area[4] - area[2]
	local pad = H * 0.12
	local night = Hud.IsNight(s)

	drawIcon(s.type, night, area[1] + pad + H * 0.4, area[2] + H * 0.5, H * 0.36)

	local tx = area[1] + pad + H * 0.85
	local bigSize = H * 0.36
	local smallSize = H * 0.25
	local topY = area[2] + H * 0.56
	local bottomY = area[2] + H * 0.16

	font:Begin()
	font:Print("\255\255\255\255" .. Hud.Label(s.type), tx, topY, bigSize, "o")
	if s.dayNight then
		local clockText = (night and "\255\160\175\255" or "\255\255\225\140") .. Hud.FormatClock(s.timeOfDay)
		font:Print(clockText, rightEdgeAt(topY) - pad, topY + (bigSize - smallSize) * 0.3, smallSize, "or")
	end
	-- "Next: <icon> Rain  1:20". The icon is drawn after the text pass, in the gap left for it.
	local nextEntry = s.forecast[1]
	local nextIconX, nextIconR
	if nextEntry then
		local prefix = "Next: "
		font:Print("\255\180\180\180" .. prefix, tx, bottomY, smallSize, "o")
		nextIconR = smallSize * 0.5
		nextIconX = tx + font:GetTextWidth(prefix) * smallSize + nextIconR
		local text = "\255\255\255\255" .. Hud.Label(nextEntry.type)
			.. "  \255\180\180\180" .. Hud.FormatEta(nextEntry.frame - s.frame, FPS)
		font:Print(text, nextIconX + nextIconR * 1.4, bottomY, smallSize, "o")
	end
	font:End()

	if nextEntry then
		-- Forecasts are minutes ahead, so the current day/night picks the sun or moon.
		drawIcon(nextEntry.type, night, nextIconX, bottomY + smallSize * 0.35, nextIconR)
	end

	-- Thin intensity bar along the bottom while a new type is blending in.
	if s.prevType ~= s.type and s.blend < 1 then
		local by1 = area[2] + H * 0.05
		local by2 = by1 + mathMax(2, H * 0.05)
		local bx1 = tx
		local bx2 = rightEdgeAt(by2) - pad
		RectRound(bx1, by1, bx2, by2, 1 * widgetScale, 1, 1, 1, 1, { 1, 1, 1, 0.15 })
		RectRound(bx1, by1, bx1 + (bx2 - bx1) * s.blend, by2, 1 * widgetScale, 1, 1, 1, 1, { 0.55, 0.8, 1, 0.85 })
	end
end

local function contentSignature(s)
	local nextEntry = s.forecast[1]
	return table.concat({
		s.type,
		tostring(s.prevType),
		floor(s.blend * 50),
		s.dayNight and floor(s.timeOfDay * 60) or "",
		nextEntry and (nextEntry.type .. floor((nextEntry.frame - s.frame) / FPS)) or "",
	}, "|")
end

local function hide()
	visible = false
	removeGuishader()
	if dlistBackground then
		glDeleteList(dlistBackground)
		dlistBackground = nil
	end
	if dlistContent then
		glDeleteList(dlistContent)
		dlistContent = nil
	end
	if WG.tooltip and displayedTooltip then
		WG.tooltip.RemoveTooltip("weather_hud")
	end
	displayedTooltip = nil
	displayedSignature = nil
	layoutDirty = true
end

--------------------------------------------------------------------------------
-- Announcements
--------------------------------------------------------------------------------

local function announce(event)
	spEcho(Hud.EventMessage(event, FPS))
	local title, subtitle = Hud.EventBanner(event)
	if title then
		banner = { title = title, subtitle = subtitle, started = clock }
		spPlaySoundFile(event.kind == "warning" and SOUND_WARNING or SOUND_CHANGE, 0.8, "ui")
	end
end

local function drawBanner()
	if not banner then
		return
	end
	local age = clock - banner.started
	if age > BANNER_SECONDS then
		banner = nil
		return
	end
	local alpha = mathMin(1, (BANNER_SECONDS - age) / BANNER_FADE_SECONDS)
	local y = vsy * 0.78
	if WG.topbar and WG.topbar.GetPosition then
		y = WG.topbar.GetPosition()[2] - 70 * widgetScale
	end
	local titleSize = 30 * widgetScale
	local subtitleSize = 17 * widgetScale

	-- The font object is shared with other widgets, so restore its colors afterwards.
	font:Begin()
	font:SetOutlineColor(0, 0, 0, 0.8 * alpha)
	font:SetTextColor(1, 1, 1, alpha)
	font:Print(banner.title, vsx * 0.5, y, titleSize, "co")
	if banner.subtitle ~= "" then
		font:SetTextColor(0.6, 0.95, 0.6, alpha)
		font:Print(banner.subtitle, vsx * 0.5, y - titleSize * 0.9, subtitleSize, "co")
	end
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
	font:End()
end

--------------------------------------------------------------------------------
-- Call-ins
--------------------------------------------------------------------------------

function widget:Update(dt)
	clock = clock + dt
	sinceUpdate = sinceUpdate + dt
	if sinceUpdate < UPDATE_SECONDS then
		return
	end
	sinceUpdate = 0

	state = readState()
	if not state then
		if visible then
			hide()
		end
		return
	end

	for _, event in ipairs(announcer:Update(state, FPS)) do
		announce(event)
	end

	if not updateLayout() then
		return
	end
	visible = true

	local signature = contentSignature(state)
	if signature ~= displayedSignature then
		displayedSignature = signature
		if dlistContent then
			glDeleteList(dlistContent)
		end
		local s = state
		dlistContent = glCreateList(function()
			drawContent(s)
		end)
	end

	if WG.tooltip then
		local text = Hud.TooltipText(state, FPS)
		if text ~= displayedTooltip then
			displayedTooltip = text
			WG.tooltip.AddTooltip("weather_hud", area, text, nil, Hud.TooltipTitle(state))
		end
	end
end

function widget:DrawScreen()
	if visible then
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		if dlistBackground then
			glCallList(dlistBackground)
		end
		if dlistContent then
			glCallList(dlistContent)
		end
		local x, y = spGetMouseState()
		if math.isInRect(x, y, area[1], area[2], area[3], area[4]) then
			Spring.SetMouseCursor("cursornormal")
		end
	end
	drawBanner()
end

function widget:MousePress(x, y, button)
	if visible and math.isInRect(x, y, area[1], area[2], area[3], area[4]) then
		return true
	end
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	font = WG.fonts.getFont(2)
	layoutDirty = true
	displayedSignature = nil
end

function widget:Initialize()
	if not WG.FlowUI or not WG.fonts then
		spEcho("[Weather] HUD needs BAR's FlowUI and fonts widgets; disabling.")
		widgetHandler:RemoveWidget()
		return
	end
	widget:ViewResize()
	WG.weatherHud = {
		---Screen rectangle of the weather panel.
		GetPosition = function()
			return area
		end,
	}
end

function widget:Shutdown()
	hide()
	WG.weatherHud = nil
end
