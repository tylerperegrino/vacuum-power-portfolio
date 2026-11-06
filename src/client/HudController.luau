-- HUD + menus — "Stud UI" style: chunky 3D stud buttons (lip + gradient face + glass streaks + subtle cube-stud
-- texture), Montserrat Heavy text with tinted outlines and a 2px extrusion, dark glass windows with coloured stud
-- headers and tilted overflowing icons. Built from the Stud-UI-Clean-Roblox design rules. Backup of the previous
-- version: ServerStorage.UIBackup_BeforeStudUI.HudController
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local PassPerks = require(ReplicatedStorage.Shared.PassPerks)
local SettingsData = require(ReplicatedStorage.Shared.SettingsData)
local Format = require(ReplicatedStorage.Shared.Format)
local Assets = require(ReplicatedStorage.Shared.UIAssets)
local Sfx = require(script.Parent.Sfx)
local EggIcon = require(script.Parent.EggIcon)
local Hatch = require(script.Parent.HatchController)
local PetData = require(ReplicatedStorage.Shared.PetData)
local EnchantConfig = require(ReplicatedStorage.Shared.EnchantConfig)

local player = Players.LocalPlayer
local Hud = {}

-- ------------------------------------------------------------ tokens
local MONT = "rbxasset://fonts/families/Montserrat.json"
local FACE = Font.new(MONT, Enum.FontWeight.Heavy)
local FACE_BOLD = Font.new(MONT, Enum.FontWeight.Bold)
local TEX = Assets.StudTile or ""
local OUT = Color3.fromRGB(6, 10, 30)          -- near-black navy outline
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SOFT = Color3.fromRGB(222, 232, 250)
local NAVY = Color3.fromRGB(14, 26, 62)
local PANEL = Color3.fromRGB(13, 61, 147)       -- royal navy inner panel (vacuum cards)
local PANEL_INK = Color3.fromRGB(6, 22, 63)
local GLASS = Color3.fromRGB(4, 8, 22)
local GOLD = Color3.fromRGB(255, 210, 63)
local MINT = Color3.fromRGB(125, 255, 106)
local CARD_T, CARD_B = Color3.fromRGB(30, 50, 104), Color3.fromRGB(16, 28, 64)
local STUD_T = 0.55                              -- cube-stud texture strength (higher = subtler); the square tile itself is faint

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
-- theme = { [1] = face colour, [2] = lip colour, hi, lo, bd (outline / text-stroke tint) }
local function th(hi, base, lo, lip, bd) return { base, lip, hi = hi, lo = lo, bd = bd } end
local C = {
	green = th(rgb(214, 255, 92), rgb(127, 224, 42), rgb(79, 191, 22), rgb(47, 138, 12), rgb(22, 61, 5)),
	blue = th(rgb(143, 228, 255), rgb(47, 168, 255), rgb(20, 120, 230), rgb(11, 79, 174), rgb(5, 35, 79)),
	red = th(rgb(255, 138, 138), rgb(255, 59, 72), rgb(216, 31, 49), rgb(149, 16, 36), rgb(61, 4, 16)),
	purple = th(rgb(230, 166, 255), rgb(180, 77, 255), rgb(138, 36, 230), rgb(92, 16, 168), rgb(36, 5, 63)),
	yellow = th(rgb(255, 242, 138), rgb(255, 201, 40), rgb(255, 157, 10), rgb(194, 106, 0), rgb(74, 36, 0)),
	orange = th(rgb(255, 191, 106), rgb(255, 138, 31), rgb(232, 101, 10), rgb(168, 67, 0), rgb(61, 22, 0)),
	pink = th(rgb(255, 154, 214), rgb(255, 63, 164), rgb(216, 31, 127), rgb(154, 19, 88), rgb(61, 4, 32)),
	grey = th(rgb(219, 232, 245), rgb(169, 191, 214), rgb(138, 163, 191), rgb(95, 122, 152), rgb(29, 44, 64)),
}
C.lime = C.green
-- any colour -> a full stud theme
local function themeOf(col: Color3)
	return th(col:Lerp(WHITE, 0.45), col, col:Lerp(BLACK, 0.12), col:Lerp(BLACK, 0.42), col:Lerp(BLACK, 0.82))
end
local function T(pal) if pal.bd then return pal end return themeOf(pal[1]) end

-- ------------------------------------------------------------ helpers
local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = p; return c end
local function stroke(p, t, col, border)
	local s = Instance.new("UIStroke"); s.Thickness = t; s.Color = col or OUT; s.LineJoinMode = Enum.LineJoinMode.Round
	if border then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	s.Parent = p; return s
end
local function grad(p, a, b, rot) local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(a, b); g.Rotation = rot or 90; g.Parent = p; return g end
local function frame(parent, size, pos, color, name)
	local f = Instance.new("Frame"); f.Name = name or "Frame"; f.Size = size; f.Position = pos
	f.BackgroundColor3 = color or WHITE; f.BackgroundTransparency = color and 0 or 1; f.BorderSizePixel = 0; f.Parent = parent
	return f
end
-- every label: Montserrat Heavy, scaled + capped, padded, tinted outline, optional 2px extrusion (dark copy below)
local function label(parent, str, size, pos, color, o)
	o = o or {}
	local function make()
		local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = size; t.Position = pos
		t.FontFace = o.bold and FACE_BOLD or FACE; t.Text = str; t.RichText = o.rich or false
		t.TextWrapped = o.wrap or false
		t.TextScaled = true -- must come after TextWrapped
		t.TextXAlignment = o.align or Enum.TextXAlignment.Center; t.TextYAlignment = o.valign or Enum.TextYAlignment.Center
		local c = Instance.new("UITextSizeConstraint"); c.MaxTextSize = o.max or 40; c.MinTextSize = 8; c.Parent = t
		local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0, o.padX or 4); p.PaddingRight = UDim.new(0, o.padX or 4)
		p.PaddingTop = UDim.new(0, o.padY or 2); p.PaddingBottom = UDim.new(0, o.padY or 2); p.Parent = t
		return t
	end
	color = color or WHITE
	-- dark text from the old light-panel style becomes soft white with an outline (all panels are dark now)
	if (color.R * 0.3 + color.G * 0.59 + color.B * 0.11) < 0.5 then color = SOFT; if (o.stroke or 2.5) == 0 then o.stroke = 2 end end
	local sw = o.stroke or 2.5
	local sc = o.strokeColor or OUT
	local t = make(); t.TextColor3 = color; t.ZIndex = o.z or 4
	if sw > 0 then stroke(t, sw, sc) end
	if o.extrude then
		local sh = make(); sh.Name = "Shadow"; sh.TextColor3 = sc; sh.ZIndex = (o.z or 4) - 1
		sh.Position = pos + UDim2.fromOffset(0, o.extrude == true and 2 or o.extrude)
		if sw > 0 then stroke(sh, sw, sc) end
		local dy = o.extrude == true and 2 or o.extrude
		t:GetPropertyChangedSignal("Text"):Connect(function() sh.Text = t.Text end)
		t:GetPropertyChangedSignal("Position"):Connect(function() sh.Position = t.Position + UDim2.fromOffset(0, dy) end)
		t:GetPropertyChangedSignal("Size"):Connect(function() sh.Size = t.Size end)
		t:GetPropertyChangedSignal("Visible"):Connect(function() sh.Visible = t.Visible end)
		t:GetPropertyChangedSignal("TextXAlignment"):Connect(function() sh.TextXAlignment = t.TextXAlignment end)
		t.Destroying:Connect(function() sh:Destroy() end)
		sh.Parent = parent
		t.AncestryChanged:Connect(function() if t.Parent and sh.Parent ~= t.Parent then sh.Parent = t.Parent end end)
		t.Parent = parent
		t.Name = "Text"
		-- keep a direct handle so paint() can retint it
		local ref = Instance.new("ObjectValue"); ref.Name = "ShadowRef"; ref.Value = sh; ref.Parent = t
		return t
	end
	t.Parent = parent
	return t
end
local function setStrokeTint(lbl, col)
	if not lbl then return end
	local s = lbl:FindFirstChildOfClass("UIStroke"); if s then s.Color = col end
	local ref = lbl:FindFirstChild("ShadowRef")
	local sh = ref and ref.Value
	if sh then sh.TextColor3 = col; local s2 = sh:FindFirstChildOfClass("UIStroke"); if s2 then s2.Color = col end end
end
local function texture(f, tile, transp, z)
	local t = Instance.new("ImageLabel"); t.Name = "Tex"; t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Image = TEX
	t.ScaleType = Enum.ScaleType.Tile; t.TileSize = UDim2.fromOffset(tile or 30, tile or 30); t.ImageTransparency = transp or STUD_T
	t.ZIndex = z or f.ZIndex; t.Parent = f
	return t
end
-- 3D stud skin: hi→base→lo gradient, subtle cube-stud texture, two diagonal glass streaks, light inner bevel
local function skin(f, base, o)
	o = o or {}
	local r = o.radius or 8
	for _, n in ipairs({ "SkinGrad", "Tex", "Gloss", "Inner", "Reflets" }) do local x = f:FindFirstChild(n); if x then x:Destroy() end end
	f.BackgroundColor3 = WHITE
	local hi = o.top or base:Lerp(WHITE, 0.45)
	local lo = o.bottom or base:Lerp(BLACK, 0.12)
	local g = Instance.new("UIGradient"); g.Name = "SkinGrad"; g.Rotation = 90
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hi), ColorSequenceKeypoint.new(0.55, base), ColorSequenceKeypoint.new(1, lo) }); g.Parent = f
	local tx = texture(f, o.tile or 30, math.max(o.texT or STUD_T, 0.5)); corner(tx, r)
	if not o.noGloss then
		local rf = Instance.new("Frame"); rf.Name = "Reflets"; rf.BorderSizePixel = 0; rf.BackgroundColor3 = WHITE; rf.Size = UDim2.fromScale(1, 1)
		rf.ZIndex = f.ZIndex; rf.Parent = f; corner(rf, r)
		local gg = Instance.new("UIGradient"); gg.Rotation = 28
		gg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 1), NumberSequenceKeypoint.new(0.201, 0.64),
			NumberSequenceKeypoint.new(0.29, 0.64), NumberSequenceKeypoint.new(0.291, 1), NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(0.351, 0.8), NumberSequenceKeypoint.new(0.4, 0.8), NumberSequenceKeypoint.new(0.401, 1),
			NumberSequenceKeypoint.new(1, 1),
		}); gg.Parent = rf
	end
	local inner = Instance.new("Frame"); inner.Name = "Inner"; inner.BackgroundTransparency = 1; inner.Size = UDim2.new(1, -6, 1, -6); inner.Position = UDim2.fromOffset(3, 3)
	inner.ZIndex = f.ZIndex; inner.Parent = f; corner(inner, math.max(r - 3, 2))
	local s = stroke(inner, o.innerW or 1.5, o.innerC or base:Lerp(WHITE, 0.75), true); s.Transparency = o.innerT or 0.25
	return f
end
-- dark navy surface (cards, wells)
local function darkSkin(f, o)
	o = o or {}
	return skin(f, CARD_B, { top = o.top or CARD_T, bottom = o.bottom or CARD_B, texT = 0.75, noGloss = true, innerC = WHITE, innerT = 0.78, innerW = o.innerW or 2, radius = o.radius, tile = 30 })
end
-- translucent dark glass (windows, HUD bars) with the thin white second frame
local function glass(f, r, o)
	o = o or {}
	f.BackgroundColor3 = GLASS; f.BackgroundTransparency = o.t or 0.42
	corner(f, r or 10); stroke(f, o.w or 3.5, OUT, true)
	local inner = Instance.new("Frame"); inner.Name = "Inner"; inner.BackgroundTransparency = 1; inner.Size = UDim2.new(1, -8, 1, -8); inner.Position = UDim2.fromOffset(4, 4)
	inner.Parent = f; corner(inner, math.max((r or 10) - 3, 2))
	local s = stroke(inner, 1.5, WHITE, true); s.Transparency = o.innerT or 0.65
	return f
end
local function glowBehind() end -- the stud style has no soft glows
-- solid darker "lip" under a brick (a sibling drawn first so it sits behind)
local function lip(parent, size, pos, color, r, drop, bd)
	local l = frame(parent, size, pos + UDim2.fromOffset(0, drop or 5), color, "Lip"); corner(l, r or 8); stroke(l, 3.5, bd or OUT, true)
	return l
end
local function icon(parent, key, size, pos)
	local i = Instance.new("ImageLabel"); i.BackgroundTransparency = 1; i.Size = size; i.Position = pos
	i.Image = Assets[key] or ""; i.ScaleType = Enum.ScaleType.Fit; i.Name = key .. "Icon"; i.ZIndex = 5; i.Parent = parent
	return i
end
-- sticker icon: tilted, overflowing
local function sticker(parent, key, px, x, y, rot)
	local i = icon(parent, key, UDim2.fromOffset(px, px), UDim2.fromOffset(x, y)); i.Rotation = rot or -10
	return i
end
-- icons tagged "VacIcon" always show the vacuum the player has equipped
local function vacKey() return "Vac" .. tostring(player:GetAttribute("Vacuum") or 1) end
local function tagVac(img) img:SetAttribute("VacIcon", true); img.Image = Assets[vacKey()] or Assets.Vac1 or ""; return img end
local function refreshVacIcons(root)
	if not root then return end
	local img = Assets[vacKey()] or Assets.Vac1 or ""
	for _, d in ipairs(root:GetDescendants()) do
		if d:GetAttribute("VacIcon") and d:IsA("ImageLabel") then d.Image = img end
	end
end
-- chunky 3D stud button. Returns the clickable face (TextButton); Label / Icon children can be changed later.
local function button(parent, str, size, pos, pal, o)
	o = o or {}
	pal = T(pal)
	local holder = frame(parent, size, pos, nil, o.name or "Button")
	local r = o.radius or 8
	local sc = Instance.new("UIScale"); sc.Parent = holder
	local base = frame(holder, UDim2.new(1, 0, 1, 0), UDim2.fromOffset(0, 5), pal[2], "Base"); corner(base, r); stroke(base, 3, pal.bd, true)
	local b = Instance.new("TextButton"); b.Name = "Face"; b.Size = UDim2.new(1, 0, 1, 0); b.BackgroundColor3 = pal[1]
	b.AutoButtonColor = false; b.Text = ""; b.Parent = holder
	corner(b, r); stroke(b, 3, pal.bd, true)
	skin(b, pal[1], { radius = r, top = pal.hi, bottom = pal.lo, tile = o.tile or 26 })
	local left = 6
	if o.icon then
		local s = o.iconSize or 0.86
		local ic = icon(b, o.icon, UDim2.new(s, 0, s, 0), UDim2.new(0, 4, (1 - s) / 2, 0))
		local ar = Instance.new("UIAspectRatioConstraint"); ar.Parent = ic
		ic.Name = "Icon"; ic.ZIndex = 2; ic.Rotation = o.iconRot or -8
		left = o.iconPad or 46
	end
	local t = label(b, str, UDim2.new(1, -(left + 6), 1, -8), UDim2.fromOffset(left, 2), WHITE,
		{ max = o.max or 30, stroke = o.stroke or 3, strokeColor = pal.bd, extrude = true })
	t.Name = "Label"
	b.MouseEnter:Connect(function() TweenService:Create(sc, TweenInfo.new(0.1), { Scale = o.hover or 1.05 }):Play() end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.05), { Position = UDim2.fromOffset(0, 4) }):Play()
		TweenService:Create(sc, TweenInfo.new(0.05), { Scale = 0.94 }):Play()
	end)
	local function up()
		TweenService:Create(b, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(0, 0) }):Play()
		TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(up); b.MouseLeave:Connect(up)
	b.Activated:Connect(function() Sfx.play("Click", 1, 0.4) end)
	return b
end
local function paint(b, pal)
	pal = T(pal)
	local g = b:FindFirstChild("SkinGrad")
	if g then
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, pal.hi), ColorSequenceKeypoint.new(0.55, pal[1]), ColorSequenceKeypoint.new(1, pal.lo) })
	else b.BackgroundColor3 = pal[1] end
	local inner = b:FindFirstChild("Inner"); local s = inner and inner:FindFirstChildOfClass("UIStroke"); if s then s.Color = pal[1]:Lerp(WHITE, 0.75) end
	local fs = b:FindFirstChildOfClass("UIStroke"); if fs then fs.Color = pal.bd end
	local holder = b.Parent
	local base = holder and holder:FindFirstChild("Base")
	if base then base.BackgroundColor3 = pal[2]; local bs = base:FindFirstChildOfClass("UIStroke"); if bs then bs.Color = pal.bd end end
	setStrokeTint(b:FindFirstChild("Label"), pal.bd)
end
-- small dark rounded pill (timers, counters) — supports rich text
local function pill(parent, text, size, pos)
	local p = frame(parent, size, pos, rgb(10, 15, 38), "Pill"); p.AnchorPoint = Vector2.new(0.5, 0.5); p.ZIndex = 6
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = p
	stroke(p, 3, BLACK, true)
	local l = label(p, text, UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 19, stroke = 0, rich = true, padX = 14, z = 7 })
	return p, l
end
-- 3D item icon from the real item model
local function itemView(parent, key, size, pos)
	local vp = Instance.new("ViewportFrame"); vp.BackgroundTransparency = 1; vp.Size = size; vp.Position = pos
	vp.Ambient = Color3.fromRGB(190, 190, 200); vp.LightColor = WHITE; vp.LightDirection = Vector3.new(-1, -1.4, -0.6); vp.Parent = parent
	local z, r = string.match(key, "^(%d+)_(%d+)$")
	local folder = ReplicatedStorage:FindFirstChild("ItemIcons") and ReplicatedStorage.ItemIcons:FindFirstChild("Zone" .. tostring(z))
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:GetAttribute("Index") == tonumber(r) then
				local c = m:Clone(); c.Parent = vp
				local cf, sz = c:GetBoundingBox()
				local cam = Instance.new("Camera"); cam.FieldOfView = 30; cam.Parent = vp
				cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.75, -1.2).Unit * sz.Magnitude * 1.9, cf.Position)
				vp.CurrentCamera = cam
				break
			end
		end
	end
	return vp
end
local function itemInfo(key)
	local z, r = string.match(key, "^(%d+)_(%d+)$")
	z, r = tonumber(z), tonumber(r)
	local zc = z and Config.Zones[z]
	local name = zc and zc.Objects[r] or "Item"
	local rar = r and Config.Rarities[r]
	return name, rar and rar.Name or "", rar and rar.Color or WHITE, z or 0, r or 0
end

-- ------------------------------------------------------------ state
local gui, scaleObj
local coinLabel, gemLabel
local coinShown, coinTarget = 0, 0
local powerShown, powerTarget = 0, 0
local powerLabel, powerFill, powerNext
local powerTitle, rebirthBadge
local bagFill, bagText
local trackName, trackFill, trackText
local toastHolder, popLayer, sellHolder, holdHint
local gatePanel, gateTitle, gateCost, gateZone = nil, nil, nil, 0
local shopRoot = nil
local shopKind = nil
local shopAnchor = nil
local booths = {} -- { kind, anchor (NPC root part), inside }
local BOOTH_OPEN = 16 -- studs from the NPC where its menu pops up (it closes again past 26); booths are 34 studs apart
local refreshShop = nil
local vacuumedOnce = false
Hud.VacuumButton = nil :: TextButton?

local function a(name, default)
	local v = player:GetAttribute(name)
	if v == nil then return default end
	return v
end
local function owned(id)
	for s in string.gmatch(a("OwnedVacuums", "1"), "%d+") do if tonumber(s) == id then return true end end
	return false
end
local function lootItems()
	local ok, t = pcall(function() return HttpService:JSONDecode(a("LootItems", "{}")) end)
	local list = {}
	if ok and type(t) == "table" then
		for k, n in pairs(t) do if n > 0 then table.insert(list, { key = k, count = n }) end end
	end
	table.sort(list, function(x, y)
		local _, _, _, zx, rx = itemInfo(x.key); local _, _, _, zy, ry = itemInfo(y.key)
		if zx ~= zy then return zx > zy end
		return rx > ry
	end)
	return list
end

-- teleports
local function charOk()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return char ~= nil and hum ~= nil and hum.Health > 0, char
end
local function teleport(cf)
	local ok, char = charOk()
	if not ok then return end
	char:PivotTo(cf)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
	-- swing the camera round behind the character so it faces where they're looking (e.g. the NPC)
	local cam = workspace.CurrentCamera
	if cam then
		local look = cf.LookVector
		cam.CFrame = CFrame.lookAt(cf.Position - look * 13 + Vector3.new(0, 6, 0), cf.Position + look * 3)
	end
end
local function toBooth(name)
	local plaza = workspace:FindFirstChild("Plaza")
	local booth = plaza and plaza:FindFirstChild("Shops") and plaza.Shops:FindFirstChild(name)
	local npc = booth and booth:FindFirstChildWhichIsA("Model")
	if not npc then return end
	local np = npc:GetPivot().Position
	local y = (booth.PrimaryPart and booth.PrimaryPart.Position.Y or 0) + 3.5
	teleport(CFrame.lookAt(Vector3.new(np.X, y, np.Z - 8), Vector3.new(np.X, y, np.Z)))
end

-- ------------------------------------------------------------ refreshers
local function refreshPower()
	local p = powerShown
	local nextC
	for _, c in ipairs(Config.Crystals) do if c.Req > a("Power", 1) then nextC = c; break end end
	powerLabel.Text = Format.short(p)
	-- bottom bar: progress to the next LEVEL (levels come from Vacuum Power)
	local lv = Config.LevelFromPower(p)
	if powerTitle then powerTitle.Text = "Level " .. lv end
	if lv < Config.Levels.Max then
		local lo, hi = Config.LevelPower(lv), Config.LevelPower(lv + 1)
		powerFill.Size = UDim2.fromScale(math.clamp((p - lo) / math.max(1, hi - lo), 0.03, 1), 1)
		powerNext.Text = Format.short(p) .. " / " .. Format.short(hi)
	else
		powerFill.Size = UDim2.fromScale(1, 1); powerNext.Text = "MAX"
	end
end
local function refreshBag()
	local n, cap = a("LootCount", 0), a("Capacity", Config.Capacity(1))
	local f = math.clamp(n / math.max(cap, 1), 0, 1)
	TweenService:Create(bagFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(math.max(f, 0.03), 1) }):Play()
	local full = n >= cap
	bagFill.BackgroundColor3 = full and Color3.fromRGB(255, 120, 120) or WHITE
	bagText.Text = Format.short(n) .. " / " .. Format.short(cap)
	if full and not sellHolder.Visible then
		sellHolder.Visible = true
		sellHolder.Position = UDim2.new(0.5, -120, 0, 20)
		TweenService:Create(sellHolder, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, -120, 0, 78) }):Play()
	elseif not full then
		sellHolder.Visible = false
	end
