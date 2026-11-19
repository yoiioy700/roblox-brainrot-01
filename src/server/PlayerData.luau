-- Warung Kopi Brainrot: persistence through DataStoreService.
-- Save data, not objects: money, lifetime earnings, rebirth count and the
-- owned brainrots as {castId, mutation, pad} triples, rebuilt into models
-- on load. Every call is pcalls-guarded; a failed load marks the session
-- not-loaded and refuses to save, so defaults never overwrite real data.

local DataStoreService = game:GetService("DataStoreService")

local BrainrotConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotConfig"))
local FormatUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("FormatUtil"))

local PlayerData = {}

local store = DataStoreService:GetDataStore(BrainrotConfig.SAVE.StoreName)

local function castExists(castId: unknown): boolean
	if type(castId) ~= "string" then
		return false
	end
	for _, entry in BrainrotConfig.CAST do
		if entry.id == castId then
			return true
		end
	end
	return false
end

local function mutationExists(mutationId: unknown): boolean
	if type(mutationId) ~= "string" then
		return false
	end
	for _, mutation in BrainrotConfig.MUTATIONS do
		if mutation.id == mutationId then
			return true
		end
	end
	return false
end

-- newDefault is the fresh-player state: starting money, no earnings, no
-- rebirths, an empty warung.
function PlayerData.newDefault(): { [string]: any }
	return {
		money = BrainrotConfig.ECONOMY.StartMoney,
		lifetimeEarned = 0,
		rebirths = 0,
		owned = {},
	}
end

-- sanitizeLoaded repairs a loaded save in place and reports what it fixed,
-- so old or edited data loads cleanly instead of erroring.
function PlayerData.sanitizeLoaded(raw: unknown): { [string]: any }
	local data = PlayerData.newDefault()
	local repaired = {}
	if type(raw) ~= "table" then
		return data
	end
	local rawTable = raw :: { [string]: any }
	data.money = FormatUtil.sanitizeAmount(rawTable.money)
	data.lifetimeEarned = FormatUtil.sanitizeAmount(rawTable.lifetimeEarned)
	data.rebirths = FormatUtil.sanitizeCount(rawTable.rebirths, 100)
	if type(rawTable.owned) == "table" then
		for _, entry in rawTable.owned do
			if type(entry) == "table" then
				local ownedEntry = entry :: { [string]: any }
				if castExists(ownedEntry.castId) and mutationExists(ownedEntry.mutation) then
					local pad = FormatUtil.sanitizeCount(ownedEntry.pad, BrainrotConfig.MAP.PadsPerPlot)
					table.insert(data.owned, { castId = ownedEntry.castId, mutation = ownedEntry.mutation, pad = pad })
				else
					table.insert(repaired, "dropped unknown brainrot")
				end
			end
		end
	end
	if #repaired > 0 then
		warn("[WarungKopi] Repaired save data: " .. table.concat(repaired, ", "))
	end
	return data
end

local function keyFor(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

-- loadPlayer returns the player's data, or nil when the load itself failed
-- (network failure, throttling): the caller must then refuse to save.
function PlayerData.loadPlayer(player: Player): { [string]: any }?
	local ok, raw = pcall(function()
		return store:GetAsync(keyFor(player))
	end)
	if not ok then
		warn("[WarungKopi] Load failed for " .. tostring(player.UserId) .. ": " .. tostring(raw))
		return nil
	end
	if raw == nil then
		return PlayerData.newDefault()
	end
	return PlayerData.sanitizeLoaded(raw)
end

-- savePlayer writes the whole state with UpdateAsync. It never yields
-- inside the callback and never saves a session whose load failed.
function PlayerData.savePlayer(player: Player, data: { [string]: any }, dataLoaded: boolean)
	if dataLoaded ~= true then
		return false
	end
	local snapshot = {
		money = FormatUtil.sanitizeAmount(data.money),
		lifetimeEarned = FormatUtil.sanitizeAmount(data.lifetimeEarned),
		rebirths = FormatUtil.sanitizeCount(data.rebirths, 100),
		owned = data.owned,
	}
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(_old)
			return snapshot
		end)
	end)
	if not ok then
		warn("[WarungKopi] Save failed for " .. tostring(player.UserId) .. ": " .. tostring(err))
		return false
	end
	return true
end

return PlayerData
