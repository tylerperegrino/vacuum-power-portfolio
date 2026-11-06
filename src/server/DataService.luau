--!strict
-- ProfileStore owns persistence and session locks; gameplay keeps the existing DataService API.
-- Old VacuumPower_v1 keys are READ ONLY. Each player is imported once into the separate store.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local Format = require(ReplicatedStorage.Shared.Format)
local Config = require(ReplicatedStorage.Shared.Config)
local PassPerks = require(ReplicatedStorage.Shared.PassPerks)
local PetData = require(ReplicatedStorage.Shared.PetData)
local EventConfig = require(ReplicatedStorage.Shared.EventConfig)
local EnchantConfig = require(ReplicatedStorage.Shared.EnchantConfig)
local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local ProfileData = require(script.Parent.ProfileData)

local DataService = {}
local LEGACY_STORE_NAME = "VacuumPower_v1"
local STORE_NAME = "VacuumPower_ProfileStore_v1"
local USE_MOCK = RunService:IsStudio() and script:GetAttribute("StudioUseLiveData") ~= true
ProfileStore.SetConstant("AUTO_SAVE_PERIOD", 120)
local playerStore = ProfileStore.New(STORE_NAME, ProfileData.Default)
if USE_MOCK then playerStore = playerStore.Mock end
local sessions = {}
local loading = {}
local started = false
local KEYS = { "Coins", "Gems", "Power", "Vacuum", "BackpackLv", "WalkLv", "CoinLv", "ZoneUnlocked", "Loot", "LootCount", "LastSpin", "LastChest", "CoinsEarned", "Rebirths", "GroupReward", "BoostPowerUntil", "BoostCoinsUntil" }

local function key(p: Player): string return "u_" .. p.UserId end
local function getData(p: Player)
	local session = sessions[p]
	if session and session:IsActive() then return session.Data end
	return nil
end