end
local function refreshTrack()
	if not trackName then return end -- Next Area tracker removed from the HUD
	local z = a("ZoneUnlocked", 1)
	local nz = Config.Zones[z + 1]
	if not nz then trackName.Text = "All areas unlocked!"; trackFill.Size = UDim2.fromScale(1, 1); trackText.Text = "MAX"; return end
	local coins = a("Coins", 0)
	trackName.Text = nz.Name
	trackFill.Size = UDim2.fromScale(math.clamp(coins / nz.Cost, 0.03, 1), 1)
	trackText.Text = Format.short(math.min(coins, nz.Cost)) .. " / " .. Format.short(nz.Cost)
end

function Hud.toast(msg, kind)
	do return end -- all toast pop-ups are switched off (Oct 2026). Delete this line to bring them back.
	local accent = C.blue
	if kind == "Mythical" then accent = C.pink elseif kind == "Sell" then accent = C.green
	elseif kind == "Bad" then accent = C.red elseif kind == "Spin" then accent = C.purple elseif kind == "Unlock" then accent = C.yellow end
	local t = frame(toastHolder, UDim2.new(1, 0, 0, 46), UDim2.new(), nil, "Toast")
	glass(t, 10, { t = 0.3, w = 3 }); t.ClipsDescendants = true
	local bar = frame(t, UDim2.fromOffset(28, 28), UDim2.new(0, 9, 0.5, -14), accent[1], "Accent"); corner(bar, 6); stroke(bar, 2.5, accent.bd, true)
	skin(bar, accent[1], { radius = 6, top = accent.hi, bottom = accent.lo, tile = 14, noGloss = true })
	label(t, msg, UDim2.new(1, -52, 1, -8), UDim2.fromOffset(44, 4), WHITE, { max = 22, stroke = 2.5 })
	t.Size = UDim2.new(1, 0, 0, 0)
	TweenService:Create(t, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 0, 46) }):Play()
	task.delay(3.2, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.25), { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0) })
		tw:Play(); tw.Completed:Wait(); t:Destroy()
	end)
end
local function bumpIcon(name)
	local i = gui:FindFirstChild(name, true)
	if not i then return end
	local base = i:GetAttribute("BaseSize") or i.Size
	i:SetAttribute("BaseSize", base)
	i.Size = base + UDim2.fromOffset(10, 10)
	TweenService:Create(i, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = base }):Play()
end
function Hud.bump() bumpIcon("CoinHud") end
function Hud.bumpBag() bumpIcon("BagHud") end
function Hud.bumpPower()
	bumpIcon("PowerHud")
	if not vacuumedOnce and holdHint and not UserInputService.TouchEnabled then
		vacuumedOnce = true
		TweenService:Create(holdHint, TweenInfo.new(0.4), { Position = holdHint.Position + UDim2.fromOffset(0, 220) }):Play()
	end
end
-- "+123" with the equipped vacuum's icon, rising from the Vacuum Power counter (gains within 0.15s are summed)
local lastPower = 0
local pendingGain, gainQueued = 0, false
local function showGain(amount)
	local holder = gui and gui:FindFirstChild("Currencies") and gui.Currencies:FindFirstChild("Power")
	if not holder then return end
	local p = frame(holder, UDim2.fromOffset(170, 44), UDim2.new(0.5, math.random(-24, 24), 1, 10), nil, "PowerGain")
	p.AnchorPoint = Vector2.new(0.5, 0); p.ZIndex = 20
	local ic = Instance.new("ImageLabel"); ic.Name = "Icon"; ic.BackgroundTransparency = 1; ic.ScaleType = Enum.ScaleType.Fit
	ic.Image = Assets[vacKey()] or Assets.Vac1 or ""; ic.Size = UDim2.fromOffset(50, 50); ic.Position = UDim2.fromOffset(0, -4)
	ic.Rotation = -10; ic.ZIndex = 21; ic.Parent = p
	local t = label(p, "+" .. Format.short(amount), UDim2.new(1, -46, 1, 0), UDim2.fromOffset(46, 0), MINT,
		{ max = 32, align = Enum.TextXAlignment.Left, stroke = 3, strokeColor = C.green.bd, extrude = true, z = 22 })
	local sc = Instance.new("UIScale"); sc.Scale = 0.5; sc.Parent = p
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Position = p.Position + UDim2.fromOffset(0, 34) }):Play()
	task.delay(0.55, function()
		local ti = TweenInfo.new(0.35)
		TweenService:Create(ic, ti, { ImageTransparency = 1 }):Play()
		for _, d in ipairs(p:GetDescendants()) do
			if d:IsA("TextLabel") then TweenService:Create(d, ti, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then TweenService:Create(d, ti, { Transparency = 1 }):Play() end
		end
		task.delay(0.36, function() p:Destroy() end)
	end)
end
function Hud.powerGain(amount)
	if not amount or amount <= 0 then return end
	pendingGain += amount
	if gainQueued then return end
	gainQueued = true
	task.delay(0.15, function()
		gainQueued = false
		local n = pendingGain; pendingGain = 0
		showGain(n)
	end)
end
function Hud.vacIcon() return Assets[vacKey()] or Assets.Vac1 or "" end
function Hud.popAt(screenPos, str, color)
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromOffset(130, 42)
	t.Position = UDim2.fromOffset(screenPos.X - 65 + math.random(-14, 14), screenPos.Y - 54)
	t.FontFace = FACE; t.TextSize = 34; t.Text = str; t.TextColor3 = color or Color3.fromRGB(210, 170, 255); t.Parent = popLayer
	stroke(t, 3, OUT)
	TweenService:Create(t, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Position = t.Position - UDim2.fromOffset(0, 64), TextTransparency = 1 }):Play()
	TweenService:Create(t:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.6), { Transparency = 1 }):Play()
	task.delay(0.62, function() t:Destroy() end)
end
function Hud.showGate(zone)
	if gateZone == zone and gatePanel.Visible then return end
	gateZone = zone
	local zc = Config.Zones[zone]
	gateTitle.Text = zc.Name
	gateCost.Text = Format.short(zc.Cost)
	gatePanel.Visible = true
	gatePanel.Position = UDim2.new(0.5, 0, 1.3, 0)
	TweenService:Create(gatePanel, TweenInfo.new(0.28, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0.5, -20) }):Play()
end
function Hud.hideGate() gatePanel.Visible = false; gateZone = 0 end


-- ------------------------------------------------------------ panels
local blur, blurTween
local closingPanel, panelTween
local function setBlur(on)
	if not blur or not blur.Parent then
		blur = Lighting:FindFirstChild("MenuBlur") or Instance.new("BlurEffect")
		blur.Name = "MenuBlur"; blur.Size = 0; blur.Parent = Lighting
	end
	if blurTween then blurTween:Cancel(); blurTween = nil end
	local target = on and 14 or 0
	if math.abs(blur.Size - target) < 0.01 then blur.Size = target; return end
	blurTween = TweenService:Create(blur, TweenInfo.new(on and 0.14 or 0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = target })
	blurTween:Play()
end

local function cancelPanelAnimation()
	local previous = panelTween
	panelTween = nil
	if previous then previous:Cancel() end
	if closingPanel then local old = closingPanel; closingPanel = nil; old:Destroy() end
end
local function closeShop(immediate)
	-- A replacement retires the old panel before constructing the next one.
	-- Explicit closes keep a short settle animation, cancelled by any new open.
	immediate = immediate == true
	cancelPanelAnimation()
	local root = shopRoot
	shopRoot = nil
	shopKind = nil; shopAnchor = nil; refreshShop = nil
	if not root then
		if not immediate then setBlur(false) end
		return
	end
	if immediate then
		root:Destroy()
		return
	end
	setBlur(false)
	local scale = root:FindFirstChild("OpenScale")
	if not scale then root:Destroy(); return end
	for _, child in ipairs(root:GetDescendants()) do
		if child:IsA("GuiButton") then child.Interactable = false end
	end
	closingPanel = root
	local tween = TweenService:Create(scale, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.97 })
	panelTween = tween
	local connection
	connection = tween.Completed:Connect(function()
		connection:Disconnect()
		if closingPanel == root then closingPanel = nil; root:Destroy() end
		if panelTween == tween then panelTween = nil end
	end)
	tween:Play()
end
Hud.closeShop = closeShop

local HEAD_H = 74
-- dark glass window with a coloured stud header, an overflowing tilted icon, a heavy title and a red X.
-- tabs = { {name, iconKey, pal} } (optional). Returns content frame + tab buttons.
local function openPanel(title, iconKey, w, h, tabs, pal)
	closeShop(true)
	pal = T(pal or C.blue)
	-- fit between the currency bars (top) and the backpack / crystal bars (bottom)
	local vh = gui.AbsoluteSize.Y / math.max(scaleObj.Scale, 0.01)
	h = math.min(h, math.max(360, vh - 200))
	local root = frame(gui, UDim2.fromOffset(w, h), UDim2.new(0.5, 0, 0.5, -12), nil, "Panel")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	shopRoot = root
	setBlur(true)
	local face = frame(root, UDim2.fromScale(1, 1), UDim2.new(), nil, "Face")
	glass(face, 10, { w = 4.5, innerT = 0.62 })
	face.Inner.Size = UDim2.new(1, -10, 1, -HEAD_H - 6); face.Inner.Position = UDim2.fromOffset(5, HEAD_H + 1)
	-- header
	local head = frame(face, UDim2.new(1, 0, 0, HEAD_H), UDim2.new(), pal[1], "Header"); corner(head, 10); stroke(head, 4.5, OUT, true)
	skin(head, pal[1], { radius = 10, top = pal.hi, bottom = pal.lo, tile = 30, innerC = WHITE, innerT = 0.5 })
	local shade = frame(head, UDim2.new(1, -6, 0, 6), UDim2.new(0, 3, 1, -7), BLACK, "Shade"); shade.BackgroundTransparency = 0.82; shade.ZIndex = 2
	local hi = sticker(head, iconKey, 108, -30, -34, -10); hi.ZIndex = 8; hi.Name = "HeaderIcon"
	label(head, title, UDim2.new(1, -170, 1, -12), UDim2.fromOffset(84, 4), WHITE,
		{ max = 46, align = Enum.TextXAlignment.Left, stroke = 4.5, strokeColor = pal.bd, extrude = 3 })
	local close = button(head, "X", UDim2.fromOffset(56, 52), UDim2.new(1, -66, 0, 8), C.red, { max = 34, name = "Close", stroke = 3.5 })
	close.Activated:Connect(closeShop)
	-- content area
	local inner = frame(face, UDim2.new(1, -28, 1, -(HEAD_H + 24)), UDim2.fromOffset(14, HEAD_H + 12), nil, "Body")
	local content
	local tabButtons = {}
	if tabs and #tabs > 1 then
		local col = frame(inner, UDim2.new(0, 170, 1, -20), UDim2.fromOffset(6, 12), nil, "Tabs")
		local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 12); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = col
		for i, t in ipairs(tabs) do
			local holder = frame(col, UDim2.new(1, 0, 0, 58), UDim2.new(), nil, "Tab" .. i); holder.LayoutOrder = i
			local b = button(holder, t[1], UDim2.new(1, 0, 1, -6), UDim2.new(), i == 1 and C.yellow or (t[3] or C.blue), { icon = t[2], max = 22, iconPad = 50 })
			tabButtons[i] = b
		end
		content = frame(inner, UDim2.new(1, -196, 1, -16), UDim2.fromOffset(190, 12), nil, "Content")
	else
		content = frame(inner, UDim2.new(1, -12, 1, -16), UDim2.fromOffset(6, 12), nil, "Content")
	end
	-- A short ease-out settles the new menu without overshooting or showing its predecessor.
	local sc = Instance.new("UIScale"); sc.Name = "OpenScale"; sc.Scale = 0.97; sc.Parent = root
	panelTween = TweenService:Create(sc, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
	panelTween:Play()
	Sfx.play("Click", 0.8, 0.35)
	return content, tabButtons, root
end
local function selectTab(tabButtons, tabs, idx)
	for i, b in ipairs(tabButtons) do paint(b, i == idx and C.yellow or (tabs[i][3] or C.blue)) end
end
local function styleScroll(s)
	s.ScrollBarThickness = 8; s.ScrollBarImageColor3 = WHITE; s.ScrollBarImageTransparency = 0.25
	s.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"; s.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
end
local function scroller(parent, cell, cols, padTop)
	local s = Instance.new("ScrollingFrame"); s.Size = UDim2.fromScale(1, 1); s.BackgroundTransparency = 1; s.BorderSizePixel = 0
	styleScroll(s); s.AutomaticCanvasSize = Enum.AutomaticSize.Y; s.CanvasSize = UDim2.new()
	s.Parent = parent
	local gl = Instance.new("UIGridLayout"); gl.CellSize = UDim2.new(1 / cols, -12, 0, cell); gl.CellPadding = UDim2.fromOffset(10, 12)
	gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = s
	local p = Instance.new("UIPadding"); p.PaddingTop = UDim.new(0, padTop or 6); p.PaddingLeft = UDim.new(0, 4); p.PaddingRight = UDim.new(0, 14); p.PaddingBottom = UDim.new(0, 10); p.Parent = s
	return s
end
local function card(parent, order)
	local c = frame(parent, UDim2.new(), UDim2.new(), WHITE, "Card"); c.LayoutOrder = order or 0
	corner(c, 12); stroke(c, 3.5, OUT, true); darkSkin(c, { radius = 12 })
	return c
end
-- Keep the original rarity/skin border when a different inventory card is selected.
local function inventorySelect(c, selected)
	local s = c:FindFirstChildOfClass("UIStroke")
	if not s then return end
	if s:GetAttribute("InventoryColor") == nil then
		s:SetAttribute("InventoryColor", s.Color); s:SetAttribute("InventoryThickness", s.Thickness)
	end
	s.Color = selected and WHITE or s:GetAttribute("InventoryColor")
	s.Thickness = selected and 4.5 or s:GetAttribute("InventoryThickness")
	c:SetAttribute("InventorySelected", selected)
end
local function priceButton(parent, size, pos)
	return button(parent, "0", size, pos, C.green, { icon = "Coin", max = 26, iconPad = 44 })
end
-- iconKey: "Coin" (default) or "Lock"
local function setPrice(b, text, pal, showIcon, iconKey)
	local lbl = b:FindFirstChild("Label")
	lbl.Text = text
	local ic = b:FindFirstChild("Icon")
	if ic then ic.Visible = showIcon; if showIcon then ic.Image = Assets[iconKey or "Coin"] or "" end end
	lbl.Position = UDim2.fromOffset(showIcon and 44 or 6, 2); lbl.Size = UDim2.new(1, showIcon and -50 or -12, 1, -8)
	paint(b, pal)
end

-- VACUUM SHOP — one column of vacuum cards you scroll down (like the approved mockup)
local function vacTheme(v)
	local h, s, val = v.Color:ToHSV()
	return themeOf(Color3.fromHSV(h, math.max(s, 0.6), math.max(val, 0.85)))
end
local function buildVacuumShop()
	local content, _, root = openPanel("Vacuums", "Shop", 600, 700, nil, C.blue)
	local _, ownedText = pill(root, "", UDim2.fromOffset(170, 34), UDim2.fromOffset(300, HEAD_H + 2))
	local list = Instance.new("ScrollingFrame"); list.Name = "List"; list.Size = UDim2.fromScale(1, 1); list.BackgroundTransparency = 1
	list.BorderSizePixel = 0; styleScroll(list); list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.CanvasSize = UDim2.new(); list.Parent = content
	local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 14); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = list
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 12); pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 16); pad.Parent = list
	local cells = {}
	for i, v in ipairs(Config.Vacuums) do
		local vt = vacTheme(v)
		local holder = frame(list, UDim2.new(1, 0, 0, 186), UDim2.new(), nil, "Vac" .. i); holder.LayoutOrder = i
		local c = frame(holder, UDim2.new(1, 0, 1, -6), UDim2.new(), vt[1], "Card")
		lip(holder, UDim2.new(1, 0, 1, -6), UDim2.new(), vt[2], 14, 5, OUT)
		c.Parent = nil; c.Parent = holder -- draw the card above its lip
		corner(c, 14); stroke(c, 4, OUT, true)
		skin(c, vt[1], { radius = 14, top = vt.hi, bottom = vt.lo, tile = 30, innerC = WHITE, innerT = 0.45 })
		label(c, v.Name, UDim2.new(1, -24, 0, 38), UDim2.fromOffset(12, 3), WHITE,
			{ max = 30, align = Enum.TextXAlignment.Left, stroke = 4, strokeColor = vt.bd, extrude = true })
		local panel = frame(c, UDim2.new(1, -20, 1, -54), UDim2.fromOffset(10, 44), PANEL, "Panel"); panel.ZIndex = 2
		corner(panel, 10); local ps = stroke(panel, 3, BLACK, true); ps.Transparency = 0.5
		local ptex = texture(panel, 30, 0.9, 2); corner(ptex, 10)
		local topShade = frame(panel, UDim2.new(1, 0, 0, 6), UDim2.new(), BLACK, "TopShade"); topShade.BackgroundTransparency = 0.75; topShade.ZIndex = 2; corner(topShade, 10)
		local img = Instance.new("ImageLabel"); img.Name = "VacImage"; img.BackgroundTransparency = 1; img.ScaleType = Enum.ScaleType.Fit
		img.Image = Assets["Vac" .. v.Id] or Assets.Vacuum or ""; img.Size = UDim2.new(0, 196, 1, 26); img.Position = UDim2.fromOffset(-6, -13)
		img.Rotation = -6; img.ZIndex = 5; img.Parent = panel
		label(panel, "x" .. v.PowerMult .. " Power", UDim2.new(1, -196, 0, 28), UDim2.fromOffset(184, 6), WHITE,
			{ max = 22, align = Enum.TextXAlignment.Left, stroke = 3, strokeColor = PANEL_INK, z = 6 })
		label(panel, string.format("Range %d  •  %.1f/s  •  %d targets", v.Range, 1 / v.Interval, v.Targets), UDim2.new(1, -196, 0, 24), UDim2.fromOffset(184, 34), SOFT,
			{ max = 18, align = Enum.TextXAlignment.Left, stroke = 2.5, strokeColor = PANEL_INK, z = 6 })
		local btn = button(panel, "0", UDim2.new(1, -196, 0, 46), UDim2.new(0, 184, 1, -58), C.green, { icon = "Coin", max = 26, iconPad = 44 })
		btn.Parent.ZIndex = 6
		btn.Activated:Connect(function()
			local was = owned(v.Id)
			if not was and v.Id > 1 and not owned(v.Id - 1) then Hud.toast("Buy the " .. Config.Vacuums[v.Id - 1].Name .. " first!", "Bad"); return end
			if was and a("Vacuum", 1) == v.Id then return end
			local remote = was and ReplicatedStorage.Remotes.EquipVacuum or ReplicatedStorage.Remotes.BuyVacuum
			local ok, res = remote:InvokeServer(v.Id)
			if ok then Sfx.play("Upgrade", 1.1, 0.6); Hud.toast((was and "Equipped " or "Bought ") .. v.Name .. "!", "Sell") end
			-- (no pop-up when the buy fails, e.g. not enough coins)
		end)
		cells[i] = { btn = btn, v = v }
	end
	refreshShop = function()
		local coins, eq = a("Coins", 0), a("Vacuum", 1)
		local n = 0
		for i, r in ipairs(cells) do
			if owned(i) then n += 1 end
			if eq == i then setPrice(r.btn, "EQUIPPED", C.blue, false)
			elseif owned(i) then setPrice(r.btn, "EQUIP", C.green, false)
			elseif i > 1 and not owned(i - 1) then setPrice(r.btn, Format.short(r.v.Price), C.grey, true, "Lock")
			else setPrice(r.btn, Format.short(r.v.Price), coins >= r.v.Price and C.green or C.grey, true, "Coin") end
		end
		ownedText.Text = string.format('Owned <font color="#FFD23F">%d / %d</font>', n, #cells)
	end
	refreshShop()
end

-- REBIRTH — coins, gems, luck and vacuum power multipliers
local rebirthArmed = 0
local function fmtMult(x) return (x == math.floor(x)) and string.format("x%.1f", x) or (string.format("x%.2f", x):gsub("0$", "")) end
local function buildRebirth()
	local content, _, root = openPanel("Rebirth", "Rebirth", 560, 610, nil, C.purple)
	local _, countText = pill(root, "", UDim2.fromOffset(210, 34), UDim2.fromOffset(280, HEAD_H + 2))
	-- Actions stay inside the panel. Only the summary scrolls on shorter viewports.
	local summary = Instance.new("ScrollingFrame")
	summary.Name = "RebirthSummary"; summary.Size = UDim2.new(1, 0, 1, -150)
	summary.BackgroundTransparency = 1; summary.BorderSizePixel = 0
	summary.ScrollingDirection = Enum.ScrollingDirection.Y; summary.AutomaticCanvasSize = Enum.AutomaticSize.Y
	summary.CanvasSize = UDim2.new(); styleScroll(summary); summary.Parent = content
	local available = root.Size.Y.Offset - HEAD_H - 40 - 150
	local rowHeight = math.clamp(math.floor((available - 134) / 4), 38, 64)
	local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 8); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = summary
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 14); pad.Parent = summary
	local actions = frame(content, UDim2.new(1, -12, 0, 140), UDim2.new(0, 6, 1, -140), nil, "RebirthActions")
	local rows = {}
	local defs = {
		{ "Coin", "Coins", "Coin", C.yellow.bd },
		{ "Gem", "Gems", "Gem", C.blue.bd },
		{ "Luck", "Luck", Assets.Luck and "Luck" or "Star", C.green.bd },
		{ "Power", "Vacuum Power", "Vac1", C.blue.bd },
	}
	for i, d in ipairs(defs) do
		local row = frame(summary, UDim2.new(1, 0, 0, rowHeight), UDim2.new(), nil, "Mult" .. d[1]); row.LayoutOrder = i
		glass(row, 10, { t = 0.45, w = 3, innerT = 0.78 })
		local iconSize = math.min(76, rowHeight + 12)
		local ic = sticker(row, d[3], iconSize, -4, (rowHeight - iconSize) / 2, -10); ic.ZIndex = 6
		if d[1] == "Power" then tagVac(ic) end
		label(row, d[2], UDim2.new(0.56, -76, 1, -10), UDim2.fromOffset(74, 5), WHITE, { max = 25, align = Enum.TextXAlignment.Left, stroke = 3, strokeColor = d[4], extrude = true })
		local val = label(row, "", UDim2.new(0.44, -14, 1, -10), UDim2.new(0.56, 0, 0, 5), SOFT, { max = 26, align = Enum.TextXAlignment.Right, stroke = 3, rich = true })
		rows[d[1]] = val
	end
	-- level progress toward the next rebirth (levels come from Vacuum Power), with a percentage
	local bar = frame(summary, UDim2.new(1, 0, 0, 38), UDim2.new(), rgb(10, 15, 38), "CostBar"); bar.LayoutOrder = 10
	corner(bar, 9); stroke(bar, 3, BLACK, true); bar.ClipsDescendants = true
	local fill = frame(bar, UDim2.fromScale(0, 1), UDim2.new(), C.green[1], "Fill"); corner(fill, 9)
	skin(fill, C.green[1], { radius = 9, top = C.green.hi, bottom = C.green.lo, tile = 22, noGloss = true })
	local barText = label(bar, "", UDim2.new(1, -24, 1, -6), UDim2.fromOffset(12, 3), WHITE, { max = 22, stroke = 3, strokeColor = C.green.bd, z = 7, rich = true })
	label(summary, "Resets power, coins, vacuums, areas & backpack.\nKeeps gems & upgrades.", UDim2.new(1, 0, 0, 30), UDim2.new(), rgb(255, 214, 214),
		{ max = 15, stroke = 2, strokeColor = C.red.bd, bold = true, wrap = true }).LayoutOrder = 11
	local holder = frame(actions, UDim2.new(1, 0, 0, 76), UDim2.new(), nil, "RebirthHolder")
	local go = button(holder, "REBIRTH", UDim2.new(1, 0, 1, -6), UDim2.new(), C.yellow, { icon = "Rebirth", max = 40, iconPad = 74, iconSize = 1.05, stroke = 4.5 })
	local goLbl = go:FindFirstChild("Label")
	goLbl.Size = UDim2.new(1, -150, 1, -8); goLbl.Position = UDim2.fromOffset(74, 2)
	-- Auto Rebirth (gamepass): on/off switch
	local autoH = frame(actions, UDim2.new(1, 0, 0, 52), UDim2.fromOffset(0, 88), nil, "AutoRebirthHolder")
	local autoB = button(autoH, "AUTO REBIRTH", UDim2.new(1, 0, 1, -6), UDim2.new(), C.grey, { max = 22 })
	autoB.Activated:Connect(function()
		if not PassPerks.Has(player, "AutoRebirth") then Hud.openShop("Store"); return end
		local new = not SettingsData.Get(player, "AutoRebirth")
		ReplicatedStorage.Remotes.SetSetting:FireServer("AutoRebirth", new)
		autoB.Label.Text = "AUTO REBIRTH: " .. (new and "ON" or "OFF"); paint(autoB, new and C.green or C.red)
	end)
	local function refreshAuto()
		if not PassPerks.Has(player, "AutoRebirth") then autoB.Label.Text = "AUTO REBIRTH (PASS)"; paint(autoB, C.grey); return end
		local on = SettingsData.Get(player, "AutoRebirth")
		autoB.Label.Text = "AUTO REBIRTH: " .. (on and "ON" or "OFF"); paint(autoB, on and C.green or C.red)
	end
	local ready = false
	go.Activated:Connect(function()
		local need = Config.RebirthLevel(a("Rebirths", 0))
		if Config.LevelFromPower(a("Power", 1)) < need then Hud.toast("Reach Level " .. need .. " to rebirth!", "Bad"); return end
		-- one tap rebirths (no confirm step)
		local ok, res = ReplicatedStorage.Remotes.Rebirth:InvokeServer()
		if ok then
			Sfx.play("Unlock", 1, 0.7)
			Hud.toast("Rebirth " .. tostring(res) .. "! Your multipliers went up!", "Unlock")
		else Hud.toast(tostring(res), "Bad") end
	end)
	refreshShop = function()
		local r = a("Rebirths", 0)
		local now, nxt = Config.RebirthMults(r), Config.RebirthMults(r + 1)
		for k, lbl in pairs(rows) do
			lbl.Text = fmtMult(now[k]) .. '  <font color="#7DFF6A">→ ' .. fmtMult(nxt[k]) .. "</font>"
		end
		countText.Text = string.format('Rebirths: <font color="#FFD23F">%d</font>  →  <font color="#FFD23F">%d</font>', r, r + 1)
		local power = a("Power", 1)
		local need, lv = Config.RebirthLevel(r), Config.LevelFromPower(power)
		ready = lv >= need
		local pct = ready and 100 or math.floor(Config.RebirthProgress(power, r) * 100)
		fill.Size = UDim2.fromScale(pct / 100, 1)
		barText.Text = string.format('Level %d / %d   <font color="#FFD23F">%d%%</font>', math.min(lv, need), need, pct) .. (ready and "  READY!" or "")
		if os.clock() - rebirthArmed > 3 then goLbl.Text = "REBIRTH" end
		paint(go, ready and C.yellow or C.grey)
		refreshAuto()
	end
	refreshShop()
