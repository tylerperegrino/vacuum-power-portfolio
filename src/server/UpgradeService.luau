--!strict
-- Upgrade shop + vacuum shop, all server-validated. Clients only send ids. Also applies walk speed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local PassPerks = require(ReplicatedStorage.Shared.PassPerks)

local UpgradeService = {}
local lastBuy: { [Player]: number } = {}
local SHOP_RANGE = 40 -- must be standing near the matching shop in the plaza

local function nearShop(p: Player, shopName: string): boolean
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plaza = workspace:FindFirstChild("Plaza")
	local shop = plaza and plaza:FindFirstChild("Shops") and plaza.Shops:FindFirstChild(shopName)
	if not hrp or not shop or not shop:IsA("Model") then return false end
	return (hrp.Position - shop:GetPivot().Position).Magnitude <= SHOP_RANGE
end

local function throttle(p: Player): boolean
	local now = os.clock()
	if lastBuy[p] and now - lastBuy[p] < 0.12 then return false end
	lastBuy[p] = now
	return true
end

local function applyWalk(p: Player, DataService)
	local prof = DataService.Get(p)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = PassPerks.WalkSpeed(p, prof and prof.WalkLv or 1) end
end

function UpgradeService.Start(DataService)
	local remotes = ReplicatedStorage.Remotes
	;(remotes:FindFirstChild("BuyUpgrade") :: RemoteFunction).OnServerInvoke = function(p: Player, id: any)
		if type(id) ~= "string" or #id > 16 then return false, "Invalid" end
		if not throttle(p) then return false, "Slow down" end
		if not nearShop(p, "UpgradeShop") then return false, "Visit the Upgrade Shop in the plaza" end
		local u = Config.UpgradeById(id)
		local prof = DataService.Get(p)
		if not u or not prof then return false, "Invalid" end
		local key = id .. "Lv"
		local lv = prof[key]
		if type(lv) ~= "number" then return false, "Invalid" end
		if lv >= u.Max then return false, "Maxed" end
		local price = Config.Price(id, lv)
		if not DataService.Spend(p, price) then return false, "Not enough coins" end
		DataService.Set(p, key, lv + 1)
		if id == "Walk" then applyWalk(p, DataService) end
		return true, lv + 1
	end
	;(remotes:FindFirstChild("BuyVacuum") :: RemoteFunction).OnServerInvoke = function(p: Player, id: any)
		if type(id) ~= "number" or id ~= id then return false, "Invalid" end
		id = math.floor(id)
		local v = Config.Vacuums[id]
		local prof = DataService.Get(p)
		if not v or not prof then return false, "Invalid" end
		if not throttle(p) then return false, "Slow down" end
		if not nearShop(p, "VacuumShop") then return false, "Visit the Vacuum Shop in the plaza" end
		if DataService.Owns(p, id) then return false, "Already owned" end
		if id > 1 and not DataService.Owns(p, id - 1) then return false, "Buy the " .. Config.Vacuums[id - 1].Name .. " first" end
		if not DataService.Spend(p, v.Price) then return false, "Not enough coins" end
		DataService.GiveVacuum(p, id)
		DataService.Set(p, "Vacuum", id) -- auto-equip the new one
		return true, id
	end
	;(remotes:FindFirstChild("EquipVacuum") :: RemoteFunction).OnServerInvoke = function(p: Player, id: any)
		if type(id) ~= "number" or id ~= id then return false, "Invalid" end
		id = math.floor(id)
		if not Config.Vacuums[id] or not DataService.Owns(p, id) then return false, "You don't own that vacuum" end
		if not throttle(p) then return false, "Slow down" end
		DataService.Set(p, "Vacuum", id)
		return true, id
	end
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(function(char)
			char:WaitForChild("Humanoid", 10)
			while p.Parent and not DataService.Get(p) do task.wait(0.2) end
			applyWalk(p, DataService)
		end)
		if p.Character then task.spawn(applyWalk, p, DataService) end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
	Players.PlayerRemoving:Connect(function(p) lastBuy[p] = nil end)
end

return UpgradeService