-- prof.Pets = { [petId] = count } is what hatching / admin tools change. prof.PetList keeps one entry per copy
-- (so pets don't stack in the Pets menu and can be sorted by Recent). This keeps the list matching the counts.
local function syncPets(prof)
	prof.Pets = prof.Pets or {}; prof.PetList = prof.PetList or {}; prof.PetUid = prof.PetUid or 0
	local eqSet = {}
	for _, u in ipairs(prof.EquippedPets or {}) do eqSet[u] = true end
	local have = {}
	for _, e in ipairs(prof.PetList) do have[e.id] = (have[e.id] or 0) + 1 end
	-- too many copies (pets were removed): drop the newest unequipped ones first
	for pass = 1, 2 do
		for i = #prof.PetList, 1, -1 do
			local e = prof.PetList[i]
			if (have[e.id] or 0) > (prof.Pets[e.id] or 0) and (pass == 2 or not eqSet[e.u]) then
				table.remove(prof.PetList, i); have[e.id] -= 1
			end
		end
	end
	-- missing copies (new pets): add them as the newest
	local ids = {}
	for id in pairs(prof.Pets) do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ipairs(ids) do
		while (have[id] or 0) < prof.Pets[id] do
			prof.PetUid += 1
			table.insert(prof.PetList, { u = "p" .. prof.PetUid, id = id })
			have[id] = (have[id] or 0) + 1
		end
	end
end

-- equipped pets must be copies you still own, each once, at most PetData.MaxEquipped
local function fixEquipped(prof)
	syncPets(prof)
	local byU = {}
	for _, e in ipairs(prof.PetList) do byU[e.u] = e end
	local eq, used = {}, {}
	for _, x in ipairs(prof.EquippedPets or {}) do
		if type(x) == "string" and #eq < PetData.MaxEquipped then
			local u = nil
			if byU[x] then u = x
			elseif PetData.ById[x] then -- older save: a pet id -> pick a copy of that pet that isn't equipped yet
				for _, e in ipairs(prof.PetList) do
					if e.id == x and not used[e.u] then u = e.u; break end
				end
			end
			if u and not used[u] then used[u] = true; table.insert(eq, u) end
		end
	end
	prof.EquippedPets = eq
end

-- the enchant you have on ("" = none). It applies to every vacuum; every client reads "Enchant" to draw the aura
local function activeEnchant(prof): string
	if (prof.Enchant == nil or prof.Enchant == "") and prof.VacEnchant and next(prof.VacEnchant) then
		-- old saves had an enchant per vacuum: keep the one on the held vacuum (or any of them)
		local id = prof.VacEnchant[tostring(prof.Vacuum)]
		if not id then local _, any = next(prof.VacEnchant); id = any end
		prof.Enchant = id or ""
		prof.VacEnchant = {}
	end
	local id = prof.Enchant
	if id and id ~= "" and (prof.Enchants or {})[id] and EnchantConfig.ById[id] then return id end
	return ""
end
DataService.ActiveEnchant = activeEnchant

-- cheap part: numbers, capacity and leaderstats. Runs on every vacuum tick (AddPower / AddLoot / AddCoins / Spend).
local function mirrorStats(p: Player, prof)
	for _, k in ipairs(KEYS) do p:SetAttribute(k, prof[k]) end
	p:SetAttribute("Capacity", PassPerks.Capacity(p, prof.BackpackLv))
	p:SetAttribute("Enchant", activeEnchant(prof))
	p:SetAttribute("Pocket", prof.Pocket or 0)
	p:SetAttribute("PocketCap", EnchantConfig.Ab.RiftVault.Pocket)
	local ls = p:FindFirstChild("leaderstats")
	if ls then
		local pw = ls:FindFirstChild("Power") :: StringValue?
		if pw then pw.Value = Format.short(prof.Power) end
		local c = ls:FindFirstChild("Coins") :: StringValue?
		if c then c.Value = Format.short(prof.Coins) end
		local z = ls:FindFirstChild("Zone") :: IntValue?
		if z then z.Value = prof.ZoneUnlocked end
	end
end
-- world-event items + the permanent perks bought with them
local function mirrorEvents(p: Player, prof)
	prof.EventItems = prof.EventItems or {}; prof.EventBought = prof.EventBought or {}
	p:SetAttribute("EventItems", HttpService:JSONEncode(prof.EventItems))
	p:SetAttribute("EventBought", HttpService:JSONEncode(prof.EventBought))
	local perks = EventConfig.Perks(prof.EventBought)
	p:SetAttribute("EvPower", perks.Power); p:SetAttribute("EvCoins", perks.Coins)
	p:SetAttribute("EvLuck", perks.Luck); p:SetAttribute("EvTargets", perks.Targets)
end
local function mirrorLoot(p: Player, prof)
	p:SetAttribute("LootItems", HttpService:JSONEncode(prof.LootItems)) -- { ["zone_rarity"] = count } for the backpack / sell menus
end

-- full refresh: also re-checks equipped pets and re-encodes the pet / egg / loot / vacuum lists
local function mirror(p: Player)
	local prof = getData(p)
	if not prof then return end
	fixEquipped(prof)
	p:SetAttribute("EquippedPets", HttpService:JSONEncode(PetData.EquippedIds(prof))) -- [petId, ...] (everyone's client draws them following you)
	p:SetAttribute("EquippedUids", HttpService:JSONEncode(prof.EquippedPets)) -- [copy id, ...] for the Pets menu check marks
	p:SetAttribute("PetList", HttpService:JSONEncode(prof.PetList)) -- [{ u, id }, ...] one entry per pet copy
	local owned = {}
	for _, id in ipairs(prof.Owned) do table.insert(owned, tostring(id)) end
	p:SetAttribute("OwnedVacuums", table.concat(owned, ","))
	mirrorLoot(p, prof)
	p:SetAttribute("EggItems", HttpService:JSONEncode(prof.Eggs)) -- { ["zone_Variant"] = count } for the backpack Items tab
	p:SetAttribute("PetItems", HttpService:JSONEncode(prof.Pets or {})) -- { [petId] = count } for the backpack Pets tab
	mirrorEvents(p, prof)
	prof.Enchants = prof.Enchants or {}; prof.VacEnchant = prof.VacEnchant or {}
	local owned = {}
	for id in pairs(prof.Enchants) do if EnchantConfig.ById[id] then table.insert(owned, id) end end
	table.sort(owned)
	p:SetAttribute("Enchants", HttpService:JSONEncode(owned)) -- [enchantId, ...] for the Enchants menu
	prof.Chests = prof.Chests or {}
	p:SetAttribute("Chests", HttpService:JSONEncode(prof.Chests)) -- { Kraken = n, Void = n } unopened chests for the bag
	mirrorStats(p, prof)
end

function DataService.Get(p: Player)
	return getData(p)
end
function DataService.Refresh(p: Player)
	mirror(p)
end
function DataService.Save(p: Player): boolean
	local session = sessions[p]
	if not session or not session:IsActive() then return false end
	session:Save()
	return true
end
-- Check the cost and update the frontier in one non-yielding profile transaction.
function DataService.UnlockZone(p: Player, zone: number): (boolean, string?)
	local prof = getData(p)
	if not prof then return false, "Loading" end
	if zone ~= prof.ZoneUnlocked + 1 or not Config.Zones[zone] then return false, "Unlock the earlier areas first" end
	local cost = Config.Zones[zone].Cost
	if prof.Coins < cost then return false, "Not enough coins" end
	prof.Coins -= cost
	prof.ZoneUnlocked = zone
	mirror(p)
	DataService.Save(p)
	return true
end
function DataService.ClaimGroupReward(p: Player, gems: number): (boolean, string?)
	local prof = getData(p)
	if not prof then return false, "Your data is still loading." end
	if prof.GroupReward then return false, "Thank you for joining the group! You already claimed your reward." end
	prof.GroupReward = true
	prof.Gems += gems
	mirror(p)
	DataService.Save(p)
	return true, "Thank you for joining the group! +" .. Format.commas(gems) .. " Gems"
end

function DataService.Set(p: Player, k: string, v: any)
	local prof = getData(p)
	if not prof then return end
	prof[k] = v
	-- plain values only change attributes; tables (inventories, Owned) need the full refresh
	if type(v) == "table" then mirror(p) else mirrorStats(p, prof) end
end

function DataService.AddCoins(p: Player, amount: number)
	local prof = getData(p)
	if not prof then return end
	prof.Coins = math.max(0, prof.Coins + amount)
	if amount > 0 then prof.CoinsEarned += amount end
	mirrorStats(p, prof)
end

function DataService.AddPower(p: Player, amount: number)
	local prof = getData(p)
	if not prof or amount <= 0 then return end
	amount *= PassPerks.PowerMultiplier(p)
	prof.Power += amount
	mirrorStats(p, prof)
	return amount
end

-- Backpack: returns false when full (the item's loot is lost and nothing is added)
function DataService.HasRoom(p: Player): boolean
	local prof = getData(p)
	return prof ~= nil and prof.LootCount < PassPerks.Capacity(p, prof.BackpackLv)
end
-- slots: backpack space this item takes (1 normally; enchants can squeeze it to 0.75 / 0.5, or 0 = free)
function DataService.AddLoot(p: Player, value: number, itemKey: string?, slots: number?): boolean
	local prof = getData(p)
	local s = math.clamp(slots or 1, 0, 1)
	if not prof or (s > 0 and prof.LootCount >= PassPerks.Capacity(p, prof.BackpackLv)) then return false end
	prof.LootCount += s
	prof.Loot += value
	if itemKey then prof.LootItems[itemKey] = (prof.LootItems[itemKey] or 0) + 1 end
	mirrorStats(p, prof)
	if itemKey then mirrorLoot(p, prof) end
	return true
end
-- Rift Vault pocket: loot kept outside the backpack (limited size), sold with the rest of your loot
function DataService.AddPocket(p: Player, value: number): boolean
	local prof = getData(p)
	if not prof or (prof.Pocket or 0) >= EnchantConfig.Ab.RiftVault.Pocket then return false end
	prof.Pocket = (prof.Pocket or 0) + 1
	prof.PocketValue = (prof.PocketValue or 0) + value
	mirrorStats(p, prof)
	return true
end
-- enchants: "new" when added to the inventory, "dupe" when you already own it (the caller pays the refund)
function DataService.GiveEnchant(p: Player, id: string): string?
	local prof = getData(p)
	if not prof or not EnchantConfig.ById[id] then return nil end
	prof.Enchants = prof.Enchants or {}
	if prof.Enchants[id] then return "dupe" end
	prof.Enchants[id] = true
	mirror(p)
	return "new"
end
-- put on one of your enchants (it works on every vacuum); id = nil / "" takes it off
function DataService.SetEnchant(p: Player, id: string?): (boolean, string?)
	local prof = getData(p)
	if not prof then return false, "Your data is still loading." end
	if id == nil or id == "" then
		prof.Enchant = ""
	else
		if not EnchantConfig.ById[id] or not (prof.Enchants or {})[id] then return false, "You don't own that enchantment." end
		prof.Enchant = id
	end
	prof.VacEnchant = {}
	mirror(p)
	return true
end
-- unopened enchant chests (bought in the boss shops, opened from the bag)
function DataService.AddChest(p: Player, key: string, n: number): boolean
	local prof = getData(p)
	if not prof or not EnchantConfig.Chests[key] then return false end
	prof.Chests = prof.Chests or {}
	local now = math.max(0, (prof.Chests[key] or 0) + math.floor(n))
	prof.Chests[key] = now > 0 and now or nil
	mirror(p)
	return true
end
function DataService.ChestCount(p: Player, key: string): number
	local prof = getData(p)
	return prof and (prof.Chests or {})[key] or 0
end
-- world-event items (saved forever; crystals can only be spent in the Crystal Shop)
function DataService.AddEventItem(p: Player, key: string, n: number): boolean
	local prof = getData(p)
	if not prof or not EventConfig.Items[key] or n <= 0 then return false end
	prof.EventItems = prof.EventItems or {}
	prof.EventItems[key] = (prof.EventItems[key] or 0) + math.floor(n)
	mirrorEvents(p, prof)
	return true
end
-- spend a cost table { [item] = n } atomically; false if any is short
function DataService.SpendEventItems(p: Player, cost: { [string]: number }): boolean
	local prof = getData(p)
	if not prof then return false end
	prof.EventItems = prof.EventItems or {}
	for k, n in pairs(cost) do if (prof.EventItems[k] or 0) < n then return false end end
	for k, n in pairs(cost) do
		local left = (prof.EventItems[k] or 0) - n
		prof.EventItems[k] = left > 0 and left or nil
	end
	mirrorEvents(p, prof)
	return true
end
function DataService.MirrorEvents(p: Player)
	local prof = getData(p)
	if prof then mirrorEvents(p, prof) end
end
-- eggs live in their own inventory (backpack Items tab) and don't use loot capacity
function DataService.AddEgg(p: Player, eggKey: string): boolean
	local prof = getData(p)
	if not prof or type(eggKey) ~= "string" then return false end
	prof.Eggs[eggKey] = (prof.Eggs[eggKey] or 0) + 1

	mirror(p)
	return true
end
-- opening an egg: takes one egg of that key, gives the pet. Returns false if the player has none.
function DataService.UseEggForPet(p: Player, eggKey: string, petId: string): boolean
	local prof = getData(p)
	if not prof or type(eggKey) ~= "string" or type(petId) ~= "string" then return false end
	local have = prof.Eggs[eggKey] or 0
	if have < 1 then return false end
	if have <= 1 then prof.Eggs[eggKey] = nil else prof.Eggs[eggKey] = have - 1 end
	prof.Pets = prof.Pets or {}
	prof.Pets[petId] = (prof.Pets[petId] or 0) + 1

	mirror(p)
	return true
end
-- opening several at once: takes #petIds eggs of that key and gives every pet in one step (all or nothing)
-- eggCount: eggs to take (defaults to #petIds; more when some hatched pets were auto-deleted)
function DataService.UseEggsForPets(p: Player, eggKey: string, petIds: { string }, eggCount: number?): boolean
	local prof = getData(p)
	local n = eggCount or #petIds
	if not prof or type(eggKey) ~= "string" or type(petIds) ~= "table" or n < 1 or n < #petIds then return false end
	local have = prof.Eggs[eggKey] or 0
	if have < n then return false end
	if have <= n then prof.Eggs[eggKey] = nil else prof.Eggs[eggKey] = have - n end
	prof.Pets = prof.Pets or {}
	for _, id in ipairs(petIds) do prof.Pets[id] = (prof.Pets[id] or 0) + 1 end

	mirror(p)
	return true
end
-- pets: equip / unequip one pet copy (u = its copy id from PetList)
function DataService.EquipPet(p: Player, u: string): (boolean, string?)
	local prof = getData(p)
	if not prof then return false, "Your data is still loading." end
	fixEquipped(prof)
	local found = false
	for _, e in ipairs(prof.PetList) do if e.u == u then found = true; break end end
	if not found then return false, "You don't have that pet." end
	if table.find(prof.EquippedPets, u) then return false, "That pet is already equipped." end
	if #prof.EquippedPets >= PetData.MaxEquipped then return false, "You can equip " .. PetData.MaxEquipped .. " pets at a time." end
	table.insert(prof.EquippedPets, u)
	mirror(p)
	return true
end
function DataService.UnequipPet(p: Player, u: string): (boolean, string?)
	local prof = getData(p)
	if not prof then return false, "Your data is still loading." end
	local i = table.find(prof.EquippedPets or {}, u)
	if not i then return false, "That pet isn't equipped." end
	table.remove(prof.EquippedPets, i)
	mirror(p)
	return true
end
function DataService.UnequipAll(p: Player): (boolean, string?)
	local prof = getData(p)
	if not prof then return false, "Your data is still loading." end
	if #(prof.EquippedPets or {}) == 0 then return false, "You don't have any pets equipped." end
	prof.EquippedPets = {}
	mirror(p)
	return true
end
-- deleting pets (Pets menu multi delete): removes these copies for good. Equipped pets are skipped.
function DataService.DeletePets(p: Player, uids: { string }): (boolean, any)
	local prof = getData(p)
	if not prof then return false, "Your data is still loading." end
	fixEquipped(prof)
	local want = {}
	for _, u in ipairs(uids) do if type(u) == "string" then want[u] = true end end
	local eq = {}
	for _, u in ipairs(prof.EquippedPets) do eq[u] = true end
	local n = 0
	for i = #prof.PetList, 1, -1 do
		local e = prof.PetList[i]
		if want[e.u] and not eq[e.u] then
			table.remove(prof.PetList, i)
			local c = (prof.Pets[e.id] or 0) - 1
			prof.Pets[e.id] = c > 0 and c or nil
			n += 1
		end
	end
	if n == 0 then return false, "Pick the pets to delete (equipped pets can't be deleted)." end
	mirror(p)
	return true, n
end
-- Equip Best: your strongest pets (highest total bonus) fill every slot
function DataService.EquipBest(p: Player): (boolean, string?)
	local prof = getData(p)
	if not prof then return false, "Your data is still loading." end
	fixEquipped(prof)
	if #prof.PetList == 0 then return false, "You don't have any pets yet." end
	local list = table.clone(prof.PetList)
	local function num(e) return tonumber(string.sub(e.u, 2)) or 0 end
	table.sort(list, function(x, y)
		local sx, sy = PetData.Score(x.id), PetData.Score(y.id)
		if sx ~= sy then return sx > sy end
		local ex, ey = table.find(prof.EquippedPets, x.u) ~= nil, table.find(prof.EquippedPets, y.u) ~= nil
		if ex ~= ey then return ex end -- same strength: keep the copy you already have out
		return num(x) < num(y)
	end)
	local eq = {}
	for i = 1, math.min(PetData.MaxEquipped, #list) do eq[i] = list[i].u end
	prof.EquippedPets = eq
	mirror(p)
	return true
end
function DataService.EggCount(p: Player, eggKey: string): number
	local prof = getData(p)
	return prof and prof.Eggs[eggKey] or 0
end
function DataService.SellLoot(p: Player): (number, number)
	local prof = getData(p)
	if not prof or (prof.LootCount <= 0 and (prof.Pocket or 0) <= 0) then return 0, 0 end
	-- the enchant on the vacuum you're holding multiplies the sale
	local ench = EnchantConfig.ById[activeEnchant(prof)]
	local sell = ench and ench.Sell or 1
	local count = math.ceil(prof.LootCount) + (prof.Pocket or 0)
	local value = (prof.Loot + (prof.PocketValue or 0)) * PassPerks.CoinMultiplier(p) * sell
	prof.LootCount = 0
	prof.Loot = 0
	prof.LootItems = {}
	prof.Pocket = 0; prof.PocketValue = 0
	mirrorLoot(p, prof)
	DataService.AddCoins(p, value)
	return count, value
end

function DataService.Owns(p: Player, id: number): boolean
	local prof = getData(p)
	if not prof then return false end
	return table.find(prof.Owned, id) ~= nil
end
function DataService.GiveVacuum(p: Player, id: number)
	local prof = getData(p)
	if not prof or table.find(prof.Owned, id) then return end
	table.insert(prof.Owned, id)
	table.sort(prof.Owned)

	mirror(p)
end

function DataService.Spend(p: Player, amount: number): boolean
	local prof = getData(p)
	if not prof or amount < 0 or prof.Coins < amount then return false end
	prof.Coins -= amount
	mirrorStats(p, prof)
	return true
end


-- A code claim and all rewards change the same active profile without yielding.
function DataService.RedeemCode(p: Player, code: string, rewards)
	local prof = getData(p)
	if not prof then return false, "Your data is still loading. Try again shortly." end
	if prof.RedeemedCodes[code] then return false, "You already redeemed this code." end
	local nextValues, labels = {}, {}
	for _, currency in ipairs({ "Coins", "Gems", "Power" }) do
		local amount = rewards[currency] or 0
		if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge or amount % 1 ~= 0 then
			return false, "This code is not available right now."
		end
		if currency == "Power" then amount *= PassPerks.PowerMultiplier(p) end
		local value = prof[currency] + amount
		if value == math.huge then return false, "This reward cannot be added right now." end
		nextValues[currency] = value
		if amount > 0 then table.insert(labels, "+" .. Format.short(amount) .. " " .. currency) end
	end
	if #labels == 0 then return false, "This code is not available right now." end
	prof.RedeemedCodes[code] = os.time()
	for currency, value in pairs(nextValues) do prof[currency] = value end
	prof.CoinsEarned += rewards.Coins or 0
	mirror(p)
	sessions[p]:Save()
	return true, "Redeemed! " .. table.concat(labels, ", ")
end

-- Developer product receipts: apply each PurchaseId once, and only report success after a save that contains it
-- has finished (ProcessReceipt must not return PurchaseGranted for a grant that could still be lost).
local PURCHASE_LOG_SIZE = 100
function DataService.GrantPurchase(p: Player, purchaseId: string, apply: (any) -> ()): boolean
	local session = sessions[p]
	if not session or not session:IsActive() then return false end
	local prof = session.Data
	prof.PurchaseIds = prof.PurchaseIds or {}
	if not table.find(prof.PurchaseIds, purchaseId) then -- a retried receipt is never applied twice
		apply(prof)
		table.insert(prof.PurchaseIds, purchaseId)
		while #prof.PurchaseIds > PURCHASE_LOG_SIZE do table.remove(prof.PurchaseIds, 1) end
		mirror(p)
	end
	local saved = false
	local conn = session.OnAfterSave:Connect(function(lastSaved)
		if type(lastSaved) == "table" and table.find(lastSaved.PurchaseIds or {}, purchaseId) then saved = true end
	end)
	session:Save()
	local t0 = os.clock()
	while not saved and session:IsActive() and os.clock() - t0 < 20 do task.wait(0.1) end
	conn:Disconnect()
	return saved
end

local function readLegacy(p: Player)
	local lastError
	for attempt = 1, 3 do
		if p.Parent ~= Players or ProfileStore.IsClosing then return false, nil end
		local ok, result = pcall(function()
			local options = Instance.new("DataStoreGetOptions")
			options.UseCache = false
			return DataStoreService:GetDataStore(LEGACY_STORE_NAME):GetAsync(key(p), options)
		end)
		if ok then return true, result end
		lastError = result
		if attempt < 3 then task.wait(1.5 * attempt) end
	end
	warn("[DataService] Legacy import read failed:", lastError)
	return false, nil
end

local function onJoin(p: Player)
	if loading[p] or sessions[p] then return end
	loading[p] = true
	p:SetAttribute("DataLoaded", false)
	p:SetAttribute("DataMode", USE_MOCK and "StudioMock" or "ProfileStore")
	if not p:FindFirstChild("leaderstats") then
		local ls = Instance.new("Folder"); ls.Name = "leaderstats"
		local power = Instance.new("StringValue"); power.Name = "Power"; power.Value = "1"; power.Parent = ls
		local coins = Instance.new("StringValue"); coins.Name = "Coins"; coins.Value = "0"; coins.Parent = ls
		local zone = Instance.new("IntValue"); zone.Name = "Zone"; zone.Value = 1; zone.Parent = ls
		ls.Parent = p
	end
	if not USE_MOCK then
		while ProfileStore.DataStoreState == "NotReady" and p.Parent == Players and not ProfileStore.IsClosing do task.wait(0.1) end
		if p.Parent ~= Players or ProfileStore.IsClosing then loading[p] = nil; return end
		if ProfileStore.DataStoreState ~= "Access" then
			loading[p] = nil
			p:Kick("Couldn't connect to saving. Please rejoin shortly - your progress is safe.")
			return
		end
	end
	local session = playerStore:StartSessionAsync(key(p), {
		Cancel = function() return p.Parent ~= Players end,
	})
	loading[p] = nil
	if not session then
		if p.Parent == Players then p:Kick("Couldn't load your progress. Please rejoin shortly.") end
		return
	end
	session:AddUserId(p.UserId)
	local function reject(message)
		session:EndSession()
		if p.Parent == Players then p:Kick(message) end
	end
	if p.Parent ~= Players or not session:IsActive() then session:EndSession(); return end
	if session.Data._legacyMigrationComplete ~= true then
		local loaded, legacy = true, nil
		if not USE_MOCK then loaded, legacy = readLegacy(p) end
		if not session:IsActive() or p.Parent ~= Players then session:EndSession(); return end
		if not loaded then
			-- Leave the marker false. Never turn a failed read into a fresh, migrated save.
			reject("Couldn't import your existing progress. Please rejoin shortly - your old save is unchanged.")
			return
		end
		local imported, reason = ProfileData.ImportLegacy(legacy)
		if not imported then
			warn("[DataService] Import blocked:", p.UserId, reason)
			reject("Your save needs checking. Your existing progress has been kept safe.")
			return
		end
		if USE_MOCK then imported._migrationSource = "StudioMock" end
		session.Data = imported
	end
	local valid, reason = ProfileData.Validate(session.Data)
	if not valid then
		warn("[DataService] Invalid profile:", p.UserId, reason)
		reject("Your save needs checking. Please rejoin later.")
		return
	end
	session:Reconcile()
	-- Match the previous loader's equipped-vacuum fallback, without resetting inventories.
	if not table.find(session.Data.Owned, 1) then table.insert(session.Data.Owned, 1) end
	if not table.find(session.Data.Owned, session.Data.Vacuum) or not Config.Vacuums[session.Data.Vacuum] then session.Data.Vacuum = 1 end
	session.Data.Power = math.max(1, session.Data.Power)
	session.OnSessionEnd:Connect(function()
		if sessions[p] == session then
			sessions[p] = nil
			p:SetAttribute("DataLoaded", false)
			if p.Parent == Players and not ProfileStore.IsClosing then
				p:Kick("Your data session ended. Please rejoin to keep your progress safe.")
			end
		end
	end)
	if p.Parent ~= Players or not session:IsActive() then session:EndSession(); return end
	sessions[p] = session
	mirror(p)
	p:SetAttribute("DataLoaded", true)
	session:Save() -- persist the migration marker and imported data together
end

local function onLeave(p: Player)
	local session = sessions[p]
	sessions[p] = nil
	loading[p] = nil
	if session then session:EndSession() end
end

function DataService.Start()
	if started then return end
	started = true
	if USE_MOCK then
		warn("[DataService] STUDIO MOCK MODE: progress and redeemed codes reset when play stops. Production saves are not changed.")
	end
	ProfileStore.OnError:Connect(function(message, name, profileKey)
		warn("[DataService] Saving error:", name, profileKey, message)
	end)
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(onJoin, p) end
	if RunService:IsStudio() then
		local ss = game:GetService("ServerStorage")
		local function hook(name, callback)
			local old = ss:FindFirstChild(name); if old then old:Destroy() end
			local bf = Instance.new("BindableFunction"); bf.Name = name; bf.OnInvoke = callback; bf.Parent = ss
		end
		hook("StudioGrantCoins", function(p, amount) DataService.AddCoins(p, amount); return true end)
		hook("StudioSet", function(p, k, v) DataService.Set(p, k, v); return true end)
		hook("StudioGiveEgg", function(p, key, n) for _ = 1, (n or 1) do DataService.AddEgg(p, key) end; return true end)
	end
	-- ProfileStore's own BindToClose waits for active loads and final saves.
end

return DataService