end

-- UPGRADES
local UP_ICON = { Backpack = "Backpack", Walk = "Shoe", Coin = "Coins" }
local function buildUpgrades()
	local content = openPanel("Upgrades", "Arrow", 780, 450, nil, C.yellow)
	local grid = frame(content, UDim2.fromScale(1, 1), UDim2.new(), nil, "Grid")
	local gl = Instance.new("UIGridLayout"); gl.CellSize = UDim2.new(1 / 3, -10, 1, -4); gl.CellPadding = UDim2.fromOffset(14, 0)
	gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = grid
	local cards = {}
	for i, u in ipairs(Config.Upgrades) do
		local c = card(grid, i)
		label(c, u.Name, UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 8), Color3.fromRGB(30, 60, 130), { max = 26, stroke = 0 })
		icon(c, UP_ICON[u.Id] or "Arrow", UDim2.fromOffset(110, 110), UDim2.new(0.5, -55, 0, 44))
		local pill = frame(c, UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 1, -150), Color3.fromRGB(11, 16, 34), "Pill"); corner(pill, 10)
		local lv = label(pill, "Lv. 1", UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(40, 90, 180), { max = 22, stroke = 0 })
		local val = label(c, "", UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 1, -110), Color3.fromRGB(140, 255, 90), { max = 22, stroke = 2.5 })
		local buy = priceButton(c, UDim2.new(1, -24, 0, 50), UDim2.new(0, 12, 1, -64))
		buy.Activated:Connect(function()
			local ok, res = ReplicatedStorage.Remotes.BuyUpgrade:InvokeServer(u.Id)
			if ok then Sfx.play("Upgrade", 1.1, 0.6) end -- (no pop-ups for levelling, maxed or failed upgrades)
		end)
		cards[u.Id] = { lv = lv, val = val, buy = buy, u = u }
	end
	refreshShop = function()
		for id, c in pairs(cards) do
			local lv = a(id .. "Lv", 1)
			local maxed = lv >= c.u.Max
			local cur, nxt
			if id == "Backpack" then cur, nxt = Format.short(PassPerks.Capacity(player, lv)), Format.short(PassPerks.Capacity(player, lv + 1))
			elseif id == "Walk" then cur, nxt = string.format("%.1f", PassPerks.WalkSpeed(player, lv)), string.format("%.1f", PassPerks.WalkSpeed(player, lv + 1))
			else cur, nxt = string.format("x%.1f", Config.CoinMult(lv)), string.format("x%.1f", Config.CoinMult(lv + 1)) end
			c.lv.Text = maxed and ("Lv. " .. lv .. "  MAX") or ("Lv. " .. lv .. "  →  Lv. " .. (lv + 1))
			c.val.Text = maxed and cur or (cur .. "  →  " .. nxt)
			local price = Config.Price(id, lv)
			if maxed then setPrice(c.buy, "MAX", C.grey, false)
			else setPrice(c.buy, Format.short(price), a("Coins", 0) >= price and C.green or C.grey, true) end
		end
	end
	refreshShop()
end

-- item cell used by backpack + sell menus
local function itemCell(parent, entry, order, onClick)
	local c = card(parent, order)
	local name, rarName, rarCol = itemInfo(entry.key)
	skin(c, rarCol, { radius = 14 }) -- Index-style rarity tile
	itemView(c, entry.key, UDim2.new(1, -16, 1, -40), UDim2.fromOffset(8, 6))
	local badge = frame(c, UDim2.fromOffset(54, 26), UDim2.fromOffset(6, 6), NAVY, "Count"); corner(badge, 10)
	label(badge, "x" .. Format.short(entry.count), UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 18, stroke = 0 })
	local tag = frame(c, UDim2.fromOffset(12, 12), UDim2.new(1, -18, 0, 8), rarCol, "Rarity"); corner(tag, 6); stroke(tag, 2, OUT, true)
	label(c, name, UDim2.new(1, -8, 0, 30), UDim2.new(0, 4, 1, -32), Color3.fromRGB(30, 60, 130), { max = 18, stroke = 0 })
	if onClick then
		local hit = Instance.new("TextButton"); hit.BackgroundTransparency = 1; hit.Text = ""; hit.Size = UDim2.fromScale(1, 1); hit.Parent = c
		hit.Activated:Connect(function() onClick(entry, c) end)
	end
	return c
end
local function emptyNote(parent, text)
	local l = label(parent, text, UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0.4, 0), Color3.fromRGB(70, 100, 160), { max = 24, stroke = 0, wrap = true })
	return l
end

-- SELL LOOT (opened at the Sell Loot NPC)
local function buildSell()
	local content = openPanel("Sell Loot", "Coin", 820, 530, nil, C.green)
	local area = frame(content, UDim2.new(1, 0, 1, -76), UDim2.new(), nil, "Area")
	local function fill()
		for _, ch in ipairs(area:GetChildren()) do ch:Destroy() end
		local items = lootItems()
		if #items == 0 then emptyNote(area, "Your backpack is empty.\nGo vacuum some items!") return end
		local list = scroller(area, 132, 5)
		for i, e in ipairs(items) do itemCell(list, e, i) end
	end
	local bottom = frame(content, UDim2.new(1, 0, 0, 66), UDim2.new(0, 0, 1, -66), nil, "Bottom")
	local sellAll = button(bottom, "Sell All", UDim2.new(0.56, 0, 1, -6), UDim2.new(), C.green, { icon = "Coin", max = 32, iconPad = 52 })
	local totalBox = frame(bottom, UDim2.new(0.42, 0, 1, -6), UDim2.new(0.58, 0, 0, 0), CARD_B, "Total"); corner(totalBox, 12); stroke(totalBox, 4, OUT, true); darkSkin(totalBox, { radius = 12 })
	label(totalBox, "Total Value", UDim2.new(0.45, 0, 1, -8), UDim2.fromOffset(6, 4), WHITE, { max = 22, align = Enum.TextXAlignment.Left })
	icon(totalBox, "Coin", UDim2.fromOffset(36, 36), UDim2.new(0.47, 0, 0.5, -18))
	local total = label(totalBox, "0", UDim2.new(0.42, 0, 1, -8), UDim2.new(0.56, 0, 0, 4), C.yellow[1], { max = 30, align = Enum.TextXAlignment.Left })
	sellAll.Activated:Connect(function()
		local ok, res = ReplicatedStorage.Remotes.SellLoot:InvokeServer()
		if not ok then Hud.toast(tostring(res), "Bad") end
	end)
	refreshShop = function()
		fill()
		local v = a("Loot", 0) * PassPerks.CoinMultiplier(player)
		total.Text = Format.short(v)
		sellAll.Label.Text = "Sell All  +" .. Format.short(v)
		paint(sellAll, a("LootCount", 0) > 0 and C.green or C.grey)
	end
	refreshShop()
end

-- Inventory details share a title, a scrollable summary and a pinned action area.
-- Only the summary scrolls, so actions stay visible at every Backpack height.
local function inventoryDetail(parent, title, actionHeight)
	local titleLabel = label(parent, title, UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, 8), WHITE,
		{ max = 24, stroke = 3, wrap = true })
	titleLabel.Name = "DetailTitle"
	local info = Instance.new("ScrollingFrame"); info.Name = "DetailInfo"
	info.BackgroundTransparency = 1; info.BorderSizePixel = 0
	info.Position = UDim2.fromOffset(10, 50); info.Size = UDim2.new(1, -20, 1, -(actionHeight + 70))
	info.ScrollingDirection = Enum.ScrollingDirection.Y; info.AutomaticCanvasSize = Enum.AutomaticSize.Y
	info.CanvasSize = UDim2.new(); styleScroll(info); info.ScrollBarThickness = 4; info.Parent = parent
	local padding = Instance.new("UIPadding"); padding.PaddingTop = UDim.new(0, 4); padding.PaddingBottom = UDim.new(0, 4); padding.Parent = info
	local actions = frame(parent, UDim2.new(1, -20, 0, actionHeight),
		UDim2.new(0, 10, 1, -(actionHeight + 10)), nil, "DetailActions")
	return info, actions
end

-- unopened enchant chests (bought in the Kraken / Void shops) for the Items tab
local CHEST_ORDER = { "Void", "Kraken" }
local function chestItems()
	local ok, t = pcall(function() return HttpService:JSONDecode(a("Chests", "{}")) end)
	local list = {}
	if ok and type(t) == "table" then
		for _, k in ipairs(CHEST_ORDER) do
			local n = t[k]
			if type(n) == "number" and n > 0 and EnchantConfig.Chests[k] then table.insert(list, { key = k, count = n, chest = EnchantConfig.Chests[k] }) end
		end
	end
	return list
end

-- BACKPACK (inventory): Items (chests + eggs), Vacuums and Enchant tabs. Pets have their own menu.
local function eggItems()
	local ok, t = pcall(function() return HttpService:JSONDecode(a("EggItems", "{}")) end)
	local list = {}
	if ok and type(t) == "table" then
		for k, n in pairs(t) do
			if type(n) == "number" and n > 0 then
				local _, zone, v = Config.EggInfo(k)
				local _, vi = Config.EggVariant(v.Id)
				table.insert(list, { key = k, count = n, zone = zone, vi = vi })
			end
		end
	end
	table.sort(list, function(x, y) if x.vi ~= y.vi then return x.vi > y.vi end return x.zone > y.zone end)
	return list
end
local function eggTheme(key)
	local _, zone, v = Config.EggInfo(key)
	if v.Id == "Gold" then return C.yellow end
	if v.Id == "Rainbow" then return C.pink end
	return themeOf((Config.Zones[zone] and Config.Zones[zone].Accent) or (Config.Eggs.Accents and Config.Eggs.Accents[zone]) or C.blue[1])
end
local BAG_TABS = { { "Items", Assets.Egg1_Basic and "Egg1_Basic" or "GemPouch", C.green }, { "Vacuums", "Vac1", C.blue }, { "Enchant", "Enchant", C.purple } }
local bagTab = 1
local function buildBackpack()
	local content, tabButtons, root = openPanel("Backpack", "Backpack", 980, 560, BAG_TABS, C.blue)
	local left = frame(content, UDim2.new(1, -250, 1, 0), UDim2.new(), nil, "Left")
	local side = card(content, 0); side.Size = UDim2.new(0, 236, 1, 0); side.Position = UDim2.new(1, -236, 0, 0)
	local detailHolder = frame(side, UDim2.new(1, 0, 1, 0), UDim2.new(), nil, "Detail")
	local enchantBody = frame(content, UDim2.fromScale(1, 1), UDim2.new(), nil, "EnchantContent")
	enchantBody.Visible = false
	local renderEnchant
	local function clearDetail() for _, ch in ipairs(detailHolder:GetChildren()) do ch:Destroy() end end
	-- what you've tapped. Nothing is selected when the bag opens; the selection survives the list refreshing
	-- (counts change all the time while you vacuum) and the selected tile gets a thin white border.
	local eggSel, vacSel = nil, nil
	local chestSel = nil
	local cells = {} -- [key] = inventory card
	local function highlight(key)
		for k, c in pairs(cells) do inventorySelect(c, k == key) end
	end
	local function track(c, key) cells[key] = c end
	-- Items tab: eggs
	local function showEgg(e)
		clearDetail()
		if not e then emptyNote(detailHolder, "Tap an egg to see it here."); return end
		local name, _, v = Config.EggInfo(e.key)
		local multi = {}
		if e.count >= 3 then table.insert(multi, 3) end
		if e.count >= 8 then table.insert(multi, 8) end
		local info, actions = inventoryDetail(detailHolder, name, #multi > 0 and 166 or 108)
		EggIcon.make(info, e.key, UDim2.fromOffset(148, 148), UDim2.new(0.5, -74, 0, 0))
		local pal = eggTheme(e.key)
		local tag = frame(info, UDim2.new(0, 130, 0, 30), UDim2.new(0.5, -65, 0, 158), pal[1], "Tag"); corner(tag, 12); stroke(tag, 2.5, pal.bd, true)
		skin(tag, pal[1], { radius = 12, top = pal.hi, bottom = pal.lo, tile = 16, noGloss = true })
		label(tag, v.Name .. " Egg", UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 19, stroke = 2.5, strokeColor = pal.bd })
		label(info, "You have x" .. Format.short(e.count) .. ".", UDim2.new(1, -8, 0, 32), UDim2.fromOffset(4, 208), SOFT, { max = 18, stroke = 2, wrap = true, bold = true })
		local function openN(n)
			if Hatch.Busy then Hud.toast("Wait for your egg to hatch!", "Bad"); return end
			closeShop()
			local ok, res = Hatch.Open(e.key, n)
			if not ok then Hud.toast(tostring(res), "Bad") end
		end
		local openHolder = frame(actions, UDim2.new(1, 0, 0, 50), UDim2.new(), nil, "OpenHolder")
		local ob = button(openHolder, "OPEN 1 EGG", UDim2.new(1, 0, 1, -6), UDim2.new(), C.green, { max = 24 })
		ob.Activated:Connect(function() openN(1) end)
		-- Open 3 / Open 8 only show up when you have that many of this egg
		for i, n in ipairs(multi) do
			local w = 1 / #multi
			local h = frame(actions, UDim2.new(w, #multi == 1 and 0 or -4, 0, 50), UDim2.new(w * (i - 1), i == 1 and 0 or 4, 0, 58), nil, "Open" .. n .. "Holder")
			local b = button(h, "OPEN " .. n .. " EGGS", UDim2.new(1, 0, 1, -6), UDim2.new(), n == 8 and C.yellow or C.blue, { max = 20 })
			b.Activated:Connect(function() openN(n) end)
		end
		-- Auto Open (gamepass): keeps opening this egg, up to 8 at a time
		local ah = frame(actions, UDim2.new(1, 0, 0, 50), UDim2.fromOffset(0, #multi > 0 and 116 or 58), nil, "AutoOpenHolder")
		local hasAuto = PassPerks.Has(player, "AutoOpen")
		local ab = button(ah, hasAuto and "AUTO OPEN" or "AUTO OPEN (PASS)", UDim2.new(1, 0, 1, -6), UDim2.new(), hasAuto and C.purple or C.grey, { max = 20 })
		ab.Activated:Connect(function()
			if not PassPerks.Has(player, "AutoOpen") then Hud.openShop("Store"); return end
			if Hatch.Busy and not Hatch.Auto then Hud.toast("Wait for your egg to hatch!", "Bad"); return end
			closeShop()
			Hatch.StartAuto(e.key)
		end)
	end
	local function eggCell(parent, e, order)
		local c = card(parent, order)
		local pal = eggTheme(e.key)
		skin(c, pal[1], { radius = 14, top = pal.hi, bottom = pal.lo })
		EggIcon.make(c, e.key, UDim2.new(1, -20, 1, -44), UDim2.fromOffset(10, 6))
		local badge = frame(c, UDim2.fromOffset(54, 26), UDim2.fromOffset(6, 6), NAVY, "Count"); corner(badge, 10)
		label(badge, "x" .. Format.short(e.count), UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 18, stroke = 0, z = 7 }); badge.ZIndex = 6
		label(c, (Config.EggInfo(e.key)), UDim2.new(1, -8, 0, 32), UDim2.new(0, 4, 1, -34), WHITE, { max = 16, stroke = 2.5, strokeColor = pal.bd, wrap = true })
		local hit = Instance.new("TextButton"); hit.BackgroundTransparency = 1; hit.Text = ""; hit.Size = UDim2.fromScale(1, 1); hit.ZIndex = 9; hit.Parent = c
		c.Name = "Egg_" .. e.key
		track(c, e.key)
		hit.Activated:Connect(function() eggSel = e.key; chestSel = nil; highlight(e.key); showEgg(e) end)
	end
	-- Items tab: enchant chests
	local function showChest(ch)
		clearDetail()
		local info, actions = inventoryDetail(detailHolder, ch.chest.Name, 50)
		local img = Instance.new("ImageLabel"); img.Name = "ChestPreview"; img.BackgroundTransparency = 1; img.ScaleType = Enum.ScaleType.Fit
		img.Image = ch.chest.Image or ""; img.Size = UDim2.fromOffset(160, 160); img.Position = UDim2.new(0.5, -80, 0, 0); img.ZIndex = 5; img.Parent = info
		label(info, "You have x" .. Format.short(ch.count) .. ".", UDim2.new(1, -8, 0, 28), UDim2.fromOffset(4, 166), SOFT, { max = 18, stroke = 2, bold = true })
		label(info, "Open it to roll 1 of 8 " .. (ch.key == "Kraken" and "Kraken" or "Void") .. " enchants. Duplicates sell for " .. (ch.key == "Kraken" and "Kraken Scales" or "Void Shards") .. ".",
			UDim2.new(1, -8, 0, 64), UDim2.fromOffset(4, 196), SOFT, { max = 15, stroke = 2, wrap = true })
		local holder = frame(actions, UDim2.fromScale(1, 1), UDim2.new(), nil, "OpenHolder")
		local ob = button(holder, "OPEN CHEST", UDim2.new(1, 0, 1, -6), UDim2.new(), C.green, { max = 24 })
		ob.Activated:Connect(function()
			if player.PlayerGui:FindFirstChild("EnchantReel") then Hud.toast("Wait for your chest to open!", "Bad"); return end
			local ok, res = ReplicatedStorage.Remotes.EnchantAction:InvokeServer("Open", ch.key)
			if ok then closeShop() else Hud.toast(tostring(res or "Couldn't open that"), "Bad") end
		end)
	end
	local function chestCell(parent, ch, order)
		local c = card(parent, order)
		local pal = T(ch.key == "Kraken" and C.blue or C.purple)
		skin(c, pal[1], { radius = 14, top = pal.hi, bottom = pal.lo })
		local img = Instance.new("ImageLabel"); img.BackgroundTransparency = 1; img.ScaleType = Enum.ScaleType.Fit; img.Image = ch.chest.Image or ""
		img.Size = UDim2.new(1, -16, 1, -44); img.Position = UDim2.fromOffset(8, 6); img.ZIndex = 5; img.Parent = c
		local badge = frame(c, UDim2.fromOffset(54, 26), UDim2.fromOffset(6, 6), NAVY, "Count"); corner(badge, 10)
		label(badge, "x" .. Format.short(ch.count), UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 18, stroke = 0, z = 7 }); badge.ZIndex = 6
		label(c, ch.chest.Name, UDim2.new(1, -8, 0, 32), UDim2.new(0, 4, 1, -34), WHITE, { max = 16, stroke = 2.5, strokeColor = pal.bd, wrap = true })
		local hit = Instance.new("TextButton"); hit.BackgroundTransparency = 1; hit.Text = ""; hit.Size = UDim2.fromScale(1, 1); hit.ZIndex = 9; hit.Parent = c
		c.Name = "Chest_" .. ch.key
		track(c, "chest" .. ch.key)
		hit.Activated:Connect(function() chestSel = ch.key; eggSel = nil; highlight("chest" .. ch.key); showChest(ch) end)
	end
	-- Vacuums tab: the vacuums you own
	local function showVac(v)
		clearDetail()
		if not v then emptyNote(detailHolder, "Tap a vacuum to see it here."); return end
		local info, actions = inventoryDetail(detailHolder, v.Name, 50)
		-- Fill the available summary height with the preview and keep stats just above the action.
		info.AutomaticCanvasSize = Enum.AutomaticSize.None; info.CanvasSize = UDim2.new()
		local img = icon(info, "Vac" .. v.Id, UDim2.new(1, -8, 1, -70), UDim2.fromOffset(4, 0)); img.Rotation = -6
		img.Name = "VacuumPreview"
		local stats = label(info, string.format("x%d Power  •  Range %d\n%.1f hits/s  •  %d targets", v.PowerMult, v.Range, 1 / v.Interval, v.Targets),
			UDim2.new(1, -8, 0, 54), UDim2.new(0, 4, 1, -62), SOFT, { max = 17, stroke = 2, wrap = true, bold = true })
		stats.Name = "VacuumStats"
		local eq = a("Vacuum", 1) == v.Id
		local holder = frame(actions, UDim2.fromScale(1, 1), UDim2.new(), nil, "EquipHolder")
		local b = button(holder, eq and "EQUIPPED" or "EQUIP", UDim2.new(1, 0, 1, -6), UDim2.new(), eq and C.blue or C.green, { max = 24 })
		b.Activated:Connect(function()
			if a("Vacuum", 1) == v.Id then return end
			local ok, res = ReplicatedStorage.Remotes.EquipVacuum:InvokeServer(v.Id)
			if ok then Sfx.play("Upgrade", 1.1, 0.6); Hud.toast("Equipped " .. v.Name .. "!", "Sell") else Hud.toast(tostring(res), "Bad") end
		end)
	end
	local function vacCell(parent, v, order)
		local c = card(parent, order)
		local vt = vacTheme(v)
		skin(c, vt[1], { radius = 14, top = vt.hi, bottom = vt.lo })
		local img = icon(c, "Vac" .. v.Id, UDim2.new(1, -16, 1, -44), UDim2.fromOffset(8, 4)); img.Rotation = -6
		label(c, v.Name, UDim2.new(1, -8, 0, 30), UDim2.new(0, 4, 1, -32), WHITE, { max = 17, stroke = 2.5, strokeColor = vt.bd })
		if a("Vacuum", 1) == v.Id then
			local eqTag = frame(c, UDim2.fromOffset(30, 30), UDim2.new(1, -36, 0, 6), nil, "Equipped")
			icon(eqTag, "Check", UDim2.fromScale(1, 1), UDim2.new()).ZIndex = 7
		end
		local hit = Instance.new("TextButton"); hit.BackgroundTransparency = 1; hit.Text = ""; hit.Size = UDim2.fromScale(1, 1); hit.ZIndex = 9; hit.Parent = c
		c.Name = "Vac_" .. v.Id
		track(c, "vac" .. v.Id)
		hit.Activated:Connect(function() vacSel = v.Id; highlight("vac" .. v.Id); showVac(v) end)
	end
	local lastTab = nil
	refreshShop = function()
		selectTab(tabButtons, BAG_TABS, bagTab)
		local enchanting = bagTab == 3
		left.Visible = not enchanting; side.Visible = not enchanting; enchantBody.Visible = enchanting
		if enchanting then
			if not renderEnchant and Hud.BuildEnchantTab then renderEnchant = Hud.BuildEnchantTab(enchantBody, root) end
			if renderEnchant then renderEnchant() end
			return
		end
		-- keep the scroll position when the list rebuilds (not when switching tabs)
		local old = left:FindFirstChildOfClass("ScrollingFrame")
		local scrollY = (old and lastTab == bagTab) and old.CanvasPosition.Y or 0
		lastTab = bagTab
		for _, ch in ipairs(left:GetChildren()) do ch:Destroy() end
		table.clear(cells)
		local list
		if bagTab == 1 then
			local eggs = eggItems()
			local chests = chestItems()
			if #eggs == 0 and #chests == 0 then eggSel = nil; chestSel = nil; emptyNote(left, "No items yet.\nVacuum the eggs you find in each area!"); showEgg(nil); return end
			list = scroller(left, 150, 4)
			local sel, csel
			for i, ch in ipairs(chests) do
				chestCell(list, ch, i)
				if ch.key == chestSel then csel = ch end
			end
			for i, e in ipairs(eggs) do
				eggCell(list, e, #chests + i)
				if e.key == eggSel then sel = e end
			end
			if not csel then chestSel = nil end -- opened the last one
			if not sel then eggSel = nil end -- that egg ran out
			if csel then highlight("chest" .. csel.key); showChest(csel)
			else highlight(eggSel); showEgg(sel) end
		else
			list = scroller(left, 150, 4)
			local sel
			for i, v in ipairs(Config.Vacuums) do
				if owned(v.Id) then vacCell(list, v, i); if v.Id == vacSel then sel = v end end
			end
			if not sel then vacSel = nil end
			highlight(vacSel and ("vac" .. vacSel) or nil)
			showVac(sel)
		end
		task.defer(function() if list and list.Parent then list.CanvasPosition = Vector2.new(0, scrollY) end end)
	end
	for i, b in ipairs(tabButtons) do
		b.Activated:Connect(function() if bagTab ~= i then bagTab = i; refreshShop() end end)
	end
	refreshShop()
end

-- PETS menu (its own button under Home). Every pet copy is its own tile (no stacking),
-- with sort filters and an Equip Best button. Equipped pets are always listed first.
local PET_SORTS = { "Best", "Rarity", "A-Z", "Recent" }
local petSort = 1     -- remembered while you play
local petCols = 3     -- grid view: 3 (3x3, the default) or 5 (5x5) pets per row and rows on screen, remembered while you play
local GRID_ICONS = { [3] = "rbxassetid://103927174895074", [5] = "rbxassetid://84061439777000" }
local STAT_VAC = "Vac1" -- the pet UI shows the Vacuum stat with the starter vacuum icon
local petSelU = nil   -- keeps the same pet selected when the list refreshes (e.g. after equipping)
local function petView(parent, id, size, pos)
	-- pets with a 2D icon (the boss pets) use the same picture as the boss-event UI
	local img = PetData.Icons and PetData.Icons[id]
	if img then
		local il = Instance.new("ImageLabel"); il.Name = "PetIcon"; il.BackgroundTransparency = 1; il.Size = size; il.Position = pos
		il.Image = img; il.ScaleType = Enum.ScaleType.Fit; il.ZIndex = 6; il.Parent = parent
		return il
	end
	local vp = Instance.new("ViewportFrame"); vp.BackgroundTransparency = 1; vp.Size = size; vp.Position = pos; vp.ZIndex = 6
	vp.LightColor = WHITE; vp.Ambient = Color3.fromRGB(175, 175, 175); vp.LightDirection = Vector3.new(-1, -1.4, -1)
	vp.Parent = parent
	local folder = ReplicatedStorage:FindFirstChild("PetModels")
	local src = folder and folder:FindFirstChild(id)
	if not src then return vp end
	local m = src:Clone(); m.Parent = vp
	local cf, sz = m:GetBoundingBox()
	local look = (cf * CFrame.Angles(0, PetData.Hatch.PetYaw or 0, 0))
	local d = math.max(sz.X, sz.Y, sz.Z) * 1.55 -- close camera = the pet fills its tile
	local cam = Instance.new("Camera"); cam.FieldOfView = 30; cam.Parent = vp; vp.CurrentCamera = cam
	cam.CFrame = CFrame.lookAt(cf.Position + look.LookVector * d + look.RightVector * d * 0.45 + Vector3.new(0, d * 0.3, 0), cf.Position)
	return vp
end
local function petMult(v) return "x" .. tostring(math.floor(v * 100 + 0.5) / 100) end
-- server attribute PetList: [{ u = "p12", id = "BarnCat" }, ...]  (higher number = hatched later)
local function petCopies()
	local ok, t = pcall(function() return HttpService:JSONDecode(a("PetList", "[]")) end)
	local list = {}
	if ok and type(t) == "table" then
		for _, e in ipairs(t) do
			local p = type(e) == "table" and PetData.ById[e.id]
			if p then table.insert(list, { u = e.u, p = p, n = tonumber(string.sub(e.u, 2)) or 0 }) end
		end
	end
	return list
end
local function equippedUids()
	local ok, t = pcall(function() return HttpService:JSONDecode(a("EquippedUids", "[]")) end)
	local set, n = {}, 0
	if ok and type(t) == "table" then for _, u in ipairs(t) do set[u] = true; n += 1 end end
	return set, n
end
local function sortPets(list, eq)
	local mode = PET_SORTS[petSort]
	table.sort(list, function(x, y)
		local ex, ey = eq[x.u] == true, eq[y.u] == true
		if ex ~= ey then return ex end -- equipped pets first
		if mode == "Best" then
			local sx, sy = PetData.Score(x.p.Id), PetData.Score(y.p.Id)
			if sx ~= sy then return sx > sy end
		elseif mode == "Rarity" then
			local rx, ry = PetData.Rarities[x.p.Rarity].Order, PetData.Rarities[y.p.Rarity].Order
			if rx ~= ry then return rx > ry end
			if x.p.Name ~= y.p.Name then return x.p.Name < y.p.Name end
		elseif mode == "A-Z" then
			if x.p.Name ~= y.p.Name then return x.p.Name < y.p.Name end
		end
		return x.n > y.n -- then newest first
	end)
end
local function petAction(action, u)
	local ok, res = ReplicatedStorage.Remotes.EquipPet:InvokeServer(action, u)
	if ok then
		Sfx.play("Upgrade", (action == "unequip" or action == "unequipAll") and 0.9 or 1.15, 0.5)
		if action == "best" then Hud.toast("Equipped your best pets!", "Sell") end
		if action == "unequipAll" then Hud.toast("Unequipped all pets.", "Sell") end
	else Hud.toast(tostring(res), "Bad") end
end
local function buildPets()
	local content, _, root = openPanel("Pets", Assets.Pet and "Pet" or "Star", 980, 560, nil, C.pink)
	local left = frame(content, UDim2.new(1, -250, 1, 0), UDim2.new(), nil, "Left")
	local bar = frame(left, UDim2.new(1, 0, 0, 50), UDim2.new(), nil, "Filters")
	local grid = frame(left, UDim2.new(1, 0, 1, -58), UDim2.fromOffset(0, 58), nil, "Grid")
	local side = card(content, 0); side.Size = UDim2.new(0, 236, 1, 0); side.Position = UDim2.new(1, -236, 0, 0)
	local detailHolder = frame(side, UDim2.new(1, 0, 1, 0), UDim2.new(), nil, "Detail")
	local function clearDetail() for _, ch in ipairs(detailHolder:GetChildren()) do ch:Destroy() end end
	local refresh
	-- top bar: [SORT: BEST v] [4x4] [8x8] ...... [DELETE] [UNEQUIP ALL] [EQUIP BEST]
	-- delete mode: tap pets to pick several, then delete them all at once (equipped pets can't be picked)
	local delMode, delSel, delConfirm = false, {}, false
	local function setText(b, t)
		local l = b:FindFirstChild("Label"); if not l then return end
		l.Text = t
		local sh = l:FindFirstChild("ShadowRef") and l.ShadowRef.Value; if sh then sh.Text = t end
	end
	local sortBtn = button(bar, "", UDim2.fromOffset(150, 40), UDim2.fromOffset(0, 2), C.yellow, { max = 18, radius = 8, name = "SortButton", tile = 18 })
	-- the drop-down list of sort options (drawn above the pet grid)
	-- a short scrollable list: 3 options visible, scroll for the rest
	local drop = frame(left, UDim2.fromOffset(168, 3 * 44 + 10), UDim2.fromOffset(0, 50), NAVY, "SortMenu")
	drop.BackgroundTransparency = 0.05; corner(drop, 10); stroke(drop, 3, OUT, true)
	local dropScroll = Instance.new("ScrollingFrame"); dropScroll.Name = "List"; dropScroll.BackgroundTransparency = 1; dropScroll.BorderSizePixel = 0
	dropScroll.Size = UDim2.new(1, -4, 1, -8); dropScroll.Position = UDim2.fromOffset(0, 4)
	dropScroll.CanvasSize = UDim2.fromOffset(0, #PET_SORTS * 44 + 2); dropScroll.ScrollBarThickness = 6
	dropScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 220, 90); dropScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	dropScroll.Parent = drop
	local optBtns = {}
	for i, name in ipairs(PET_SORTS) do
		local b = button(dropScroll, name, UDim2.fromOffset(148, 38), UDim2.fromOffset(6, 2 + (i - 1) * 44), C.blue, { max = 18, radius = 8, name = "Sort" .. i, tile = 18 })
		optBtns[i] = b
		b.Activated:Connect(function() drop.Visible = false; if petSort ~= i then petSort = i; refresh() end end)
	end
	drop.ZIndex = 30
	for _, d in ipairs(drop:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex += 30 end end
	drop.Visible = false
	sortBtn.Activated:Connect(function() drop.Visible = not drop.Visible end)
	-- one grid-size button: shows the current view's icon (3x3 or 5x5), tap to switch
	local viewBtn = button(bar, "", UDim2.fromOffset(48, 40), UDim2.fromOffset(158, 2), C.blue, { max = 18, radius = 8, name = "GridToggle", tile = 18 })
	local viewIcon = Instance.new("ImageLabel"); viewIcon.Name = "GridIcon"; viewIcon.BackgroundTransparency = 1
	viewIcon.AnchorPoint = Vector2.new(0.5, 0.5); viewIcon.Position = UDim2.fromScale(0.5, 0.5); viewIcon.Size = UDim2.fromOffset(32, 32)
	viewIcon.ScaleType = Enum.ScaleType.Fit; viewIcon.ZIndex = viewBtn.ZIndex + 5; viewIcon.Parent = viewBtn
	viewBtn.Activated:Connect(function() drop.Visible = false; petCols = petCols == 3 and 5 or 3; refresh() end)
	local delBtn = button(bar, "DELETE", UDim2.fromOffset(92, 40), UDim2.new(1, -342, 0, 2), C.red, { max = 17, radius = 8, name = "DeleteMode", tile = 18 })
	delBtn.Activated:Connect(function()
		drop.Visible = false
		delMode = not delMode; delSel = {}; delConfirm = false
		refresh()
	end)
	local unAll = button(bar, "UNEQUIP ALL", UDim2.fromOffset(122, 40), UDim2.new(1, -244, 0, 2), C.orange or C.red, { max = 16, radius = 8, name = "UnequipAll", tile = 18 })
	unAll.Activated:Connect(function() drop.Visible = false; petAction("unequipAll") end)
	local best = button(bar, "EQUIP BEST", UDim2.fromOffset(116, 40), UDim2.new(1, -116, 0, 2), C.green, { max = 16, radius = 8, name = "EquipBest", tile = 18 })
	best.Activated:Connect(function() drop.Visible = false; petAction("best") end)

	local function showPet(e, eq, team)
		clearDetail()
		if not e then emptyNote(detailHolder, "Your pets will show up here."); return end
		petSelU = e.u
		local pal = themeOf(PetData.Rarities[e.p.Rarity].Color)
		label(detailHolder, e.p.Name, UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, 6), WHITE, { max = 24, stroke = 3, wrap = true })
		petView(detailHolder, e.p.Id, UDim2.new(1, -30, 0, 130), UDim2.fromOffset(15, 38))
		local tag = frame(detailHolder, UDim2.new(0, 120, 0, 26), UDim2.new(0.5, -60, 0, 166), pal[1], "Tag"); corner(tag, 12); stroke(tag, 2.5, pal.bd, true)
		skin(tag, pal[1], { radius = 12, top = pal.hi, bottom = pal.lo, tile = 16, noGloss = true })
		label(tag, e.p.Rarity, UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 17, stroke = 2.5, strokeColor = pal.bd })
		if e.p.Zone ~= "Boss" then -- boss pets don't show a "Boss drop" line
			label(detailHolder, e.p.Odds, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 196), GOLD, { max = 17, stroke = 2 })
		end
		local st = PetData.Stats[e.p.Id] or { Coins = 1, Gems = 1, Vacuum = 1 }
		for i, row in ipairs({ { "Coin", st.Coins, "Coins", GOLD }, { "Gem", st.Gems, "Gems", rgb(130, 220, 255) }, { STAT_VAC, st.Vacuum, "Vacuum", rgb(170, 255, 120) } }) do
			local y = 224 + (i - 1) * 27
			local ic = icon(detailHolder, row[1], UDim2.fromOffset(24, 24), UDim2.fromOffset(34, y)); ic.ZIndex = 6
			label(detailHolder, petMult(row[2]) .. " " .. row[3], UDim2.new(1, -74, 0, 24), UDim2.fromOffset(64, y), row[4],
				{ max = 18, stroke = 2, align = Enum.TextXAlignment.Left })
		end
		label(detailHolder, "Team " .. team .. "/" .. PetData.MaxEquipped, UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 308), SOFT, { max = 16, stroke = 2, bold = true })
		local txt, pal2, fn
		if eq[e.u] then txt, pal2, fn = "UNEQUIP", C.red, function() petAction("unequip", e.u) end
		elseif team < PetData.MaxEquipped then txt, pal2, fn = "EQUIP", C.green, function() petAction("equip", e.u) end
		else txt, pal2, fn = "TEAM FULL", C.grey, function() Hud.toast("You can equip " .. PetData.MaxEquipped .. " pets. Unequip one first.", "Bad") end end
		local h = frame(detailHolder, UDim2.new(1, -20, 0, 50), UDim2.fromOffset(10, 336), nil, "PetBtn")
		button(h, txt, UDim2.new(1, 0, 1, -6), UDim2.new(), pal2, { max = 24 }).Activated:Connect(fn)
	end
	-- the side panel in delete mode
	local function showDelete(pets, eq)
		clearDetail()
		local n = 0
		for _ in pairs(delSel) do n += 1 end
		label(detailHolder, "DELETE PETS", UDim2.new(1, -16, 0, 36), UDim2.fromOffset(8, 6), rgb(255, 120, 120), { max = 26, stroke = 3 })
		label(detailHolder, "Tap pets to pick them. Equipped pets can't be deleted.", UDim2.new(1, -20, 0, 50), UDim2.fromOffset(10, 46), SOFT, { max = 16, stroke = 2, wrap = true, bold = true })
		label(detailHolder, n .. " selected", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 102), WHITE, { max = 24, stroke = 2.5 })
		local h1 = frame(detailHolder, UDim2.new(0.5, -14, 0, 48), UDim2.fromOffset(10, 142), nil, "SelectAll")
		button(h1, "ALL", UDim2.new(1, 0, 1, -6), UDim2.new(), C.blue, { max = 20 }).Activated:Connect(function()
			for _, e in ipairs(pets) do if not eq[e.u] then delSel[e.u] = true end end
			delConfirm = false; refresh()
		end)
		local h2 = frame(detailHolder, UDim2.new(0.5, -14, 0, 48), UDim2.new(0.5, 4, 0, 142), nil, "Clear")
		button(h2, "CLEAR", UDim2.new(1, 0, 1, -6), UDim2.new(), C.grey, { max = 20 }).Activated:Connect(function()
			delSel = {}; delConfirm = false; refresh()
		end)
		local h3 = frame(detailHolder, UDim2.new(1, -20, 0, 58), UDim2.fromOffset(10, 200), nil, "DeleteNow")
		local txt = delConfirm and "TAP TO CONFIRM" or ("DELETE " .. n)
		button(h3, txt, UDim2.new(1, 0, 1, -6), UDim2.new(), n > 0 and C.red or C.grey, { max = 22 }).Activated:Connect(function()
			if n == 0 then return end
			if not delConfirm then
				delConfirm = true; refresh()
				task.delay(3, function() if delConfirm then delConfirm = false; refresh() end end)
				return
			end
			delConfirm = false
			local list = {}
			for u in pairs(delSel) do table.insert(list, u) end
			local ok, res = ReplicatedStorage.Remotes.EquipPet:InvokeServer("delete", list)
			if ok then Sfx.play("Upgrade", 0.75, 0.5); delSel = {} else Hud.toast(tostring(res), "Bad") end
			refresh()
		end)
		local h4 = frame(detailHolder, UDim2.new(1, -20, 0, 50), UDim2.fromOffset(10, 266), nil, "Done")
		button(h4, "DONE", UDim2.new(1, 0, 1, -6), UDim2.new(), C.green, { max = 22 }).Activated:Connect(function()
			delMode = false; delSel = {}; delConfirm = false; refresh()
		end)
	end
	local function petCell(parent, e, order, isEq, onTap)
		local small = petCols == 5
		local c = card(parent, order); c.Name = "Pet_" .. e.u
		local pal = themeOf(PetData.Rarities[e.p.Rarity].Color)
		skin(c, pal[1], { radius = small and 8 or 12, top = pal.hi, bottom = pal.lo })
		if small then
			local cr = c:FindFirstChildOfClass("UICorner"); if cr then cr.CornerRadius = UDim.new(0, 8) end
			local s = c:FindFirstChildOfClass("UIStroke"); if s then s.Thickness = 2.5 end
			c.ClipsDescendants = true
			local pv = petView(c, e.p.Id, UDim2.new(1, -2, 1, -2), UDim2.fromOffset(1, 1)); pv.ZIndex = 5
		else
			-- the picture fills the whole tile (the name and stats sit on top of it), clipped to the tile
			c.ClipsDescendants = true
			local pv = petView(c, e.p.Id, UDim2.new(1, -4, 1, -4), UDim2.fromOffset(2, 0)); pv.ZIndex = 5
			local nm = label(c, e.p.Name, UDim2.new(1, -4, 0, 22), UDim2.new(0, 2, 1, -24), WHITE, { max = 13, stroke = 2, strokeColor = pal.bd, z = 8, padX = 1 })
			nm:FindFirstChildOfClass("UITextSizeConstraint").MinTextSize = 1 -- long names shrink to fit on one line
		end
		-- stats in the top-left corner (12x12 tiles are tiny, so they show the Vacuum multiplier only)
		local st = PetData.Stats[e.p.Id] or { Coins = 1, Gems = 1, Vacuum = 1 }
		local rows = small and { { STAT_VAC, st.Vacuum, rgb(170, 255, 120) } }
			or { { "Coin", st.Coins, GOLD }, { "Gem", st.Gems, rgb(130, 220, 255) }, { STAT_VAC, st.Vacuum, rgb(170, 255, 120) } }
		for i, row in ipairs(rows) do
			local isz, x = small and 11 or 14, small and 2 or 5
			local y = (small and 2 or 4) + (i - 1) * 15
			local ic = icon(c, row[1], UDim2.fromOffset(isz, isz), UDim2.fromOffset(x, y)); ic.ZIndex = 8
			label(c, petMult(row[2]), UDim2.fromOffset(small and 34 or 52, isz + 1), UDim2.fromOffset(x + isz + 1, y), row[3],
				{ max = small and 11 or 14, stroke = small and 1.5 or 2, align = Enum.TextXAlignment.Left, z = 8 })
		end
		if isEq then -- equipped: a check mark in the top-right corner
			local sz = small and 15 or 22
			local eqTag = frame(c, UDim2.fromOffset(sz, sz), UDim2.new(1, -(sz + (small and 1 or 4)), 0, small and 1 or 4), nil, "Equipped")
			icon(eqTag, "Check", UDim2.fromScale(1, 1), UDim2.new()).ZIndex = 8
		end
		if delMode then
			if isEq then -- equipped pets can't be deleted: greyed out
				local dim = frame(c, UDim2.fromScale(1, 1), UDim2.new(), BLACK, "Locked"); dim.BackgroundTransparency = 0.55; dim.ZIndex = 8
				corner(dim, small and 8 or 12)
			elseif delSel[e.u] then -- picked for deleting: red outline + a big X
				local s = c:FindFirstChildOfClass("UIStroke"); if s then s.Color = rgb(255, 60, 70); s.Thickness = small and 3.5 or 5 end
				local tint = frame(c, UDim2.fromScale(1, 1), UDim2.new(), rgb(255, 40, 60), "Picked"); tint.BackgroundTransparency = 0.7; tint.ZIndex = 8
				corner(tint, small and 8 or 12)
				label(c, "X", UDim2.fromScale(1, 1), UDim2.new(), rgb(255, 80, 90), { max = small and 26 or 48, stroke = 3, z = 9 })
			end
		elseif e.u == petSelU then -- selected: gold outline
			local s = c:FindFirstChildOfClass("UIStroke"); if s then s.Color = GOLD; s.Thickness = 4.5 end
		end
		local hit = Instance.new("TextButton"); hit.BackgroundTransparency = 1; hit.Text = ""; hit.Size = UDim2.fromScale(1, 1); hit.ZIndex = 9; hit.Parent = c
		hit.Activated:Connect(onTap)
	end
	refresh = function()
		if shopRoot ~= root then return end
		setText(sortBtn, "SORT: " .. string.upper(PET_SORTS[petSort]))
		for i, b in ipairs(optBtns) do paint(b, i == petSort and C.yellow or C.blue) end
		viewIcon.Image = GRID_ICONS[petCols] or ""
		setText(delBtn, delMode and "DONE" or "DELETE"); paint(delBtn, delMode and C.green or C.red)
		local old = grid:FindFirstChildOfClass("ScrollingFrame")
		local scrollY = old and old.CanvasPosition.Y or 0
		for _, ch in ipairs(grid:GetChildren()) do ch:Destroy() end
		local pets = petCopies()
		local eq, team = equippedUids()
		if #pets == 0 then
			emptyNote(grid, "No pets yet.\nOpen an egg from your Bag!")
			showPet(nil, eq, team)
			return
		end
		sortPets(pets, eq)
		-- 3x3 / 5x5: that many pets per row, and that many rows fit on screen
		local padY = petCols == 5 and 8 or 12
		local list = scroller(grid, 80, petCols)
		local gl = list:FindFirstChildOfClass("UIGridLayout")
		-- cell height as a share of the visible grid, so exactly petCols rows fit whatever the screen size
		gl.CellSize = UDim2.new(1 / petCols, petCols == 5 and -8 or -12, 1 / petCols, -(16 + (petCols - 1) * padY) / petCols)
		if petCols == 5 then gl.CellPadding = UDim2.fromOffset(8, padY) end
		-- forget picks of pets that are gone
		local have = {}
		for _, e in ipairs(pets) do have[e.u] = true end
		for u in pairs(delSel) do if not have[u] or eq[u] then delSel[u] = nil end end
		local sel = pets[1]
		for _, e in ipairs(pets) do if e.u == petSelU then sel = e end end
		petSelU = sel.u
		for i, e in ipairs(pets) do
			petCell(list, e, i, eq[e.u], function()
				if delMode then
					if eq[e.u] then return end
					delSel[e.u] = (not delSel[e.u]) or nil; delConfirm = false
				else
					petSelU = e.u
				end
				refresh()
			end)
		end
		if delMode then showDelete(pets, eq) else showPet(sel, eq, team) end
		task.defer(function() if list.Parent then list.CanvasPosition = Vector2.new(0, scrollY) end end)
	end
	-- attribute changes (equip, new pets) can arrive several at once: rebuild once per frame
	local pending = false
	refreshShop = function()
		if pending then return end
		pending = true
		task.defer(function() pending = false; refresh() end)
	end
	refresh()
end

-- WORLDS (teleport to any area you've unlocked)
local function zoneEntry(z)
	if z == 0 then return Config.Spawn end
	if z == 1 then return Vector3.new(-343, 4, 260) end
	return Config.ZoneEntry(z)
end
local function buildWorlds()
	local content = openPanel("Worlds", "Island", 860, 530, nil, C.green)
	-- one column, one row per area (the plaza isn't listed: the Home button already goes there).
	-- Each row shows a small 3D scene of that zone (ReplicatedStorage.WorldBanners.ZoneN) behind it.
	local list = scroller(content, 128, 1)
	local cards = {}
	local entries = {}
	local banners = ReplicatedStorage:FindFirstChild("WorldBanners")
	local SKY = { [9] = Color3.fromRGB(44, 30, 84), [10] = Color3.fromRGB(28, 34, 92), [11] = Color3.fromRGB(200, 96, 60) }
	local views = {}
	for z, zc in ipairs(Config.Zones) do table.insert(entries, { z, zc.Name, zc.Accent, zc.Cost }) end
	for i, e in ipairs(entries) do
		local c = card(list, i)
		local et = themeOf(e[3])
		-- zone scene (filled in when the row scrolls into view)
		local vp = Instance.new("ViewportFrame"); vp.Name = "Scene"; vp.Size = UDim2.new(1, -8, 1, -8); vp.Position = UDim2.fromOffset(4, 4)
		vp.BackgroundColor3 = SKY[e[1]] or Color3.fromRGB(110, 190, 245); vp.BorderSizePixel = 0; vp.ZIndex = 2
		vp.Ambient = Color3.fromRGB(175, 175, 190); vp.LightColor = WHITE; vp.LightDirection = Vector3.new(-0.5, -1, 0.7); vp.Parent = c
		corner(vp, 9)
		local shade = frame(c, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4), BLACK, "Shade"); shade.ZIndex = 3; corner(shade, 9)
		local sg = Instance.new("UIGradient"); sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.45, 0.8), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.6) }); sg.Parent = shade
		table.insert(views, { vp = vp, z = e[1] })
		local head = frame(c, UDim2.new(0.5, -20, 0, 44), UDim2.fromOffset(12, 12), e[3], "Head"); head.ZIndex = 4; corner(head, 8); stroke(head, 3, et.bd, true)
		skin(head, e[3], { radius = 8, tile = 26, top = et.hi, bottom = et.lo })
		label(head, e[2], UDim2.new(1, -16, 1, -6), UDim2.fromOffset(8, 3), WHITE, { max = 26, stroke = 3, strokeColor = et.bd, extrude = true, align = Enum.TextXAlignment.Left, z = 6 })
		local sub = label(c, "Area " .. e[1], UDim2.new(0.5, -20, 0, 28), UDim2.fromOffset(16, 64), WHITE, { max = 20, stroke = 3, align = Enum.TextXAlignment.Left, z = 6 })
		local btn = button(c, "Teleport", UDim2.fromOffset(226, 58), UDim2.new(1, -240, 0.5, -31), C.blue, { icon = "Island", max = 24, iconPad = 44 })
		if btn.Parent and btn.Parent ~= c then btn.Parent.ZIndex = 6 else btn.ZIndex = 6 end
		btn.Activated:Connect(function()
			local unlocked = e[1] <= a("ZoneUnlocked", 1)
			if not unlocked then Hud.toast("Unlock " .. e[2] .. " at its gate first!", "Bad"); return end
			closeShop(); teleport(CFrame.new(zoneEntry(e[1])))
		end)
		cards[i] = { btn = btn, z = e[1], cost = e[4] }
	end
	-- only build the 3D scenes for rows you can see (keeps the menu light on phones)
	local function fillVisible()
		local top, bottom = list.AbsolutePosition.Y - 120, list.AbsolutePosition.Y + list.AbsoluteSize.Y + 120
		for _, v in ipairs(views) do
			if not v.done and v.vp.Parent then
				local y = v.vp.AbsolutePosition.Y
				if y + v.vp.AbsoluteSize.Y > top and y < bottom then
					v.done = true
					local src = banners and banners:FindFirstChild("Zone" .. v.z)
					if src then
						src:Clone().Parent = v.vp
						local cam = Instance.new("Camera")
						local aspect = math.max(1, v.vp.AbsoluteSize.X / math.max(1, v.vp.AbsoluteSize.Y))
						cam.FieldOfView = math.deg(2 * math.atan(math.tan(math.rad(36)) / aspect))
						cam.CFrame = CFrame.lookAt(Vector3.new(0, 27, -105), Vector3.new(0, 16, 70))
						cam.Parent = v.vp
						v.vp.CurrentCamera = cam
					end
				end
			end
		end
	end
	list:GetPropertyChangedSignal("CanvasPosition"):Connect(fillVisible)
	task.defer(fillVisible)
	task.delay(0.4, fillVisible) -- after the open animation settles
	refreshShop = function()
		for _, c in ipairs(cards) do
			local unlocked = c.z <= a("ZoneUnlocked", 1)
			local lbl, ic = c.btn:FindFirstChild("Label"), c.btn:FindFirstChild("Icon")
			if unlocked then lbl.Text = "Teleport"; ic.Image = Assets.Island; paint(c.btn, C.blue)
			else lbl.Text = Format.short(c.cost); ic.Image = Assets.Lock; paint(c.btn, C.grey) end
		end
	end
	refreshShop()
end

-- DAILY SPIN
local spinning = false
local function spinWheel3D(idx, duration)
	local plaza = workspace:FindFirstChild("Plaza")
	local wheel = plaza and plaza:FindFirstChild("DailySpin") and plaza.DailySpin:FindFirstChild("Wheel")
	if not wheel or not wheel.PrimaryPart then return end
	local base = wheel:GetAttribute("BaseCFrame") or wheel.PrimaryPart.CFrame
	wheel:SetAttribute("BaseCFrame", base)
	local target = math.rad((idx - 1) * 45) + math.pi * 2 * 6
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - t0) / duration, 0, 1)
		local e = 1 - (1 - t) ^ 3
		local pos = base.Position
		wheel:PivotTo(CFrame.new(pos) * CFrame.fromAxisAngle(Vector3.new(0, 0, 1), target * e) * (base - pos))
		if t >= 1 then conn:Disconnect() end
	end)
end
local function buildSpin()
	local content = openPanel("Daily Spin", "Wheel", 780, 470, nil, C.pink)
	local legend = frame(content, UDim2.new(0.58, 0, 1, 0), UDim2.new(), nil, "Legend")
	local gl = Instance.new("UIGridLayout"); gl.CellSize = UDim2.new(0.5, -8, 0.25, -10); gl.CellPadding = UDim2.fromOffset(12, 12)
	gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = legend
	local chips = {}
	for i, pr in ipairs(Config.Spin.Prizes) do
		local pt = themeOf(pr.Color)
		local chip = frame(legend, UDim2.new(), UDim2.new(), pr.Color, "Prize" .. i); chip.LayoutOrder = i
		corner(chip, 10); stroke(chip, 3.5, pt.bd, true); skin(chip, pr.Color, { radius = 10, top = pt.hi, bottom = pt.lo, tile = 26 })
		local ik = pr.Kind == "Coins" and "Coin" or pr.Kind == "Gems" and "Gem" or "Bolt"
		local ic = icon(chip, ik, UDim2.new(0, 44, 0, 44), UDim2.new(0, 4, 0.5, -22)); ic.Rotation = -10
		label(chip, pr.Label, UDim2.new(1, -56, 1, -8), UDim2.fromOffset(50, 4), WHITE, { max = 22, align = Enum.TextXAlignment.Left, stroke = 3, strokeColor = pt.bd, extrude = true })
		chips[i] = chip
	end
	local right = frame(content, UDim2.new(0.4, 0, 1, 0), UDim2.new(0.6, 0, 0, 0), nil, "Right")
	label(right, "One free spin every day!", UDim2.new(1, 0, 0, 40), UDim2.new(), Color3.fromRGB(40, 70, 140), { max = 24, stroke = 0, wrap = true })
	icon(right, "Wheel", UDim2.fromOffset(150, 150), UDim2.new(0.5, -75, 0, 44))
	local tbox = frame(right, UDim2.new(1, -8, 0, 46), UDim2.new(0, 4, 1, -132), nil, "Timer"); glass(tbox, 10, { t = 0.3, w = 3 })
	local timer = label(tbox, "", UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 22 })
	local spin = button(right, "SPIN!", UDim2.new(1, -8, 0, 70), UDim2.new(0, 4, 1, -76), C.pink, { max = 40, stroke = 4 })
	spin.Activated:Connect(function()
		if spinning then return end
		spinning = true
		local ok, idx, value = ReplicatedStorage.Remotes.Spin:InvokeServer()
		if not ok then spinning = false; Hud.toast(tostring(idx), "Bad"); return end
		spinWheel3D(idx, 4.5)
		local t0 = os.clock()
		task.spawn(function()
			while os.clock() - t0 < 4.5 do
				local k = math.floor((os.clock() - t0) * (12 - (os.clock() - t0) * 2)) % #chips + 1
				for i, c in ipairs(chips) do if c.Parent then c.BackgroundTransparency = (i == k) and 0 or 0.55 end end
				task.wait(0.05)
			end
			for i, c in ipairs(chips) do if c.Parent then c.BackgroundTransparency = (i == idx) and 0 or 0.6 end end
			local pr = Config.Spin.Prizes[idx]
			local what = pr.Kind == "Coins" and (Format.short(value) .. " Coins") or pr.Kind == "Gems" and (Format.short(value) .. " Gems") or ("+" .. Format.short(value) .. " Power")
			Hud.toast("Daily Spin: you won " .. what .. "!", "Spin")
			Sfx.play("Unlock", 1, 0.6)
			spinning = false
		end)
	end)
	refreshShop = function()
		local left = a("LastSpin", 0) + Config.Spin.Cooldown - os.time()
		if left > 0 then
			timer.Text = string.format("Next spin  %02d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60)
			spin.Label.Text = "Come back later"; paint(spin, C.grey)
		else
			timer.Text = "Ready to spin!"; spin.Label.Text = "SPIN!"; paint(spin, C.pink)
		end
	end
	refreshShop()
end

-- ROBUX STORE: one continuous scroll; sidebar buttons jump to section headings.
local MarketplaceService = game:GetService("MarketplaceService")
local function buildStore()
	local tabs = {
		{ "Gamepasses", "Shop", C.red }, { "Boosts", "BoltBoost", C.purple },
		{ "Coins", "CoinPack2", C.yellow }, { "Gems", "GemPouch", C.pink },
		{ "Codes", Assets.Code and "Code" or "Star", C.blue },
		{ "Free Reward", Assets.GroupReward and "GroupReward" or "Star", C.green },
	}
	-- one scrolling list with a sub title per section (no side tabs)
	local content, _, root = openPanel("Shop", "Shop", 900, 600, nil, C.red)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "StoreScroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.CanvasSize = UDim2.new()
	scroll.Active = true
	styleScroll(scroll)
	scroll.Parent = content
	local sections, offsets = {}, {}
	local nextY = 6
	local function section(index, height)
		local tab = tabs[index]
		offsets[index] = nextY
		local f = frame(scroll, UDim2.new(1, -24, 0, height), UDim2.fromOffset(4, nextY), nil, tab[1] .. "Section")
		sections[index] = f
		nextY += height + 20
		local pal = T(tab[3])
		local heading = frame(f, UDim2.new(1, 0, 0, 40), UDim2.new(), pal[1], "SectionHeader")
		corner(heading, 8); stroke(heading, 3, pal.bd, true)
		skin(heading, pal[1], { radius = 8, tile = 26, top = pal.hi, bottom = pal.lo })
		icon(heading, tab[2], UDim2.fromOffset(42, 42), UDim2.fromOffset(6, -1))
		label(heading, tab[1], UDim2.new(1, -66, 1, -4), UDim2.fromOffset(54, 2), WHITE,
			{ max = 26, align = Enum.TextXAlignment.Left, stroke = 3, strokeColor = pal.bd, extrude = true })
		return f
	end
	local lists = { Config.Store.Gamepasses, Config.Store.Boosts, Config.Store.Coins or {}, Config.Store.Currency }
	-- rows of 2, then 3, then 3...: the first two products in each section get the big cards
	local ROW_BIG, ROW_SMALL = 300, 262
	local function rowsOf(n)
		local rows, left = {}, n
		while left > 0 do
			local k = (#rows == 0) and math.min(2, left) or math.min(3, left)
			table.insert(rows, k); left -= k
		end
		return rows
	end
	for t, list in ipairs(lists) do
		local rows = rowsOf(#list)
		local gridH = 0
		for r, k in ipairs(rows) do gridH += (r == 1 and ROW_BIG or ROW_SMALL) + 12 end
		local f = section(t, 52 + gridH)
		local grid = frame(f, UDim2.new(1, 0, 1, -52), UDim2.fromOffset(0, 52), nil, "Products")
		local idx, y = 0, 0
		for r, k in ipairs(rows) do
			local big = r == 1
			local h = big and ROW_BIG or ROW_SMALL
			for col = 1, k do
				idx += 1
				local item = list[idx]
				local c = card(grid, idx)
				c.Name = "Product" .. idx
				c.Size = UDim2.new(1 / k, -10, 0, h)
				c.Position = UDim2.new((col - 1) / k, (col - 1) * 10 / k, 0, y)
				local it = themeOf(item.Color)
				local head = frame(c, UDim2.new(1, -12, 0, big and 44 or 38), UDim2.fromOffset(6, 6), item.Color, "Head"); corner(head, 8); stroke(head, 3, it.bd, true)
				skin(head, item.Color, { radius = 8, tile = 26, top = it.hi, bottom = it.lo })
				label(head, item.Name, UDim2.new(1, -16, 1, -6), UDim2.fromOffset(8, 3), WHITE, { max = big and 30 or 25, stroke = 3, strokeColor = it.bd, extrude = true })
				local isz = big and 132 or 108
				local ic = icon(c, item.Icon, UDim2.fromOffset(isz, isz), UDim2.new(0.5, -isz / 2, 0, big and 54 or 48)); ic.Rotation = -8
				label(c, item.Desc, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, (big and 54 or 48) + isz + 2), Color3.fromRGB(40, 60, 110), { max = big and 21 or 18, stroke = 0, wrap = true, bold = true })
				local buy = button(c, "R$ " .. item.Robux, UDim2.new(1, -24, 0, big and 48 or 44), UDim2.new(0, 12, 1, big and -58 or -54), C.purple, { max = big and 27 or 25, name = "Buy" })
			local robuxPrice = item.Robux
			-- for now gamepasses cost gems (Config.Store.PassesForGems); tap once, then tap again to confirm
			local forGems = item.Key ~= nil and Config.Store.PassesForGems == true and type(item.Gems) == "number"
			local confirmAt = 0
			local function refreshOwnership()
				if not c.Parent then return end
				local has = item.Key and PassPerks.Has(player, item.Key)
				if has then buy.Label.Text = "Owned"; paint(buy, C.green)
				elseif forGems then
					local confirming = os.clock() < confirmAt
					buy.Label.Text = confirming and "TAP TO CONFIRM" or (Format.commas(item.Gems) .. " Gems")
					paint(buy, confirming and C.yellow or C.blue)
				else buy.Label.Text = "R$ " .. robuxPrice; paint(buy, C.purple) end
			end
			if item.Key then
				refreshOwnership()
				local connection = player:GetAttributeChangedSignal("Pass_" .. item.Key):Connect(refreshOwnership)
				root.Destroying:Connect(function() connection:Disconnect() end)
				if item.PassId > 0 then
					task.spawn(function()
						local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(item.PassId, Enum.InfoType.GamePass) end)
						if ok and info and info.PriceInRobux then robuxPrice = info.PriceInRobux; refreshOwnership() end
					end)
				end
			end
			buy.Activated:Connect(function()
				if item.Key and PassPerks.Has(player, item.Key) then return end
				if forGems then
					if os.clock() >= confirmAt then
						confirmAt = os.clock() + 3; refreshOwnership()
						task.delay(3.05, refreshOwnership)
						return
					end
					confirmAt = 0
					local ok, res = ReplicatedStorage.Remotes.BuyPassGems:InvokeServer(item.Key)
					if ok then Sfx.play("Unlock", 1, 0.6) else Hud.toast(tostring(res), "Bad") end
					refreshOwnership()
					return
				end
				if item.PassId and item.PassId > 0 then
					MarketplaceService:PromptGamePassPurchase(player, item.PassId)
				elseif item.ProductId and item.ProductId > 0 then
					MarketplaceService:PromptProductPurchase(player, item.ProductId)
				else
					Hud.toast(item.Name .. " is coming soon!", "Unlock")
				end
			end)
			end
			y += h + 12
		end
	end
	local codes = section(5, 244)
	local codeCard = frame(codes, UDim2.new(1, 0, 1, -52), UDim2.fromOffset(0, 52), WHITE, "CodeCard")
	corner(codeCard, 12); stroke(codeCard, 3.5, OUT, true); darkSkin(codeCard, { radius = 12 })
	label(codeCard, "Enter a code for free rewards!", UDim2.new(1, -28, 0, 32), UDim2.fromOffset(14, 10), WHITE,
		{ max = 24, align = Enum.TextXAlignment.Left, stroke = 2.5 })
	local inputBack = frame(codeCard, UDim2.new(1, -186, 0, 52), UDim2.fromOffset(14, 55), PANEL_INK, "CodeInputFrame")
	corner(inputBack, 8); stroke(inputBack, 3, C.blue.bd, true)
	local input = Instance.new("TextBox")
	input.Name = "CodeInput"
	input.Size = UDim2.new(1, -20, 1, -8)
	input.Position = UDim2.fromOffset(10, 4)
	input.BackgroundTransparency = 1
	input.FontFace = FACE
	input.TextSize = 24
	input.TextColor3 = WHITE
	input.PlaceholderColor3 = SOFT
	input.PlaceholderText = "Enter code here"
	input.Text = ""
	input.ClearTextOnFocus = false
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.TextTruncate = Enum.TextTruncate.AtEnd
	input.Parent = inputBack
	local redeem = button(codeCard, "Redeem", UDim2.fromOffset(144, 48), UDim2.new(1, -158, 0, 55), C.green, { max = 25, name = "Redeem" })
	local feedback = label(codeCard, "", UDim2.new(1, -28, 0, 58), UDim2.fromOffset(14, 119), SOFT,
		{ max = 19, align = Enum.TextXAlignment.Left, stroke = 0, wrap = true, bold = true })
	feedback.Name = "CodeFeedback"
	local busy = false
	local function submit()
		if busy then return end
		local code = input.Text:match("^%s*(.-)%s*$") or ""
		if code == "" then feedback.Text = "Enter a code first."; feedback.TextColor3 = SOFT; return end
		if #code > 64 then feedback.Text = "That code is too long."; feedback.TextColor3 = SOFT; return end
		busy = true
		redeem.Label.Text = "Checking..."
		feedback.Text = ""
		local ok, success, message = pcall(function()
			return ReplicatedStorage.Remotes.RedeemCode:InvokeServer(code)
		end)
		if codeCard.Parent then
			busy = false
			redeem.Label.Text = "Redeem"
			feedback.Text = ok and tostring(message or "Please try again.") or "Couldn't connect. Please try again."
			feedback.TextColor3 = ok and success and MINT or SOFT
			if ok and success then input.Text = ""; Hud.toast(message, "Unlock") end
		end
	end
	redeem.Activated:Connect(submit)
	input.FocusLost:Connect(function(enterPressed) if enterPressed then submit() end end)
	-- The server verifies membership. Likes remain an optional request.
	local gr = Config.GroupReward or {}
	local groupSec = section(6, 52 + 196)
	local grCard = frame(groupSec, UDim2.new(1, 0, 1, -52), UDim2.fromOffset(0, 52), WHITE, "GroupCard")
	corner(grCard, 12); stroke(grCard, 3.5, OUT, true); darkSkin(grCard, { radius = 12 })
	local grIcon = icon(grCard, Assets.GroupReward and "GroupReward" or "Star", UDim2.fromOffset(150, 150), UDim2.fromOffset(14, 20))
	grIcon.Name = "GroupIcon"
	label(grCard, "Join our group for free Gems!", UDim2.new(1, -200, 0, 34), UDim2.fromOffset(180, 16), WHITE,
		{ max = 26, align = Enum.TextXAlignment.Left, stroke = 2.5 })
	local parts = {}
	if (gr.Gems or 0) > 0 then table.insert(parts, Format.commas(gr.Gems) .. " Gems") end
	if (gr.Coins or 0) > 0 then table.insert(parts, Format.commas(gr.Coins) .. " Coins") end
	label(grCard, "Reward: " .. (#parts > 0 and table.concat(parts, " + ") or "???"), UDim2.new(1, -200, 0, 28), UDim2.fromOffset(180, 52), MINT,
		{ max = 22, align = Enum.TextXAlignment.Left, stroke = 2.5 })
	local grFeedback = label(grCard, "One-time reward. Likes are appreciated!", UDim2.new(1, -200, 0, 26), UDim2.fromOffset(180, 84), SOFT,
		{ max = 18, align = Enum.TextXAlignment.Left, stroke = 0, wrap = true, bold = true })
	grFeedback.Name = "GroupFeedback"
	local enabled = (gr.GroupId or 0) > 0
	local joinBtn = button(grCard, "Join Group", UDim2.fromOffset(190, 50), UDim2.fromOffset(180, 122), C.blue, { max = 24, name = "JoinGroup" })
	local claimBtn = button(grCard, "Claim", UDim2.fromOffset(170, 50), UDim2.fromOffset(384, 122), C.green, { max = 25, name = "ClaimGroup" })
	local claimed = Players.LocalPlayer:GetAttribute("GroupReward") == true
	if claimed then
		claimBtn.Label.Text = "Claimed"; paint(claimBtn, C.grey); joinBtn.Parent.Visible = false; claimBtn.Parent.Position = UDim2.fromOffset(180, 122)
		grFeedback.Text = "Thank you for joining the group! Reward claimed."; grFeedback.TextColor3 = MINT
	elseif not enabled then
		grFeedback.Text = "The group reward is not configured yet."
	end
	joinBtn.Activated:Connect(function()
		if not enabled then grFeedback.Text = "Coming soon!"; return end
		task.spawn(function()
			local ok = pcall(function() game:GetService("GroupService"):PromptJoinAsync(gr.GroupId) end)
			if not ok and grCard.Parent then grFeedback.Text = "Search the group on Roblox and join it, then claim!" end
		end)
	end)
	local grBusy = false
	claimBtn.Activated:Connect(function()
		if grBusy or claimed then return end
		grBusy = true
		claimBtn.Label.Text = "Checking..."
		local ok, success, message = pcall(function()
			return ReplicatedStorage.Remotes.ClaimGroupReward:InvokeServer()
		end)
		grBusy = false
		if not grCard.Parent then return end
		claimBtn.Label.Text = (ok and success) and "Claimed" or "Claim"
		grFeedback.Text = ok and tostring(message or "Please try again.") or "Couldn't connect. Please try again."
		grFeedback.TextColor3 = ok and success and MINT or SOFT
		if ok and success then
			claimed = true; joinBtn.Parent.Visible = false; paint(claimBtn, C.grey); claimBtn.Parent.Position = UDim2.fromOffset(180, 122)
			Hud.toast(message, "Unlock")
		end
	end)
	-- CanvasPosition and AbsoluteCanvasSize use rendered pixels, including every ancestor UIScale.
	local canvasHeight = nextY - 20 + 12
	scroll.CanvasSize = UDim2.fromOffset(0, canvasHeight)
end

-- REWARDS: Play-time (top) + Daily Day 1-7 (bottom), one scrolling list. Both reset every Monday 00:00 UTC.
local function rewardsData()
	local ok, t = pcall(function() return HttpService:JSONDecode(a("Rewards", "{}")) end)
	if not ok or type(t) ~= "table" or not t.at then return nil end
	return t
end
local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 86400 then return string.format("%dd %dh", sec // 86400, (sec % 86400) // 3600) end
	if sec >= 3600 then return string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60) end
	return string.format("%02d:%02d", sec // 60, sec % 60)
end
-- how many rewards can be claimed right now (for the red badge)
local function rewardsReady()
	local d = rewardsData()
	if not d then return 0 end
	local now = workspace:GetServerTimeNow()
	local play = d.playSec + math.max(0, now - d.at)
	local n = 0
	for i, mins in ipairs(Config.Rewards.Playtime) do
		if not (d.claimed and d.claimed[tostring(i)]) and play >= mins * 60 then n += 1 end
	end
	if d.daily < Config.Rewards.DailyDays and d.nextDaily <= now then n += 1 end
	return n
end
Hud.rewardsReady = rewardsReady
local function buildRewards()
	local content, _, root = openPanel("Rewards", Assets.Rewards and "Rewards" or "Star", 900, 640, nil, C.green)
	local scroll = Instance.new("ScrollingFrame"); scroll.Size = UDim2.fromScale(1, 1); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
	styleScroll(scroll); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(); scroll.Parent = content
	local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 12); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = scroll
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 4); pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 16); pad.PaddingBottom = UDim.new(0, 12); pad.Parent = scroll
	local order = 0
	local function section(title, pal)
		order += 1
		local head = frame(scroll, UDim2.new(1, 0, 0, 50), UDim2.new(), pal[1], title .. "Header"); head.LayoutOrder = order
		corner(head, 10); stroke(head, 3.5, pal.bd, true)
		skin(head, pal[1], { radius = 10, top = pal.hi, bottom = pal.lo, tile = 26 })
		label(head, title, UDim2.new(0.6, -16, 1, -8), UDim2.fromOffset(14, 4), WHITE, { max = 30, align = Enum.TextXAlignment.Left, stroke = 3.5, strokeColor = pal.bd, extrude = true })
		local _, resetTxt = pill(head, "", UDim2.fromOffset(230, 32), UDim2.new(1, -127, 0.5, 0))
		order += 1
		local grid = frame(scroll, UDim2.new(1, 0, 0, 0), UDim2.new(), nil, title .. "Grid"); grid.AutomaticSize = Enum.AutomaticSize.Y; grid.LayoutOrder = order
		local gl = Instance.new("UIGridLayout"); gl.CellSize = UDim2.new(0.25, -9, 0, 236); gl.CellPadding = UDim2.fromOffset(10, 10)
		gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = grid
		return grid, resetTxt
	end
	-- every reward shows what you get: an icon (coins / gems / power, bigger packs for bigger prizes) and the amount
	local function prizeIcon(prize)
		local tier = prize.Kind == "Gems" and (prize.Amount >= 40 and 4 or prize.Amount >= 20 and 3 or prize.Amount >= 10 and 2 or 1)
			or (prize.Amount >= 0.2 and 4 or prize.Amount >= 0.15 and 3 or prize.Amount >= 0.1 and 2 or 1)
		if prize.Kind == "Coins" then return Assets["CoinPack" .. tier] and ("CoinPack" .. tier) or "Coin"
		elseif prize.Kind == "Gems" then return Assets["GemPack" .. tier] and ("GemPack" .. tier) or "Gem"
		else return Assets.BoltBoost and "BoltBoost" or "Bolt" end
	end
	local function prizeText(prize)
		local v = Config.PrizeValue(prize, a("ZoneUnlocked", 1), a("Power", 1))
		if prize.Kind == "Coins" then return "+" .. Format.short(v) .. " Coins"
		elseif prize.Kind == "Gems" then return "+" .. Format.commas(v) .. " Gems"
		else return "+" .. Format.short(v) .. " Power" end
	end
	local function rewardCard(grid, i, title, prize)
		local c = card(grid, i)
		label(c, title, UDim2.new(1, -12, 0, 32), UDim2.fromOffset(6, 8), WHITE, { max = 26, stroke = 3, extrude = true })
		if prize then
			local ic = icon(c, prizeIcon(prize), UDim2.fromOffset(78, 78), UDim2.new(0.5, -39, 0, 40)); ic.Rotation = -8
			local col = prize.Kind == "Coins" and GOLD or (prize.Kind == "Gems" and rgb(130, 220, 255) or rgb(170, 255, 120))
			local amt = label(c, prizeText(prize), UDim2.new(1, -12, 0, 26), UDim2.fromOffset(6, 120), col, { max = 20, stroke = 2.5 })
			amt.Name = "Amount"
		end
		local timer = label(c, "", UDim2.new(1, -12, 0, 26), UDim2.fromOffset(6, 146), SOFT, { max = 20, stroke = 2.5 })
		local holder = frame(c, UDim2.new(1, -20, 0, 50), UDim2.new(0, 10, 1, -62), nil, "ClaimHolder")
		local b = button(holder, "CLAIM", UDim2.new(1, 0, 1, -6), UDim2.new(), C.grey, { max = 22 })
		return { card = c, timer = timer, button = b, state = "" }
	end
	local playGrid, playReset = section("Play-time Rewards", C.blue)
	local dailyGrid, dailyReset = section("Daily Rewards", C.yellow)
	local plays, days = {}, {}
	for i, mins in ipairs(Config.Rewards.Playtime) do plays[i] = rewardCard(playGrid, i, mins .. " Min", Config.Rewards.PlayPrizes[i]) end
	for d = 1, Config.Rewards.DailyDays do days[d] = rewardCard(dailyGrid, d, "Day " .. d, Config.Rewards.DailyPrizes[d]) end
	local busy = false
	local function claim(kind, idx)
		if busy then return end
		busy = true
		local ok, res = ReplicatedStorage.Remotes.ClaimReward:InvokeServer(kind, idx)
		busy = false
		if ok then Sfx.play("Upgrade", 1.1, 0.5); Hud.toast(tostring(res), "Unlock") else Hud.toast(tostring(res), "Bad") end
	end
	for i, r in ipairs(plays) do r.button.Activated:Connect(function() if r.state == "ready" then claim("play", i) end end) end
	for d, r in ipairs(days) do r.button.Activated:Connect(function() if r.state == "ready" then claim("daily", d) end end) end
	local function setState(r, st, timerText, timerColor)
		r.timer.Text = timerText
		r.timer.TextColor3 = timerColor or SOFT
		if r.state == st then return end
		r.state = st
		local lbl = r.button:FindFirstChild("Label")
		if st == "ready" then lbl.Text = "CLAIM"; paint(r.button, C.green)
		elseif st == "claimed" then lbl.Text = "CLAIMED"; paint(r.button, C.blue)
		else lbl.Text = "LOCKED"; paint(r.button, C.grey) end
	end
	local function update()
		local d = rewardsData()
		if not d then return end
		local now = workspace:GetServerTimeNow()
		local left = d.weekEnd - now
		playReset.Text = "Resets in " .. fmtTime(left)
		dailyReset.Text = "Resets in " .. fmtTime(left)
		local play = d.playSec + math.max(0, now - d.at)
		for i, mins in ipairs(Config.Rewards.Playtime) do
			local r = plays[i]
			if d.claimed and d.claimed[tostring(i)] then setState(r, "claimed", "Claimed!", MINT)
			elseif play >= mins * 60 then setState(r, "ready", "Ready!", GOLD)
			else setState(r, "locked", fmtTime(mins * 60 - play)) end
		end
		for day, r in ipairs(days) do
			if day <= d.daily then setState(r, "claimed", "Claimed!", MINT)
			elseif day == d.daily + 1 then
				if d.nextDaily <= now then setState(r, "ready", "Ready!", GOLD)
				else setState(r, "locked", fmtTime(d.nextDaily - now)) end
			else setState(r, "locked", "Locked") end
		end
	end
	update()
	refreshShop = update
	task.spawn(function()
		while root.Parent do update(); task.wait(0.25) end
	end)
end

-- SETTINGS (top-right gear): on/off switches, saved with your data
local function buildSettings()
	local content = openPanel("Settings", Assets.Settings and "Settings" or "Star", 640, 470, nil, C.blue)
	local list = Instance.new("ScrollingFrame"); list.Size = UDim2.fromScale(1, 1); list.BackgroundTransparency = 1; list.BorderSizePixel = 0
	styleScroll(list); list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.CanvasSize = UDim2.new(); list.Parent = content
	local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 10); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = list
	local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 4); pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 14); pad.Parent = list
	local rows = {}
	for i, st in ipairs(SettingsData.List) do
		local c = frame(list, UDim2.new(1, 0, 0, 78), UDim2.new(), WHITE, st.Id); c.LayoutOrder = i
		corner(c, 12); stroke(c, 3.5, OUT, true); darkSkin(c, { radius = 12 })
		label(c, st.Name, UDim2.new(1, -170, 0, 32), UDim2.fromOffset(14, 8), WHITE, { max = 24, align = Enum.TextXAlignment.Left, stroke = 3, extrude = true })
		label(c, st.Desc, UDim2.new(1, -170, 0, 26), UDim2.fromOffset(14, 42), SOFT, { max = 16, align = Enum.TextXAlignment.Left, stroke = 2, bold = true, wrap = true })
		local holder = frame(c, UDim2.fromOffset(130, 52), UDim2.new(1, -144, 0, 10), nil, "ToggleHolder")
		local b = button(holder, "ON", UDim2.new(1, 0, 1, -6), UDim2.new(), C.green, { max = 24 })
		rows[st.Id] = b
		b.Activated:Connect(function()
			local new = not SettingsData.Get(player, st.Id)
			ReplicatedStorage.Remotes.SetSetting:FireServer(st.Id, new)
			-- show it straight away; the server confirms through the Settings attribute
			b.Label.Text = new and "ON" or "OFF"; paint(b, new and C.green or C.red)
		end)
	end
	-- Auto Delete: tick a rarity and every pet of it you hatch is deleted straight away (Secret pets never are)
	local ad = frame(list, UDim2.new(1, 0, 0, 184), UDim2.new(), WHITE, "AutoDelete"); ad.LayoutOrder = #SettingsData.List + 1
	corner(ad, 12); stroke(ad, 3.5, OUT, true); darkSkin(ad, { radius = 12 })
	label(ad, "Auto Delete", UDim2.new(1, -28, 0, 32), UDim2.fromOffset(14, 8), WHITE, { max = 24, align = Enum.TextXAlignment.Left, stroke = 3, extrude = true })
	label(ad, "Pets you hatch of the rarities you tick are deleted straight away.", UDim2.new(1, -28, 0, 26), UDim2.fromOffset(14, 42), SOFT, { max = 16, align = Enum.TextXAlignment.Left, stroke = 2, bold = true, wrap = true })
	local chips = {}
	for i, r in ipairs(SettingsData.AutoDelete) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local holder = frame(ad, UDim2.new(1 / 3, -14, 0, 52), UDim2.new(col / 3, 10, 0, 74 + row * 54), nil, "Chip" .. r)
		local b = button(holder, r, UDim2.new(1, 0, 1, -6), UDim2.new(), C.grey, { max = 20 })
		local tick = icon(b, "Check", UDim2.fromOffset(26, 26), UDim2.new(1, -30, 0, 4)); tick.ZIndex = (b.ZIndex or 1) + 5
		chips[r] = { b = b, tick = tick }
		b.Activated:Connect(function()
			local id = "Del_" .. r
			local new = not SettingsData.Get(player, id)
			ReplicatedStorage.Remotes.SetSetting:FireServer(id, new)
			paint(b, new and themeOf(PetData.Rarities[r].Color) or C.grey); tick.Visible = new
		end)
	end
	refreshShop = function()
		for id, b in pairs(rows) do
			local on = SettingsData.Get(player, id)
			b.Label.Text = on and "ON" or "OFF"; paint(b, on and C.green or C.red)
		end
		for r, ch in pairs(chips) do
			local on = SettingsData.Get(player, "Del_" .. r)
			paint(ch.b, on and themeOf(PetData.Rarities[r].Color) or C.grey); ch.tick.Visible = on
		end
	end
	refreshShop()
end

-- ADMIN PANEL (owner + developers only; the server re-checks every action)
local ADMIN_TABS = { { "Stats", "Coin", C.orange }, { "Items", "Star", C.pink }, { "Tools", "Check", C.green }, { "Events", "Star", C.purple } }
local adminTab = 1
local adminTargetId = nil -- nil = yourself
local ADMIN_STATS = {
	{ "Coins", "Coins", "Coin" }, { "Gems", "Gems", "Gem" }, { "Power", "Vacuum Power", "Bolt" },
	{ "Rebirths", "Rebirths", "Rebirth" }, { "ZoneUnlocked", "Zones Unlocked", "Island" },
	{ "BackpackLv", "Backpack Level", "Backpack" }, { "WalkLv", "Walk Speed Level", "Shoe" }, { "CoinLv", "Coin Multiplier Level", "Coins" },
}
local function adminTarget()
	local t = adminTargetId and Players:GetPlayerByUserId(adminTargetId)
	if not t then adminTargetId = nil; t = player end
	return t
end
local function adminCall(action, a1, a2, a3)
	local t = adminTarget()
	local ok, success, msg = pcall(function()
		return ReplicatedStorage.Remotes.AdminAction:InvokeServer(action, t.UserId, a1, a2, a3)
	end)
	if not ok then Hud.toast("Couldn't reach the server", "Bad"); return false end
	Hud.toast(tostring(msg), success and "Unlock" or "Bad")
	if success then Sfx.play("Upgrade", 1.1, 0.4) end
	return success
end
local function adminInput(parent, size, pos, placeholder, text)
	local back = frame(parent, size, pos, PANEL_INK, "InputBack"); corner(back, 8); stroke(back, 3, C.blue.bd, true); back.ZIndex = 5
	local box = Instance.new("TextBox"); box.Name = "Input"; box.Size = UDim2.new(1, -16, 1, -6); box.Position = UDim2.fromOffset(8, 3)
	box.BackgroundTransparency = 1; box.FontFace = FACE; box.TextScaled = true; box.TextColor3 = WHITE; box.PlaceholderColor3 = SOFT
	box.PlaceholderText = placeholder or ""; box.Text = text or ""; box.ClearTextOnFocus = false; box.ZIndex = 6
	box.TextXAlignment = Enum.TextXAlignment.Left; box.Parent = back
	local c = Instance.new("UITextSizeConstraint"); c.MaxTextSize = 24; c.Parent = box
	return box
end
local function adminPetView(parent, id, size, pos)
	if PetData.Icons and PetData.Icons[id] then return petView(parent, id, size, pos) end
	local vp = Instance.new("ViewportFrame"); vp.BackgroundTransparency = 1; vp.Size = size; vp.Position = pos; vp.ZIndex = 6
	vp.LightColor = WHITE; vp.Ambient = Color3.fromRGB(175, 175, 175); vp.LightDirection = Vector3.new(-1, -1.4, -1); vp.Parent = parent
	local src = ReplicatedStorage:FindFirstChild("PetModels") and ReplicatedStorage.PetModels:FindFirstChild(id)
	if not src then return vp end
	local m = src:Clone(); m.Parent = vp
	local cf, sz = m:GetBoundingBox()
	local d = math.max(sz.X, sz.Y, sz.Z) * 2.2
	local cam = Instance.new("Camera"); cam.FieldOfView = 30; cam.Parent = vp; vp.CurrentCamera = cam
	cam.CFrame = CFrame.lookAt(cf.Position + cf.LookVector * d + cf.RightVector * d * 0.45 + Vector3.new(0, d * 0.3, 0), cf.Position)
	return vp
end
local function buildAdmin()
	local content, tabButtons, root = openPanel("Admin Panel", Assets.Admin and "Admin" or "Star", 1020, 640, ADMIN_TABS, C.blue)
	-- who you're editing: < name >
	local bar = frame(content, UDim2.new(1, -14, 0, 56), UDim2.fromOffset(4, 0), nil, "Target")
	local prev = button(bar, "<", UDim2.fromOffset(56, 48), UDim2.fromOffset(0, 2), C.blue, { max = 30, name = "Prev" })
	local nxt = button(bar, ">", UDim2.fromOffset(56, 48), UDim2.new(1, -56, 0, 2), C.blue, { max = 30, name = "Next" })
	local nameBack = frame(bar, UDim2.new(1, -136, 0, 48), UDim2.fromOffset(68, 2), WHITE, "Who"); corner(nameBack, 10); stroke(nameBack, 3, OUT, true); darkSkin(nameBack, { radius = 10 })
	local who = label(nameBack, "", UDim2.new(1, -16, 1, -6), UDim2.fromOffset(8, 3), WHITE, { max = 24, stroke = 2.5, rich = true })
	local body = frame(content, UDim2.new(1, 0, 1, -66), UDim2.fromOffset(0, 66), nil, "AdminBody")
	local updaters, targetConn = {}, nil
	local render
	local function refreshValues() for _, u in ipairs(updaters) do u() end end
	local function setTarget(dir)
		local list = Players:GetPlayers()
		table.sort(list, function(x, y) if x == player then return true elseif y == player then return false end return x.Name < y.Name end)
		local idx = table.find(list, adminTarget()) or 1
		if dir then idx = (idx - 1 + dir) % #list + 1; adminTargetId = list[idx] ~= player and list[idx].UserId or nil end
		local t = adminTarget()
		who.Text = (t == player and "Editing: <font color=\"#7dff6a\">You</font>" or ("Editing: <font color=\"#ffd23f\">" .. t.DisplayName .. "</font>")) .. "  (@" .. t.Name .. ")"
		if targetConn then targetConn:Disconnect() end
		targetConn = t.AttributeChanged:Connect(function() refreshValues() end)
		refreshValues()
	end
	-- only real developers can edit other players; everyone else edits themselves (the server enforces this too)
	local canTarget = player:GetAttribute("IsDeveloper") == true
	prev.Visible = canTarget; nxt.Visible = canTarget
	if not canTarget then adminTargetId = nil end
	prev.Activated:Connect(function() if canTarget then setTarget(-1); render() end end)
	nxt.Activated:Connect(function() if canTarget then setTarget(1); render() end end)
	root.Destroying:Connect(function() if targetConn then targetConn:Disconnect() end end)

	local function statsTab()
		local list = scroller(body, 74, 1)
		for i, st in ipairs(ADMIN_STATS) do
			local c = card(list, i)
			local ic = icon(c, st[3], UDim2.fromOffset(56, 56), UDim2.fromOffset(10, 9)); ic.ZIndex = 6
			if st[3] == "Bolt" then tagVac(ic) end
			label(c, st[2], UDim2.new(1, -470, 0, 30), UDim2.fromOffset(74, 6), WHITE, { max = 22, align = Enum.TextXAlignment.Left, stroke = 2.5 })
			local val = label(c, "0", UDim2.new(1, -470, 0, 26), UDim2.fromOffset(74, 38), GOLD, { max = 20, align = Enum.TextXAlignment.Left, stroke = 2.5 })
			local box = adminInput(c, UDim2.fromOffset(170, 48), UDim2.new(1, -386, 0, 13), "e.g. 1m")
			local set = button(c, "SET", UDim2.fromOffset(96, 48), UDim2.new(1, -206, 0, 10), C.green, { max = 24 })
			local add = button(c, "ADD", UDim2.fromOffset(96, 48), UDim2.new(1, -104, 0, 10), C.blue, { max = 24 })
			table.insert(updaters, function()
				local v = adminTarget():GetAttribute(st[1]) or 0
				val.Text = (type(v) == "number" and v >= 1e6) and (Format.short(v) .. "  (" .. Format.commas(v) .. ")") or Format.commas(tonumber(v) or 0)
			end)
			local function go(mode)
				if box.Text == "" then Hud.toast("Type an amount first (use a - with ADD to take away)", "Bad"); return end
				adminCall("stat", st[1], mode, box.Text)
			end
			set.Activated:Connect(function() go("set") end)
			add.Activated:Connect(function() go("add") end)
		end
	end
	local function itemsTab()
		local top = frame(body, UDim2.new(1, -14, 0, 50), UDim2.fromOffset(4, 0), nil, "Amount")
		label(top, "Amount per tap:", UDim2.fromOffset(200, 48), UDim2.new(), WHITE, { max = 22, align = Enum.TextXAlignment.Left, stroke = 2.5 })
		local amount = adminInput(top, UDim2.fromOffset(150, 46), UDim2.fromOffset(204, 1), "1", "1")
		label(top, "+ gives, - takes away", UDim2.new(1, -380, 0, 46), UDim2.fromOffset(370, 1), SOFT, { max = 18, align = Enum.TextXAlignment.Left, stroke = 2, bold = true })
		local s = Instance.new("ScrollingFrame"); s.Size = UDim2.new(1, 0, 1, -58); s.Position = UDim2.fromOffset(0, 58); s.BackgroundTransparency = 1; s.BorderSizePixel = 0
		styleScroll(s); s.AutomaticCanvasSize = Enum.AutomaticSize.Y; s.CanvasSize = UDim2.new(); s.Parent = body
		local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 10); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = s
		local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 4); pad.PaddingRight = UDim.new(0, 14); pad.PaddingBottom = UDim.new(0, 10); pad.Parent = s
		local order = 0
		local function heading(text)
			order += 1
			local hf = frame(s, UDim2.new(1, 0, 0, 36), UDim2.new(), nil, "Heading"); hf.LayoutOrder = order
			label(hf, text, UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 26, align = Enum.TextXAlignment.Left, stroke = 3, extrude = true })
		end
		local function grid()
			order += 1
			local g = frame(s, UDim2.new(1, 0, 0, 0), UDim2.new(), nil, "Grid"); g.AutomaticSize = Enum.AutomaticSize.Y; g.LayoutOrder = order
			local gl = Instance.new("UIGridLayout"); gl.CellSize = UDim2.new(0.25, -10, 0, 196); gl.CellPadding = UDim2.fromOffset(10, 10)
			gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = g
			return g
		end
		local function itemCard(g, i, title, pal, countFn, action, arg, drawIcon)
			local c = card(g, i)
			skin(c, pal[1], { radius = 12, top = pal.hi, bottom = pal.lo })
			drawIcon(c)
			label(c, title, UDim2.new(1, -8, 0, 26), UDim2.fromOffset(4, 104), WHITE, { max = 17, stroke = 2.5, strokeColor = pal.bd, wrap = true })
			local cnt = label(c, "x0", UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 128), GOLD, { max = 17, stroke = 2.5 })
			table.insert(updaters, function() cnt.Text = "x" .. Format.commas(countFn()) end)
			local minus = button(c, "-", UDim2.new(0.5, -12, 0, 36), UDim2.new(0, 8, 1, -46), C.red, { max = 26 })
			local plus = button(c, "+", UDim2.new(0.5, -12, 0, 36), UDim2.new(0.5, 4, 1, -46), C.green, { max = 26 })
			plus.Activated:Connect(function() adminCall(action, arg, amount.Text ~= "" and amount.Text or "1") end)
			minus.Activated:Connect(function() adminCall(action, arg, "-" .. (amount.Text ~= "" and amount.Text:gsub("^%-", "") or "1")) end)
		end
		local function decode(attr)
			local ok, t = pcall(function() return HttpService:JSONDecode(adminTarget():GetAttribute(attr) or "{}") end)
			return ok and type(t) == "table" and t or {}
		end
		heading("Eggs")
		local eg = grid()
		for z = 1, #Config.Zones do
			local key = z .. "_Basic"
			local pal = themeOf((Config.Zones[z] and Config.Zones[z].Accent) or C.blue[1])
			itemCard(eg, z, Config.Eggs.Names[z] or ("Egg " .. z), pal, function() return decode("EggItems")[key] or 0 end, "giveEgg", z,
				function(c) EggIcon.make(c, key, UDim2.new(1, -40, 0, 96), UDim2.fromOffset(20, 6)) end)
		end
		heading("Pets")
		local pg = grid()
		for i, p in ipairs(PetData.Pets) do
			local pal = themeOf(PetData.Rarities[p.Rarity].Color)
			itemCard(pg, i, p.Name, pal, function() return decode("PetItems")[p.Id] or 0 end, "givePet", p.Id,
				function(c) adminPetView(c, p.Id, UDim2.new(1, -20, 0, 98), UDim2.fromOffset(10, 4)) end)
		end
		local EvC = require(ReplicatedStorage.Shared.EventConfig)
		local function img(c, image)
			local il = Instance.new("ImageLabel"); il.BackgroundTransparency = 1; il.ScaleType = Enum.ScaleType.Fit; il.Image = image or ""
			il.Size = UDim2.new(1, -40, 0, 96); il.Position = UDim2.fromOffset(20, 6); il.ZIndex = 6; il.Parent = c
			return il
		end
		-- boss + event currencies
		heading("Event Currency")
		local cg = grid()
		for i, k in ipairs(EvC.ItemOrder) do
			local it = EvC.Items[k]
			itemCard(cg, i, it.Name, themeOf(it.Color or C.blue[1]), function() return decode("EventItems")[k] or 0 end, "giveEventItem", k,
				function(c) img(c, EvC.Images[k]) end)
		end
		-- enchant chests (go into the bag's Items tab)
		heading("Enchant Chests")
		local chg = grid()
		for i, k in ipairs({ "Kraken", "Void" }) do
			local ch = EnchantConfig.Chests[k]
			itemCard(chg, i, ch.Name, themeOf(ch.Color), function() return decode("Chests")[k] or 0 end, "giveChest", k,
				function(c) img(c, ch.Image) end)
		end
		-- enchants: + gives, - removes (you can only own one of each)
		heading("Enchants")
		local enG = grid()
		for i, e in ipairs(EnchantConfig.List) do
			itemCard(enG, i, e.Name .. " (" .. e.Rarity .. ")", themeOf(EnchantConfig.Rarities[e.Rarity].Color), function()
				local ok, t = pcall(function() return HttpService:JSONDecode(adminTarget():GetAttribute("Enchants") or "[]") end)
				return (ok and type(t) == "table" and table.find(t, e.Id)) and 1 or 0
			end, "giveEnchant", e.Id, function(c)
				local il = img(c, ""); EnchantConfig.ApplyIcon(il, e.Id)
			end)
		end
	end
	local function toolsTab()
		local list = scroller(body, 120, 3)
		local tools = {
			{ "Unlock All Zones", "Island", C.green, "unlockZones" },
			{ "Max Upgrades", "Backpack", C.orange, "maxUpgrades" },
			{ "Unlock All Vacuums", "Vac8", C.purple, "allVacuums" },
			{ "Reset Daily Spin", "Wheel", C.blue, "resetSpin" },
			{ "Reset Daily Chest", "Star", C.yellow, "resetChest" },
			{ "Empty Backpack", "LootBox", C.grey, "emptyBackpack" },
			{ "Remove All Pets", "Close", C.red, "clearPets" },
			{ "Remove All Eggs", "Close", C.red, "clearEggs" },
			{ "Give All Enchants", "Enchant", C.purple, "allEnchants" },
			{ "Remove All Enchants", "Close", C.red, "clearEnchants" },
			{ "Reset Progress", "Rebirth", C.red, "resetProgress", true },
		}
		for i, t in ipairs(tools) do
			local c = card(list, i)
			local ic = icon(c, t[2], UDim2.fromOffset(60, 60), UDim2.fromOffset(10, 8)); ic.Rotation = -8; ic.ZIndex = 6
			label(c, t[1], UDim2.new(1, -84, 0, 60), UDim2.fromOffset(76, 8), WHITE, { max = 20, align = Enum.TextXAlignment.Left, stroke = 2.5, wrap = true })
			local b = button(c, t[5] and "RESET" or "DO IT", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 1, -50), t[3], { max = 22 })
			local armed = 0
			b.Activated:Connect(function()
				if t[5] then
					if os.clock() - armed > 3 then
						armed = os.clock(); b.Label.Text = "TAP AGAIN"
						Hud.toast("This wipes " .. (adminTarget() == player and "your" or (adminTarget().DisplayName .. "'s")) .. " progress. Tap again to confirm.", "Bad")
						task.delay(3, function() if b.Parent and os.clock() - armed >= 3 then b.Label.Text = "RESET" end end)
						return
					end
					armed = 0; b.Label.Text = "RESET"
				end
				adminCall(t[4])
			end)
		end
	end
	-- World Events: start any event instantly (server-wide), or stop the one that's running
	local function eventsTab()
		local E = require(ReplicatedStorage.Shared.EventConfig)
		local icons = ReplicatedStorage:FindFirstChild("EventAssets") and ReplicatedStorage.EventAssets:FindFirstChild("Icons")
		local ICON = { Kraken = "KrakenScale", VoidDragon = "VoidShard", Meteor = "CosmicCore", Crystal = "BlueCrystal", Stars = "StarRainbow" }
		local status = frame(body, UDim2.new(1, -14, 0, 40), UDim2.fromOffset(4, 0), nil, "Status")
		local st = label(status, "", UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 22, align = Enum.TextXAlignment.Left, stroke = 2.5, rich = true })
		local function refreshStatus()
			local id = ReplicatedStorage:GetAttribute("EventId")
			if id then
				local left = math.max(0, math.floor((ReplicatedStorage:GetAttribute("EventEndsAt") or 0) - workspace:GetServerTimeNow()))
				st.Text = string.format("Running now: <font color=\"#ffd23f\">%s</font>  (%d:%02d left)", E.Events[id].Name, left // 60, left % 60)
			else
				st.Text = "No event running. Starting one here starts it for the whole server."
			end
		end
		table.insert(updaters, refreshStatus)
		local holder = frame(body, UDim2.new(1, 0, 1, -48), UDim2.fromOffset(0, 48), nil, "Grid")
		local list = scroller(holder, 170, 3)
		local function startCall(id)
			local rf = ReplicatedStorage.Remotes:FindFirstChild("EventAction")
			if not rf then return end
			local ok, msg = rf:InvokeServer("Start", id)
			if not ok and msg then Hud.toast(msg, "Bad") end
			task.wait(0.3); refreshStatus()
		end
		for i, id in ipairs(E.Order) do
			local info = E.Events[id]
			local c = card(list, i)
			local vp = Instance.new("ViewportFrame"); vp.BackgroundTransparency = 1; vp.Size = UDim2.fromOffset(78, 78); vp.Position = UDim2.fromOffset(6, 6)
			vp.Ambient = Color3.fromRGB(200, 200, 210); vp.LightColor = WHITE; vp.LightDirection = Vector3.new(-1, -1.4, -0.6); vp.ZIndex = 6; vp.Parent = c
			local src = icons and icons:FindFirstChild(ICON[id])
			local img = E.Images and E.Images["Event_" .. id]
			if img then -- the event's 2D icon
				local il = Instance.new("ImageLabel"); il.BackgroundTransparency = 1; il.Size = UDim2.fromScale(1, 1); il.Image = img
				il.ScaleType = Enum.ScaleType.Fit; il.ZIndex = vp.ZIndex; il.Parent = vp
			elseif src then
				local m = src:Clone(); m.Parent = vp
				local cf, sz = m:GetBoundingBox()
				local cam = Instance.new("Camera"); cam.FieldOfView = 30; cam.Parent = vp
				cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.5, 0.45, -1).Unit * sz.Magnitude * 1.85, cf.Position)
				vp.CurrentCamera = cam
			end
			label(c, info.Name, UDim2.new(1, -96, 0, 34), UDim2.fromOffset(88, 8), WHITE, { max = 22, align = Enum.TextXAlignment.Left, stroke = 2.5, wrap = true })
			label(c, (info.Boss and "World Boss" or "World Event") .. " - " .. math.floor(info.Duration / 60) .. " min", UDim2.new(1, -96, 0, 26), UDim2.fromOffset(88, 44), SOFT, { max = 17, align = Enum.TextXAlignment.Left, stroke = 2, bold = true })
			local b = button(c, "START NOW", UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 1, -54), themeOf(info.Color), { max = 22 })
			b.Activated:Connect(function() startCall(id) end)
		end
		local c = card(list, #E.Order + 1)
		local ic = icon(c, "Close", UDim2.fromOffset(60, 60), UDim2.fromOffset(12, 12)); ic.ZIndex = 6
		label(c, "Stop Current Event", UDim2.new(1, -96, 0, 60), UDim2.fromOffset(84, 12), WHITE, { max = 22, align = Enum.TextXAlignment.Left, stroke = 2.5, wrap = true })
		local stop = button(c, "STOP", UDim2.new(1, -20, 0, 44), UDim2.new(0, 10, 1, -54), C.red, { max = 22 })
		stop.Activated:Connect(function() startCall("Stop") end)
		-- keep the countdown ticking while the tab is open
		task.spawn(function()
			while status.Parent do refreshStatus(); task.wait(1) end
		end)
	end
	render = function()
		selectTab(tabButtons, ADMIN_TABS, adminTab)
		for _, ch in ipairs(body:GetChildren()) do ch:Destroy() end
		table.clear(updaters)
		if adminTab == 1 then statsTab() elseif adminTab == 2 then itemsTab() elseif adminTab == 3 then toolsTab() else eventsTab() end
		refreshValues()
	end
	for i, b in ipairs(tabButtons) do
		b.Activated:Connect(function() if adminTab ~= i then adminTab = i; render() end end)
	end
	setTarget(nil)
	render()
	refreshShop = refreshValues
end

function Hud.openShop(kind, anchor)
	-- Keep existing enchant links working, now inside the Backpack.
	if kind == "Enchants" or kind == "Enchant" then bagTab = 3; kind = "Backpack" end
	if kind == "Store" then buildStore(); shopKind = kind; shopAnchor = nil; return end
	if kind == "Rebirth" then buildRebirth(); shopKind = kind; shopAnchor = nil; return end
	if kind == "Vacuum" then buildVacuumShop()
	elseif kind == "Upgrade" then buildUpgrades()
	elseif kind == "Spin" then buildSpin()
	elseif kind == "Sell" then buildSell()
	elseif kind == "Backpack" then buildBackpack()
	elseif kind == "Pets" then buildPets()
	elseif kind == "Worlds" then buildWorlds()
	elseif kind == "Rewards" then buildRewards()
	elseif kind == "Settings" then buildSettings()
	elseif kind == "Admin" then
		if player:GetAttribute("IsAdmin") ~= true then return end
		buildAdmin()
	elseif Hud.ExtraShops and Hud.ExtraShops[kind] then
		Hud.ExtraShops[kind](anchor) -- event booths (EventController)
	else return end
	shopKind = kind; shopAnchor = anchor
end

-- Shared toggle for side-menu controllers added outside this module.
function Hud.toggleShop(kind)
	if shopRoot and shopKind == kind then closeShop() else Hud.openShop(kind) end
end

-- a stud "brick" panel (lip + skinned face) used for the bottom HUD bars and the gate popup
local function brick(parent, size, pos, pal, name, r)
	pal = T(pal)
	lip(parent, size, pos, pal[2], r or 10, 5, pal.bd)
	local f = frame(parent, size, pos, pal[1], name); corner(f, r or 10); stroke(f, 3.5, pal.bd, true)
	skin(f, pal[1], { radius = r or 10, top = pal.hi, bottom = pal.lo, tile = 28 })
	return f
end
-- dark progress track with a stud-skinned fill
local function track(parent, size, pos, fillPal)
	fillPal = T(fillPal)
	local bb = frame(parent, size, pos, rgb(10, 15, 38), "Bar"); corner(bb, 8); stroke(bb, 2.5, BLACK, true); bb.ClipsDescendants = true; bb.ZIndex = 3
	local fill = frame(bb, UDim2.fromScale(0, 1), UDim2.new(), fillPal[1], "Fill"); corner(fill, 8); fill.ZIndex = 3
	skin(fill, fillPal[1], { radius = 8, top = fillPal.hi, bottom = fillPal.lo, tile = 18, noGloss = true })
	local txt = label(bb, "", UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 17, stroke = 2.5, z = 6 })
	return fill, txt
end

-- auto-vacuum bar (used by VacuumController): a stud brick above the bottom bars, same style as Backpack / Crystal.
-- bar.set("off" | "charge" | "auto", k 0..1)
function Hud.AutoBar()
	local function make(name, pal, title, trackPal)
		local h = frame(gui, UDim2.fromOffset(340, 74), UDim2.new(0.5, -170, 1, -180 - (UserInputService.TouchEnabled and 26 or 0)), nil, name); h.Visible = false
		local sc = Instance.new("UIScale"); sc.Parent = h
		local b = brick(h, UDim2.fromOffset(340, 62), UDim2.fromOffset(0, 6), pal, "Brick", 10)
		local ic = sticker(b, "Vac1", 78, -18, -14, -10); ic.ZIndex = 8; tagVac(ic)
		local t = label(b, title, UDim2.new(1, -80, 0, 24), UDim2.fromOffset(66, 3), WHITE, { max = 20, align = Enum.TextXAlignment.Left, stroke = 3, strokeColor = T(pal).bd, extrude = true })
		local fill, txt = track(b, UDim2.new(1, -80, 0, 24), UDim2.fromOffset(68, 31), trackPal)
		return { holder = h, scale = sc, title = t, fill = fill, txt = txt, icon = ic }
	end
	local charge = make("AutoCharge", C.blue, "Charging Auto Vacuum", C.blue)
	local auto = make("AutoOn", C.yellow, "Auto Vacuum ON!", C.green)
	auto.fill.Size = UDim2.fromScale(1, 1)
	auto.txt.Text = UserInputService.TouchEnabled and "TAP STOP TO END" or "CLICK TO STOP"
	-- the STOP button (right of the bar, above the Backpack / Next Crystal bars) is the only way to end Auto Vacuum:
	-- holding or tapping the screen, moving and turning the camera all leave it running. VacuumController sets bar.onStop.
	local stopHolder = frame(auto.holder, UDim2.fromOffset(104, 66), UDim2.fromOffset(348, 4), nil, "StopAuto")
	stopHolder.Visible = UserInputService.TouchEnabled -- phones / tablets only; PC and controller stop it by clicking / pressing R2 again
	local stopBtn = button(stopHolder, "STOP", UDim2.new(1, 0, 1, -5), UDim2.new(), C.red, { max = 28, radius = 10, hover = 1.08 })
	local state = "off"
	local bar = {}
	bar.onStop = nil :: (() -> ())?
	stopBtn.Activated:Connect(function() if bar.onStop then bar.onStop() end end)
	local function pop(p)
		p.holder.Visible = true; p.scale.Scale = 0.7
		TweenService:Create(p.scale, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	function bar.set(s, k)
		if s ~= state then
			state = s
			charge.holder.Visible = false; auto.holder.Visible = false
			if s == "charge" then pop(charge) elseif s == "auto" then pop(auto) end
			refreshVacIcons(charge.holder); refreshVacIcons(auto.holder)
		end
		if s == "charge" then
			charge.fill.Size = UDim2.fromScale(math.clamp(k or 0, 0, 1), 1)
			charge.txt.Text = math.floor((k or 0) * 100) .. "%"
		elseif s == "auto" then
			local p = 0.5 + 0.5 * math.sin(os.clock() * 6)
			auto.icon.Rotation = -10 + 6 * math.sin(os.clock() * 9)
			auto.fill.BackgroundTransparency = 0.15 * p
			stopHolder.Rotation = 3 * math.sin(os.clock() * 7)
		end
	end
	return bar
end

-- UI kit shared with other controllers (EventController uses it so its windows match the Stud UI)
Hud.UI = {
	frame = frame, label = label, button = button, paint = paint, corner = corner, stroke = stroke, grad = grad, skin = skin,
	darkSkin = darkSkin, glass = glass, lip = lip, icon = icon, sticker = sticker, pill = pill, brick = brick, track = track,
	openPanel = openPanel, closeShop = closeShop, selectTab = selectTab, scroller = scroller, card = card, inventorySelect = inventorySelect, inventoryDetail = inventoryDetail, theme = T, themeOf = themeOf,
	C = C, FACE = FACE, WHITE = WHITE, OUT = OUT, SOFT = SOFT, GOLD = GOLD, MINT = MINT,
	gui = function() return gui end,
	setRefresh = function(f) refreshShop = f end,
}

-- ------------------------------------------------------------ HUD
function Hud.Init()
	gui = Instance.new("ScreenGui"); gui.Name = "HUD"; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	scaleObj = Instance.new("UIScale"); scaleObj.Parent = gui
	-- scale from the area the HUD can actually use (below Roblox's top bar, inside the phone's safe area)
	local TOUCH = UserInputService.TouchEnabled
	local function rescale()
		local v = gui.AbsoluteSize
		if v.X < 2 then
			local cam = workspace.CurrentCamera
			v = cam and cam.ViewportSize or Vector2.new(1280, 800)
		end
		local s = math.min(v.Y / 800, v.X / 1400)
		if TOUCH then s *= 0.92 end -- phones: a touch smaller so the HUD leaves room for the thumbsticks
		scaleObj.Scale = math.clamp(s, 0.5, 1.15)
	end
	rescale(); gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

	-- currencies (top centre): dark glass bars with tilted overflowing icons. TOP_Y pulls them (and the
	-- Settings / Rewards buttons) up into the strip next to Roblox's own top-bar buttons.
	local TOP_Y = -42
	local top = frame(gui, UDim2.fromOffset(760, 66), UDim2.new(0.5, -380, 0, TOP_Y), nil, "Currencies")
	local tl = Instance.new("UIListLayout"); tl.FillDirection = Enum.FillDirection.Horizontal; tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tl.Padding = UDim.new(0, 44); tl.SortOrder = Enum.SortOrder.LayoutOrder; tl.Parent = top
	local function bar(order, w, iconKey, name, tip, iconPx)
		local holder = frame(top, UDim2.fromOffset(w, 52), UDim2.new(), nil, name); holder.LayoutOrder = order
		local body = frame(holder, UDim2.fromScale(1, 1), UDim2.new(), nil, "Body"); glass(body, 12, { t = 0.38 })
		local ic = sticker(holder, iconKey, iconPx or 68, -18, -8, -10); ic.Name = name .. "Hud"; ic.ZIndex = 8
		local l = label(body, "0", UDim2.new(1, tip and -98 or -64, 1, -8), UDim2.fromOffset(54, 3), WHITE, { max = 30, stroke = 3, extrude = true })
		if tip then
			local plus = button(holder, "+", UDim2.fromOffset(38, 36), UDim2.new(1, -22, 0.5, -20), C.green, { max = 30, radius = 7, stroke = 3 })
			plus.Activated:Connect(function() Hud.toast(tip) end)
		end
		return l
	end
	coinLabel = bar(1, 220, "Coin", "Coin", "Vacuum items, then sell your loot for coins!")
	gemLabel = bar(2, 180, "Gem", "Gem", "Gems drop from rare items and the Daily Spin!")
	powerLabel = bar(3, 200, "Vac1", "Power", nil, 74)
	local powerHolder = top:FindFirstChild("Power")
	if powerHolder and powerHolder:FindFirstChild("PowerHud") then tagVac(powerHolder.PowerHud) end

	-- every square menu tile (Shop, Home, Bag, Worlds, Rebirth, Admin) uses the same icon size + text size
	local TILE_ICON, TILE_TEXT = 80, 20
	local function tileLook(b, iconKey)
		local lbl = b:FindFirstChild("Label"); lbl.Size = UDim2.new(1, -6, 0, 26); lbl.Position = UDim2.new(0, 3, 1, -31)
		local sh = lbl:FindFirstChild("ShadowRef") and lbl.ShadowRef.Value
		for _, t in ipairs({ lbl, sh }) do
			if t then t.TextScaled = false; t.TextSize = TILE_TEXT; local c = t:FindFirstChildOfClass("UITextSizeConstraint"); if c then c:Destroy() end end
		end
		if sh then sh.Size = lbl.Size; sh.Position = lbl.Position + UDim2.fromOffset(0, 2) end
		local ic = icon(b, iconKey, UDim2.fromOffset(TILE_ICON, TILE_ICON), UDim2.new(0.5, -TILE_ICON / 2, 0, -10)); ic.Rotation = -10; ic.ZIndex = 2; ic.Name = "Icon"
		return ic
	end

	-- left menu: one column of square stud tiles
	local menu = frame(gui, UDim2.fromOffset(104, 4 * 104 + 3 * 8), UDim2.new(0, 14, 0.5, -258), nil, "Menu")
	local ml = Instance.new("UIListLayout"); ml.Padding = UDim.new(0, 8); ml.SortOrder = Enum.SortOrder.LayoutOrder; ml.Parent = menu
	local function goHome()
		closeShop()
		local pad = Config.Spawn
		local boards = Vector3.new(Config.Plaza.Center.X, pad.Y, Config.Plaza.Center.Z) -- face into the plaza
		teleport(CFrame.lookAt(pad, boards))
	end
	local items = {
		{ "Home", Assets.Home and "Home" or "Island", C.orange, goHome },
		{ "Bag", "Backpack", C.blue, function() Hud.openShop("Backpack") end },
		{ "Worlds", "Island", C.green, function() Hud.openShop("Worlds") end },
		{ "Rebirth", "Rebirth", C.purple, function() Hud.openShop("Rebirth") end },
	}
	for i, it in ipairs(items) do
		local h = frame(menu, UDim2.fromOffset(104, 104), UDim2.new(), nil, it[1]); h.LayoutOrder = i
		local b = button(h, it[1], UDim2.new(1, 0, 1, -5), UDim2.new(), it[3], { max = 21, radius = 9, hover = 1.07, tile = 24 })
		local tileIcon = tileLook(b, it[2])
		if it[1] == "Home" then tileIcon.Size = UDim2.fromOffset(88, 88); tileIcon.Position = UDim2.new(0.5, -44, 0, -15) end
		-- pressing the button of the menu that is already open closes it
		local kind = it[1] == "Shop" and "Store" or it[1] == "Bag" and "Backpack" or it[1]
		b.Activated:Connect(function()
			if shopRoot and shopKind == kind then closeShop() else it[4]() end
		end)
		if it[1] == "Rebirth" then
			rebirthBadge = frame(h, UDim2.fromOffset(32, 32), UDim2.new(1, -20, 0, -10), C.red[1], "Badge"); rebirthBadge.ZIndex = 9
			local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.5, 0); bc.Parent = rebirthBadge
			stroke(rebirthBadge, 3, C.red.bd, true); grad(rebirthBadge, C.red.hi, C.red[1], 90)
			label(rebirthBadge, "!", UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 22, stroke = 2.5, strokeColor = C.red.bd, z = 10 })
			rebirthBadge.Visible = false
		end
	end

	-- Shop uses the original Home slot on the right; Home is first in the left menu.
	local shopHolder = frame(gui, UDim2.fromOffset(104, 104), UDim2.new(0, 14 + 104 + 10, 0.5, -258), nil, "Shop")
	local sb = button(shopHolder, "Shop", UDim2.new(1, 0, 1, -5), UDim2.new(), C.red, { max = 21, radius = 9, hover = 1.07, tile = 24 })
	tileLook(sb, "Shop")
	sb.Activated:Connect(function()
		if shopRoot and shopKind == "Store" then closeShop() else Hud.openShop("Store") end
	end)

	-- PETS button (right under Shop): opens the Pets menu
	local petsHolder = frame(gui, UDim2.fromOffset(104, 104), UDim2.new(0, 14 + 104 + 10, 0.5, -258 + 104 + 8), nil, "PetsButton")
	local pb = button(petsHolder, "Pets", UDim2.new(1, 0, 1, -5), UDim2.new(), C.pink, { max = 21, radius = 9, hover = 1.07, tile = 24 })
	tileLook(pb, Assets.Pet and "Pet" or "Star")
	pb.Activated:Connect(function() if shopRoot and shopKind == "Pets" then closeShop() else Hud.openShop("Pets") end end)
	-- the left-side tiles (Home / Bag / Worlds / Rebirth + Shop / Pets) are drawn 25% smaller, staying centred on the same spot
	do
		local SIDE_SCALE = 0.75
		local colH = 4 * 104 + 3 * 8
		local side = frame(gui, UDim2.fromOffset(104 * 2 + 10, colH), UDim2.new(0, 14, 0.5, -258 + colH / 2), nil, "SideMenu")
		side.AnchorPoint = Vector2.new(0, 0.5)
		local sc = Instance.new("UIScale"); sc.Scale = SIDE_SCALE; sc.Parent = side
		menu.Parent = side; menu.Position = UDim2.new()
		shopHolder.Parent = side; shopHolder.Position = UDim2.fromOffset(104 + 10, 0)
		petsHolder.Parent = side; petsHolder.Position = UDim2.fromOffset(104 + 10, 104 + 8)
	end

	-- admin button (bottom-left): only shows for the owner + developers
	local adminHolder = frame(gui, UDim2.fromOffset(104, 104), UDim2.new(0, 14, 1, -122), nil, "Admin")
	local ab = button(adminHolder, "Admin", UDim2.new(1, 0, 1, -5), UDim2.new(), C.blue, { max = 21, radius = 9, hover = 1.07, tile = 24 })
	local aic = tileLook(ab, Assets.Admin and "Admin" or "Star")
	aic.Size = UDim2.fromOffset(98, 98); aic.Position = UDim2.new(0.5, -49, 0, -22) -- the admin art has more empty space, so it's drawn bigger
	ab.Activated:Connect(function() if shopRoot and shopKind == "Admin" then closeShop() else Hud.openShop("Admin") end end)
	local function showAdmin() adminHolder.Visible = player:GetAttribute("IsAdmin") == true end
	showAdmin(); player:GetAttributeChangedSignal("IsAdmin"):Connect(showAdmin)


	-- bottom: backpack meter + next-crystal bar
	local bottom = frame(gui, UDim2.fromOffset(700, 74), UDim2.new(0.5, -350, 1, -96 - (TOUCH and 26 or 0)), nil, "Bottom") -- phones: clear of the rounded corners / home bar
	local bag = brick(bottom, UDim2.fromOffset(240, 62), UDim2.fromOffset(0, 6), C.orange, "Backpack", 10)
	local bi = sticker(bag, "Backpack", 70, -16, -10, -10); bi.Name = "BagHud"; bi.ZIndex = 8
	label(bag, "Backpack", UDim2.new(1, -66, 0, 24), UDim2.fromOffset(58, 3), WHITE, { max = 20, align = Enum.TextXAlignment.Left, stroke = 3, strokeColor = C.orange.bd, extrude = true })
	bagFill, bagText = track(bag, UDim2.new(1, -70, 0, 24), UDim2.fromOffset(60, 31), C.orange)
	bagText.Text = "0 / " .. Config.Capacity(1)
	local pw = brick(bottom, UDim2.fromOffset(446, 62), UDim2.fromOffset(254, 6), C.blue, "Power", 10)
	local pi = sticker(pw, "Vac1", 78, -18, -14, -10); pi.Name = "PowerHud"; pi.ZIndex = 8; tagVac(pi)
	powerTitle = label(pw, "Next Crystal", UDim2.new(1, -80, 0, 24), UDim2.fromOffset(66, 3), WHITE, { max = 20, align = Enum.TextXAlignment.Left, stroke = 3, strokeColor = C.blue.bd, extrude = true })
	powerFill, powerNext = track(pw, UDim2.new(1, -80, 0, 24), UDim2.fromOffset(68, 31), C.blue)

	-- SELL button (appears when the backpack is full; teleports you to the Sell Loot booth)
	sellHolder = frame(gui, UDim2.fromOffset(240, 64), UDim2.new(0.5, -120, 0, 84), nil, "SellHolder")
	sellHolder.Visible = false
	local sell = button(sellHolder, "Sell Loot!", UDim2.new(1, 0, 1, -5), UDim2.new(), C.green, { icon = "Coins", max = 30, iconPad = 58, iconSize = 1 })
	sell.Activated:Connect(function() toBooth("SellShop"); Hud.toast("Sell your loot here!", "Sell") end)

	toastHolder = frame(gui, UDim2.fromOffset(460, 220), UDim2.new(0.5, -230, 0, 156), nil, "Toasts")
	local tll = Instance.new("UIListLayout"); tll.Padding = UDim.new(0, 6); tll.HorizontalAlignment = Enum.HorizontalAlignment.Center; tll.Parent = toastHolder
	popLayer = frame(gui, UDim2.fromScale(1, 1), UDim2.new(), nil, "Pops")
	local inv = Instance.new("UIScale"); inv.Parent = popLayer
	local function invScale() inv.Scale = 1 / scaleObj.Scale end
	invScale(); scaleObj:GetPropertyChangedSignal("Scale"):Connect(invScale)

	-- REWARDS button (bottom-right): half the size of the menu tiles, icon only, red badge when something is ready
	-- SETTINGS button (top-right corner), same half-size tile as Rewards
	local stHolder = frame(gui, UDim2.fromOffset(52, 52), UDim2.new(1, -70, 0, TOP_Y + 6), nil, "Settings")
	local stb = button(stHolder, "", UDim2.new(1, 0, 1, -3), UDim2.new(), C.blue, { max = 10, radius = 6, hover = 1.1, tile = 14 })
	local stIcon = icon(stb, Assets.Settings and "Settings" or "Star", UDim2.fromOffset(46, 46), UDim2.new(0.5, -23, 0, -4)); stIcon.Rotation = -10; stIcon.ZIndex = 2; stIcon.Name = "Icon"
	stb.Activated:Connect(function() if shopRoot and shopKind == "Settings" then closeShop() else Hud.openShop("Settings") end end)

	local rwHolder = frame(gui, UDim2.fromOffset(52, 52), UDim2.new(1, -132, 0, TOP_Y + 6), nil, "Rewards")
	local rwb = button(rwHolder, "", UDim2.new(1, 0, 1, -3), UDim2.new(), C.green, { max = 10, radius = 6, hover = 1.1, tile = 14 })
	local rwIcon = icon(rwb, Assets.Rewards and "Rewards" or "Star", UDim2.fromOffset(50, 50), UDim2.new(0.5, -25, 0, -6)); rwIcon.Rotation = -10; rwIcon.ZIndex = 2; rwIcon.Name = "Icon"
	rwb.Activated:Connect(function() if shopRoot and shopKind == "Rewards" then closeShop() else Hud.openShop("Rewards") end end)
	local rwBadge = frame(rwHolder, UDim2.fromOffset(22, 22), UDim2.new(1, -14, 0, -8), C.red[1], "Badge"); rwBadge.ZIndex = 9
	local rbc = Instance.new("UICorner"); rbc.CornerRadius = UDim.new(0.5, 0); rbc.Parent = rwBadge
	stroke(rwBadge, 2.5, C.red.bd, true); grad(rwBadge, C.red.hi, C.red[1], 90)
	local rwCount = label(rwBadge, "!", UDim2.fromScale(1, 1), UDim2.new(), WHITE, { max = 15, stroke = 2, strokeColor = C.red.bd, z = 10 })
	rwBadge.Visible = false

	-- keep the top row out from under Roblox's own buttons (menu / chat / mic on the left, anything on the right):
	-- GuiService.TopbarInset is the free part of the top bar. The currencies centre in that space (shrinking if it is
	-- narrow, as on phones) and Settings / Rewards sit at its right end.
	local GuiService = game:GetService("GuiService")
	top.AnchorPoint = Vector2.new(0.5, 0)
	local topScale = Instance.new("UIScale"); topScale.Parent = top
	local TOP_W = 700 -- the three bars and their gaps (unscaled)
	local function fitTop()
		local s = scaleObj.Scale
		local inset = GuiService:GetGuiInset()
		local tb = GuiService.TopbarInset
		local guiW = gui.AbsoluteSize.X
		local margin = TOUCH and 18 or 8
		-- right end: Settings, then Rewards, inside the free strip
		local right = math.min(guiW, tb.Max.X - inset.X) - margin
		if tb.Max.X <= tb.Min.X then right = guiW - margin end
		stHolder.Position = UDim2.fromOffset(right / s - 56, TOP_Y + 6)
		rwHolder.Position = UDim2.fromOffset(right / s - 118, TOP_Y + 6)
		-- currencies between Roblox's left buttons and Rewards
		local left = math.max(0, tb.Min.X - inset.X) + margin
		local freeR = (right / s - 118 - 10) * s
		local avail = math.max(1, freeR - left)
		local k = math.clamp(avail / (TOP_W * s), 0.55, 1)
		topScale.Scale = k
		local half = TOP_W * s * k / 2
		local cx = math.clamp(guiW / 2, left + half, math.max(left + half, freeR - half))
		top.Position = UDim2.fromOffset(cx / s, TOP_Y)
	end
	fitTop()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fitTop)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(fitTop) end)
	scaleObj:GetPropertyChangedSignal("Scale"):Connect(fitTop)
	task.spawn(function()
		while gui.Parent do
			local n = rewardsReady()
			rwBadge.Visible = n > 0; rwCount.Text = tostring(n)
			task.wait(1)
		end
	end)

	-- gate popup: small glass window, blue stud header with the gold lock
	-- (centred on screen, well above the auto-vacuum bar and the bottom bars so nothing overlaps)
	gatePanel = frame(gui, UDim2.fromOffset(500, 250), UDim2.new(0.5, 0, 0.5, -20), nil, "GatePopup")
	gatePanel.AnchorPoint = Vector2.new(0.5, 0.5); gatePanel.Visible = false
	glass(gatePanel, 10, { w = 4.5 })
	local gh = frame(gatePanel, UDim2.new(1, 0, 0, 70), UDim2.new(), C.blue[1], "Header"); corner(gh, 10); stroke(gh, 4.5, OUT, true)
	skin(gh, C.blue[1], { radius = 10, top = C.blue.hi, bottom = C.blue.lo, tile = 28, innerC = WHITE, innerT = 0.5 })
	local gl = sticker(gh, "Lock", 96, -24, -26, -10); gl.ZIndex = 8
	label(gh, "Unlock Area", UDim2.new(1, -110, 1, -10), UDim2.fromOffset(82, 4), WHITE, { max = 42, align = Enum.TextXAlignment.Left, stroke = 4.5, strokeColor = C.blue.bd, extrude = 3 })
	gateTitle = label(gatePanel, "", UDim2.new(1, -30, 0, 48), UDim2.fromOffset(15, 84), WHITE, { max = 36, stroke = 3.5, extrude = true })
	local unlock = button(gatePanel, "0", UDim2.fromOffset(290, 70), UDim2.new(0.5, -145, 1, -92), C.green, { icon = "Coin", max = 34, iconPad = 60 })
	gateCost = unlock:FindFirstChild("Label")
	unlock.Activated:Connect(function()
		local ok, res = ReplicatedStorage.Remotes.UnlockZone:InvokeServer(gateZone)
		if ok then Hud.hideGate() else Hud.toast(tostring(res), "Bad") end -- no unlock music on area unlock
	end)

	-- booth NPCs: open on approach instead of "hold E" (the prompts are switched off on this client)
	local function addBooth(prompt)
		local kind = prompt:GetAttribute("Shop")
		if not kind or not prompt.Parent or not prompt.Parent:IsA("BasePart") then return end
		prompt.Enabled = false
		table.insert(booths, { kind = kind, anchor = prompt.Parent, inside = false })
	end
	for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("ProximityPrompt") then addBooth(d) end end
	workspace.DescendantAdded:Connect(function(d) if d:IsA("ProximityPrompt") then task.defer(addBooth, d) end end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute("Shop")
		if kind then Hud.openShop(kind, prompt.Parent) end
	end)
	-- Studio-only test hook (never exists in a live game): HUD.DebugOpen:Fire("Vacuum")
	if RunService:IsStudio() then
		local dbg = Instance.new("BindableEvent"); dbg.Name = "DebugOpen"; dbg.Parent = gui
		dbg.Event:Connect(function(kind) if kind == "close" then closeShop() else Hud.openShop(kind) end end)
	end

	local function refreshBadge()
		if not rebirthBadge then return end
		rebirthBadge.Visible = Config.LevelFromPower(a("Power", 1)) >= Config.RebirthLevel(a("Rebirths", 0))
	end
	for _, k in ipairs({ "Coins", "Gems", "Power", "Vacuum", "OwnedVacuums", "BackpackLv", "WalkLv", "CoinLv", "ZoneUnlocked", "LootCount", "Capacity", "LastSpin", "LootItems", "Loot", "Rebirths", "EggItems", "PetItems", "EquippedPets", "PetList", "EquippedUids", "Rewards", "Settings", "GroupReward", "Enchants", "Enchant", "Chests" }) do
		player:GetAttributeChangedSignal(k):Connect(function()
			if k == "Coins" then coinTarget = a("Coins", 0) end
			if k == "Power" then
				powerTarget = a("Power", 1)
				if powerTarget > lastPower then Hud.powerGain(powerTarget - lastPower) end
				lastPower = powerTarget
			end
			if k == "Vacuum" then refreshVacIcons(gui) end
			if k == "Gems" then gemLabel.Text = Format.commas(a("Gems", 0)) end
			if k == "LootCount" or k == "Capacity" then refreshBag() end
			if k == "Power" or k == "Rebirths" then refreshBadge() end
			refreshTrack()
			if refreshShop and (k ~= "Power" or shopKind == "Rebirth") then refreshShop() end
		end)
	end
	player:GetAttributeChangedSignal("BackpackFull"):Connect(function()
		if player:GetAttribute("BackpackFull") then Hud.toast("Backpack full! Tap Sell Loot at the top.", "Bad") end
	end)
	coinTarget = a("Coins", 0); coinShown = coinTarget
	powerTarget = a("Power", 1); powerShown = powerTarget; lastPower = powerTarget
	refreshVacIcons(gui)
	gemLabel.Text = Format.commas(a("Gems", 0))
	refreshTrack(); refreshBag(); refreshPower(); refreshBadge()
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		if coinShown ~= coinTarget then
			coinShown += (coinTarget - coinShown) * math.min(1, dt * 10)
			if math.abs(coinTarget - coinShown) < 1 then coinShown = coinTarget end
		end
		if powerShown ~= powerTarget then
			powerShown += (powerTarget - powerShown) * math.min(1, dt * 12)
			if math.abs(powerTarget - powerShown) < 1 then powerShown = powerTarget end
			refreshPower()
		end
		coinLabel.Text = coinShown < 1e6 and Format.commas(coinShown) or Format.short(coinShown)
		if sellHolder.Visible then sellHolder.Rotation = math.sin(os.clock() * 5) * 3 end
		if rebirthBadge and rebirthBadge.Visible then
			local s = 1 + 0.12 * math.sin(os.clock() * 6)
			rebirthBadge.Size = UDim2.fromOffset(32 * s, 32 * s)
		end
		acc += dt
		if acc > 0.25 then
			acc = 0
			-- walk up to a booth NPC (Sell / Vacuum Shop / Upgrades) and its menu opens by itself.
			-- It won't pop open again until you've walked away and come back.
			local hrp0 = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp0 then
				for _, b in ipairs(booths) do
					if b.anchor.Parent then
						local near = (hrp0.Position - b.anchor.Position).Magnitude <= BOOTH_OPEN
						if near and not b.inside then
							b.inside = true
							local busyPanel = shopRoot ~= nil and shopAnchor == nil -- don't replace a menu you opened yourself
							if not busyPanel and not Hatch.Busy and shopKind ~= b.kind then Hud.openShop(b.kind, b.anchor) end
						elseif not near and (hrp0.Position - b.anchor.Position).Magnitude > BOOTH_OPEN + 4 then
							b.inside = false
						end
					end
				end
			end
			if shopRoot then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if shopAnchor and hrp and (hrp.Position - shopAnchor.Position).Magnitude > 26 then closeShop()
				elseif shopKind == "Spin" and refreshShop and not spinning then refreshShop() end
			end
		end
	end)
	for _, key in ipairs({ "Power", "Coins", "Backpack", "FastWalk", "Lucky", "AutoRebirth", "AutoOpen" }) do
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(function()
			refreshBag()
			if refreshShop then refreshShop() end
		end)
	end
	ReplicatedStorage.Remotes.Notify.OnClientEvent:Connect(function(msg, kind)
		Hud.toast(msg, kind)
		if kind == "Unlock" then Sfx.play("Upgrade", 0.8, 0.4) end
		if kind == "Sell" then Sfx.play("Coin", 1, 0.6); Hud.bump() end
	end)
end

return Hud
