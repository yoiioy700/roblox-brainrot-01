-- Warung Kopi Brainrot: the server. One module owns the whole game:
-- player sessions and plots, the conveyor that walks brainrots past the
-- warung, the money tick, buying, stealing with a base lock, rebirths,
-- saving, and the Banjir Bandang wave that sweeps the street.
-- The server decides everything; the client only shows state and sends
-- intent (an id to buy, an id to steal, lock, rebirth). No amount or price
-- is ever accepted from a client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BrainrotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotConfig"))
local FormatUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatUtil"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local BrainrotFactory = require(script.Parent:WaitForChild("BrainrotFactory"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local GameServer = {}

-- Live state. sessions is keyed by Player; conveyor by brainrot id.
local sessions: { [Player]: { [string]: any } } = {}
local conveyor: { [string]: Model } = {}
local clickConnections: { [string]: RBXScriptConnection } = {}
local world: { [string]: any }
local remotes: { [string]: RemoteEvent }
local nextBrainrotId = 1
local rng = Random.new()
local waveState = "idle" -- "idle" | "warning" | "sweep"
local waveTimer = BrainrotConfig.WAVE.Period
local waveWall: Part? = nil

-- rebirthRequirement is the lifetime rupiah a player must have earned to
-- rebirth again: 25,000 times 2.5 for every rebirth already done.
local function rebirthRequirement(rebirths: number): number
	return math.floor(BrainrotConfig.ECONOMY.RebirthBaseRequirement * (BrainrotConfig.ECONOMY.RebirthRequirementGrowth ^ rebirths))
end

-- incomePerSecond sums one player's owned brainrots, times the rebirth
-- multiplier (1 + rebirths). Mutations are already folded into each
-- brainrot's Income attribute.
local function incomePerSecond(session: { [string]: any }): number
	local total = 0
	for _, owned in session.owned do
		local model = owned.model :: Model
		if model.Parent then
			total += model:GetAttribute("Income") or 0
		end
	end
	return total * (1 + session.rebirths)
end

local function freePadIndex(session: { [string]: any }): number?
	local used: { [boolean]: boolean } = {}
	for _, owned in session.owned do
		used[owned.pad] = true
	end
	for pad = 1, BrainrotConfig.MAP.PadsPerPlot do
		if not used[pad] then
			return pad
		end
	end
	return nil
end

local function findCast(castId: string): { [string]: any }?
	for _, entry in BrainrotConfig.CAST do
		if entry.id == castId then
			return entry
		end
	end
	return nil
end

local function castOfRarity(rarityId: string): { [string]: any }
	local pool = {}
	for _, entry in BrainrotConfig.CAST do
		if entry.rarity == rarityId then
			table.insert(pool, entry)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- rollBrainrot picks a rarity by weight, a character of that rarity, and a
-- mutation by weight: the same weighted roll the economy skill recommends.
local function rollBrainrot(): ({ [string]: any }, string)
	local rarity = FormatUtil.pickWeighted(BrainrotConfig.RARITIES, rng)
	local cast = castOfRarity(rarity.id)
	local mutation = FormatUtil.pickWeighted(BrainrotConfig.MUTATIONS, rng)
	return cast, mutation.id
end

-- notify sends one banner line to one player (or everyone when player is
-- nil): the client shows it centre-screen for a few seconds.
local function notify(player: Player?, text: string, color: Color3)
	if player then
		remotes.Notify:FireClient(player, text, color)
	else
		remotes.Notify:FireAllClients(text, color)
	end
end

-- pushState sends one player's HUD numbers. The client renders from this
-- and never from its own copy of the economy.
local function pushState(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local now = os.clock()
	remotes.StateUpdate:FireClient(player, {
		money = session.money,
		incomePerSecond = incomePerSecond(session),
		ownedCount = #session.owned,
		rebirths = session.rebirths,
		rebirthRequirement = rebirthRequirement(session.rebirths),
		lifetimeEarned = session.lifetimeEarned,
		plotIndex = session.plotIndex,
		waveState = waveState,
		waveCountdown = math.ceil(waveTimer),
		lockRemaining = math.max(0, (session.lockUntil or 0) - now),
		lockCooldownRemaining = math.max(0, (session.lockCooldownUntil or 0) - now),
	})
end

local function updateLeaderstats(player: Player)
	local session = sessions[player]
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local money = stats:FindFirstChild("Uang")
	if money and money:IsA("IntValue") then
		money.Value = math.floor(session.money)
	end
	local rebirth = stats:FindFirstChild("Rebirth")
	if rebirth and rebirth:IsA("IntValue") then
		rebirth.Value = session.rebirths
	end
end

-- placeBrainrotOnPad moves a model onto a pad of a plot, facing the
-- conveyor, and stamps its new ownership in its attributes.
local function placeBrainrotOnPad(model: Model, plotIndex: number, padIndex: number, ownerUserId: number)
	local plot = world.plots[plotIndex]
	local padPos = plot.pads[padIndex]
	local cast = findCast(model:GetAttribute("CastId"))
	local scale = cast and cast.scale or 1
	local facing = if plot.center.Z > 0 then 0 else math.pi
	model:SetAttribute("OwnerUserId", ownerUserId)
	model:SetAttribute("PlotIndex", plotIndex)
	model:SetAttribute("PadIndex", padIndex)
	model:PivotTo(CFrame.new(padPos + Vector3.new(0, 0.9 * scale, 0)) * CFrame.Angles(0, facing, 0))
	BrainrotFactory.refreshLabel(model)
end

-- destroyBrainrot removes a brainrot everywhere: its model, its click
-- connection, and its conveyor slot if it had one.
local function destroyBrainrot(brainrotId: string)
	local connection = clickConnections[brainrotId]
	if connection then
		connection:Disconnect()
		clickConnections[brainrotId] = nil
	end
	local model = conveyor[brainrotId]
	if model then
		conveyor[brainrotId] = nil
		model:Destroy()
		return
	end
	-- It may be owned on a plot instead of on the conveyor.
	for _, session in sessions do
		for i, owned in session.owned do
			local ownedModel = owned.model :: Model
			if ownedModel:GetAttribute("BrainrotId") == brainrotId then
				table.remove(session.owned, i)
				ownedModel:Destroy()
				return
			end
		end
	end
end

-- returnBrainrotToOwner puts a carried (stolen) brainrot back on its
-- owner's plot: its original pad when free, else any free pad, else it is
-- removed and the owner keeps nothing for it.
local function returnBrainrotToOwner(model: Model)
	local ownerUserId = model:GetAttribute("OwnerUserId")
	local padIndex = model:GetAttribute("PadIndex")
	local owner: Player? = nil
	for player, _ in sessions do
		if player.UserId == ownerUserId then
			owner = player
			break
		end
	end
	if not owner then
		model:Destroy()
		return
	end
	local session = sessions[owner]
	local wantedPad = padIndex
	local free = true
	for _, owned in session.owned do
		if owned.pad == wantedPad then
			free = false
			break
		end
	end
	if not free then
		wantedPad = freePadIndex(session)
	end
	if not wantedPad then
		-- The owner's warung is full: the brainrot is lost.
		for i, owned in session.owned do
			local ownedModel = owned.model :: Model
			if ownedModel == model then
				table.remove(session.owned, i)
				break
			end
		end
		model:Destroy()
		return
	end
	placeBrainrotOnPad(model, session.plotIndex, wantedPad, ownerUserId)
end

-- onBrainrotClicked is the one ClickDetector handler for every brainrot:
-- on the conveyor it is a buy, on someone else's plot it is a steal, on
-- your own plot it does nothing.
local function onBrainrotClicked(player: Player, model: Model)
	local session = sessions[player]
	if not session then
		return
	end
	local brainrotId = model:GetAttribute("BrainrotId")
	local ownerUserId = model:GetAttribute("OwnerUserId") or 0
	if ownerUserId == 0 then
		-- ClickDetectors fire on the server already, so call the buy logic
		-- directly; there is no remote round-trip.
		GameServer.tryBuyBrainrot(player, brainrotId)
	elseif ownerUserId == player.UserId then
		notify(player, "Itu brainrotmu sendiri!", Color3.fromRGB(255, 220, 120))
	else
		GameServer.tryStealBrainrot(player, brainrotId)
	end
end

-- tryBuyBrainrot validates and applies a purchase. The server looks up
-- the price; the client never sends one.
function GameServer.tryBuyBrainrot(player: Player, brainrotId: unknown)
	local session = sessions[player]
	if not session or type(brainrotId) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (session.lastBuyAt or 0) < 0.5 then
		return
	end
	session.lastBuyAt = now
	if waveState ~= "idle" then
		notify(player, "Banjir! Tunggu gelombangnya lewat.", Color3.fromRGB(140, 210, 255))
		return
	end
	local model = conveyor[brainrotId]
	if not model then
		return
	end
	local price = model:GetAttribute("Price") or 0
	if session.money < price then
		notify(player, "Uangmu kurang! Butuh Rp " .. tostring(price) .. ".", Color3.fromRGB(255, 120, 120))
		return
	end
	local pad = freePadIndex(session)
	if not pad then
		notify(player, "Warungmu penuh! Rebirth untuk mulai lagi.", Color3.fromRGB(255, 220, 120))
		return
	end
	session.money -= price
	conveyor[brainrotId] = nil
	placeBrainrotOnPad(model, session.plotIndex, pad, player.UserId)
	table.insert(session.owned, { model = model, castId = model:GetAttribute("CastId"), mutation = model:GetAttribute("Mutation"), pad = pad })
	local cast = findCast(model:GetAttribute("CastId"))
	notify(player, "Dibeli: " .. (cast and cast.name or "Brainrot") .. "!", Color3.fromRGB(140, 255, 140))
	updateLeaderstats(player)
	pushState(player)
end

-- tryStealBrainrot starts a carry: the brainrot rides above the thief's
-- head until they reach their own plot, the wave hits, or they die.
function GameServer.tryStealBrainrot(player: Player, brainrotId: unknown)
	local session = sessions[player]
	if not session or type(brainrotId) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (session.lastStealAt or 0) < BrainrotConfig.ECONOMY.StealCooldown then
		return
	end
	session.lastStealAt = now
	if session.carrying then
		notify(player, "Kamu sudah membawa satu brainrot!", Color3.fromRGB(255, 220, 120))
		return
	end
	local target: Model? = nil
	local victim: Player? = nil
	for other, otherSession in sessions do
		if other ~= player then
			for _, owned in otherSession.owned do
				local ownedModel = owned.model :: Model
				if ownedModel:GetAttribute("BrainrotId") == brainrotId then
					target = ownedModel
					victim = other
					break
				end
			end
		end
		if target then
			break
		end
	end
	if not target or not victim then
		return
	end
	local victimSession = sessions[victim]
	if victimSession and (victimSession.lockUntil or 0) > now then
		notify(player, "Warung itu terkunci!", Color3.fromRGB(255, 120, 120))
		return
	end
	local pad = freePadIndex(session)
	if not pad then
		notify(player, "Warungmu penuh, tidak bisa menampung curian!", Color3.fromRGB(255, 220, 120))
		return
	end
	-- Lift it off the victim's plot and mark it carried.
	for i, owned in victimSession.owned do
		local ownedModel = owned.model :: Model
		if ownedModel == target then
			table.remove(victimSession.owned, i)
			break
		end
	end
	session.carrying = target
	notify(player, "Lari! Bawa ke warungmu sebelum banjir!", Color3.fromRGB(255, 220, 120))
	notify(victim, "Brainrotmu dicuri " .. player.DisplayName .. "!", Color3.fromRGB(255, 120, 120))
	pushState(player)
	pushState(victim)
end

-- lockBase locks the player's own warung for 30 seconds; stealing from a
-- locked warung is refused. Cooldown 90 seconds after it ends.
function GameServer.tryLockBase(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local now = os.clock()
	if (session.lockCooldownUntil or 0) > now then
		notify(player, "Kunci masih cooldown.", Color3.fromRGB(255, 220, 120))
		return
	end
	session.lockUntil = now + BrainrotConfig.ECONOMY.LockDuration
	session.lockCooldownUntil = session.lockUntil + BrainrotConfig.ECONOMY.LockCooldown
	notify(player, "Warung terkunci 30 detik!", Color3.fromRGB(140, 210, 255))
	pushState(player)
end

-- doRebirth resets money and the warung and grants a permanent income
-- multiplier. The requirement is lifetime earnings, so it only grows.
function GameServer.doRebirth(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local now = os.clock()
	if now - (session.lastRebirthAt or 0) < 2 then
		return
	end
	session.lastRebirthAt = now
	local requirement = rebirthRequirement(session.rebirths)
	if session.lifetimeEarned < requirement then
		notify(player, "Rebirth butuh total Rp " .. tostring(requirement) .. " yang pernah kamu hasilkan.", Color3.fromRGB(255, 220, 120))
		return
	end
	for _, owned in session.owned do
		local ownedModel = owned.model :: Model
		local connection = clickConnections[ownedModel:GetAttribute("BrainrotId")]
		if connection then
			connection:Disconnect()
			clickConnections[ownedModel:GetAttribute("BrainrotId")] = nil
		end
		ownedModel:Destroy()
	end
	session.owned = {}
	session.money = BrainrotConfig.ECONOMY.StartMoney
	session.rebirths += 1
	notify(player, "REBIRTH! Penghasilanmu sekarang x" .. tostring(1 + session.rebirths) .. ".", Color3.fromRGB(255, 215, 60))
	updateLeaderstats(player)
	pushState(player)
	PlayerData.savePlayer(player, {
		money = session.money,
		lifetimeEarned = session.lifetimeEarned,
		rebirths = session.rebirths,
		owned = {},
	}, session.dataLoaded)
end

-- spawnConveyorBrainrot rolls a new character and puts it at the start of
-- the belt, facing the direction it walks.
local function spawnConveyorBrainrot()
	local count = 0
	for _ in conveyor do
		count += 1
	end
	if count >= BrainrotConfig.MAP.MaxOnConveyor then
		return
	end
	local cast, mutationId = rollBrainrot()
	local brainrotId = "B" .. tostring(nextBrainrotId)
	nextBrainrotId += 1
	local model = BrainrotFactory.createBrainrotModel(cast, mutationId, brainrotId)
	model.Parent = Workspace:WaitForChild("WarungWorld")
	local map = BrainrotConfig.MAP
	model:PivotTo(CFrame.new(map.ConveyorStartX, map.ConveyorTopY + 0.9 * cast.scale, map.ConveyorZ) * CFrame.Angles(0, math.rad(-90), 0))
	conveyor[brainrotId] = model
	local click = model.PrimaryPart:FindFirstChildOfClass("ClickDetector")
	if click then
		clickConnections[brainrotId] = click.MouseClick:Connect(function(player: Player)
			onBrainrotClicked(player, model)
		end)
	end
end

-- moveConveyorAndCarried runs every physics step: the belt walks its
-- brainrots forward, and a carried brainrot rides above its thief's head
-- until the thief reaches their own plot.
local function moveConveyorAndCarried(dt: number)
	local map = BrainrotConfig.MAP
	for brainrotId, model in conveyor do
		if not model.Parent then
			conveyor[brainrotId] = nil
		else
			local pos = model:GetPivot().Position
			local newX = pos.X + map.ConveyorSpeed * dt
			if newX >= map.ConveyorEndX then
				destroyBrainrot(brainrotId)
			else
				model:PivotTo(CFrame.new(newX, pos.Y, pos.Z) * CFrame.Angles(0, math.rad(-90), 0))
			end
		end
	end
	for player, session in sessions do
		local carried = session.carrying :: Model?
		if carried then
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or humanoid.Health <= 0 or not root then
				-- The thief died or left: the brainrot goes home.
				session.carrying = nil
				returnBrainrotToOwner(carried)
				continue
			else
				carried:PivotTo(root.CFrame * CFrame.new(0, 4, 0))
				local plot = world.plots[session.plotIndex]
				if (root.Position - plot.center).Magnitude < 16 then
					-- Home: put it on a free pad and hand over ownership.
					local pad = freePadIndex(session)
					if pad then
						session.carrying = nil
						placeBrainrotOnPad(carried, session.plotIndex, pad, player.UserId)
						table.insert(session.owned, { model = carried, castId = carried:GetAttribute("CastId"), mutation = carried:GetAttribute("Mutation"), pad = pad })
						notify(player, "Curian berhasil! Brainrot itu sekarang milikmu.", Color3.fromRGB(140, 255, 140))
						pushState(player)
					else
						session.carrying = nil
						returnBrainrotToOwner(carried)
					end
				end
			end
		end
	end
end

-- tickIncome runs once a second: every owned brainrot pays its rate into
-- its owner's wallet, and the HUD and leaderboard follow.
local function tickIncome()
	while true do
		task.wait(1)
		for player, session in sessions do
			if session.dataLoaded then
				local earned = incomePerSecond(session)
				session.money += earned
				session.lifetimeEarned += earned
				updateLeaderstats(player)
				pushState(player)
			end
		end
		if waveState == "idle" then
			waveTimer -= 1
			if waveTimer <= BrainrotConfig.WAVE.WarningSeconds then
				waveState = "warning"
				notify(nil, "BANJIR BANDANG dalam " .. tostring(BrainrotConfig.WAVE.WarningSeconds) .. " detik! Balik ke warungmu!", Color3.fromRGB(140, 210, 255))
			end
		elseif waveState == "warning" then
			waveTimer -= 1
			if waveTimer <= 0 then
				GameServer.startWaveSweep()
			end
		end
	end
end

-- startWaveSweep runs the flood: a wall of water crosses the map, the
-- conveyor is cleared, anyone in the street is pushed back to their
-- warung, and anything being carried goes home.
function GameServer.startWaveSweep()
	if waveState == "sweep" then
		return
	end
	waveState = "sweep"
	notify(nil, "BANJIR BANDANG! Lari ke warungmu!", Color3.fromRGB(120, 180, 255))
	-- Clear the conveyor: the flood takes what nobody bought.
	for brainrotId in conveyor do
		destroyBrainrot(brainrotId)
	end
	-- Anything being carried drops and goes home.
	for _, session in sessions do
		local carried = session.carrying :: Model?
		if carried then
			session.carrying = nil
			returnBrainrotToOwner(carried)
		end
	end
	local wall = Instance.new("Part")
	wall.Name = "WaveWall"
	wall.Size = Vector3.new(4, 26, 200)
	wall.Position = Vector3.new(-95, 13, 0)
	wall.Color = Color3.fromRGB(60, 140, 255)
	wall.Material = Enum.Material.SmoothPlastic
	wall.Transparency = 0.35
	wall.Anchored = true
	wall.CanCollide = false
	wall.Parent = Workspace
	waveWall = wall
	local tween = TweenService:Create(wall, TweenInfo.new(BrainrotConfig.WAVE.SweepSeconds, Enum.EasingStyle.Linear), { Position = Vector3.new(95, 13, 0) })
	tween:Play()
	-- Push players out of the street while the wall crosses.
	task.spawn(function()
		for _ = 1, 16 do
			task.wait(0.5)
			for player, session in sessions do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and math.abs(root.Position.Z) < BrainrotConfig.WAVE.StreetHalfWidth then
					local plot = world.plots[session.plotIndex]
					root.CFrame = CFrame.new(plot.center + Vector3.new(0, 5, 0))
				end
			end
		end
	end)
	task.delay(BrainrotConfig.WAVE.SweepSeconds + 1, function()
		if waveWall then
			waveWall:Destroy()
			waveWall = nil
		end
		waveState = "idle"
		waveTimer = BrainrotConfig.WAVE.Period
		notify(nil, "Banjir surut. Konveyor jalan lagi!", Color3.fromRGB(140, 255, 140))
	end)
end

-- assignPlot gives a joining player the first free warung and writes their
-- name on its sign. Six plots, first come first served.
local function assignPlot(player: Player): number
	for index = 1, #world.plots do
		local taken = false
		for _, session in sessions do
			if session.plotIndex == index then
				taken = true
				break
			end
		end
		if not taken then
			return index
		end
	end
	return 0
end

local function setPlotSign(plotIndex: number, text: string)
	local plot = world.plots[plotIndex]
	if not plot then
		return
	end
	local label = plot.sign:FindFirstChild("Label")
	local textLabel = label and label:FindFirstChild("Text")
	if textLabel and textLabel:IsA("TextLabel") then
		textLabel.Text = text
	end
end

-- respawnOwnedBrainrots rebuilds a returning player's saved warung from
-- their save data: ids and mutations only, models rebuilt fresh.
local function respawnOwnedBrainrots(player: Player, session: { [string]: any })
	for _, entry in session.savedOwned do
		local cast = findCast(entry.castId)
		if cast then
			local pad = entry.pad
			local taken = false
			for _, owned in session.owned do
				if owned.pad == pad then
					taken = true
					break
				end
			end
			if not taken then
				local brainrotId = "B" .. tostring(nextBrainrotId)
				nextBrainrotId += 1
				local model = BrainrotFactory.createBrainrotModel(cast, entry.mutation, brainrotId)
				model.Parent = Workspace:WaitForChild("WarungWorld")
				placeBrainrotOnPad(model, session.plotIndex, pad, player.UserId)
				table.insert(session.owned, { model = model, castId = entry.castId, mutation = entry.mutation, pad = pad })
				local click = model.PrimaryPart:FindFirstChildOfClass("ClickDetector")
				if click then
					clickConnections[brainrotId] = click.MouseClick:Connect(function(clickingPlayer: Player)
						onBrainrotClicked(clickingPlayer, model)
					end)
				end
			end
		end
	end
end

local function onPlayerAdded(player: Player)
	-- leaderstats first: the leaderboard shows Uang and Rebirth.
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local money = Instance.new("IntValue")
	money.Name = "Uang"
	money.Parent = stats
	local rebirth = Instance.new("IntValue")
	rebirth.Name = "Rebirth"
	rebirth.Parent = stats
	stats.Parent = player
	local data = PlayerData.loadPlayer(player)
	local session: { [string]: any } = {
		money = BrainrotConfig.ECONOMY.StartMoney,
		lifetimeEarned = 0,
		rebirths = 0,
		owned = {},
		savedOwned = {},
		plotIndex = 0,
		dataLoaded = data ~= nil,
		carrying = nil,
		lockUntil = 0,
		lockCooldownUntil = 0,
		lastBuyAt = 0,
		lastStealAt = 0,
		lastRebirthAt = 0,
	}
	if data then
		session.money = data.money
		session.lifetimeEarned = data.lifetimeEarned
		session.rebirths = data.rebirths
		session.savedOwned = data.owned
	else
		notify(player, "Datamu gagal dimuat; progres sesi ini tidak akan disimpan.", Color3.fromRGB(255, 120, 120))
	end
	session.plotIndex = assignPlot(player)
	sessions[player] = session
	if session.plotIndex > 0 then
		setPlotSign(session.plotIndex, player.DisplayName .. " • WARUNG " .. tostring(session.plotIndex))
		respawnOwnedBrainrots(player, session)
		-- Spawn the player at their warung's edge, facing the conveyor.
		local plot = world.plots[session.plotIndex]
		player.RespawnLocation = nil
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			local root = character:WaitForChild("HumanoidRootPart", 10)
			if root then
				root.CFrame = CFrame.new(plot.center + Vector3.new(0, 5, if plot.center.Z > 0 then -14 else 14))
			end
		end)
	else
		notify(player, "Semua warung penuh! Kamu jadi penonton dulu.", Color3.fromRGB(255, 220, 120))
	end
	updateLeaderstats(player)
	pushState(player)
end

local function sessionToSaveData(session: { [string]: any }): { [string]: any }
	local owned = {}
	for _, entry in session.owned do
		table.insert(owned, { castId = entry.castId, mutation = entry.mutation, pad = entry.pad })
	end
	return { money = session.money, lifetimeEarned = session.lifetimeEarned, rebirths = session.rebirths, owned = owned }
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	if session.carrying then
		local carried = session.carrying :: Model
		session.carrying = nil
		returnBrainrotToOwner(carried)
	end
	PlayerData.savePlayer(player, sessionToSaveData(session), session.dataLoaded)
	for _, owned in session.owned do
		local ownedModel = owned.model :: Model
		local connection = clickConnections[ownedModel:GetAttribute("BrainrotId")]
		if connection then
			connection:Disconnect()
			clickConnections[ownedModel:GetAttribute("BrainrotId")] = nil
		end
		ownedModel:Destroy()
	end
	if session.plotIndex > 0 then
		setPlotSign(session.plotIndex, "WARUNG " .. tostring(session.plotIndex))
	end
	sessions[player] = nil
end

local function autosaveLoop()
	while true do
		task.wait(BrainrotConfig.SAVE.AutosaveSeconds)
		for player, session in sessions do
			PlayerData.savePlayer(player, sessionToSaveData(session), session.dataLoaded)
		end
	end
end

local function conveyorLoop()
	while true do
		task.wait(BrainrotConfig.MAP.SpawnInterval)
		if waveState == "idle" then
			spawnConveyorBrainrot()
		end
	end
end

local function setupRemotes()
	local remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
	remotes = {}
	for _, name in { "BuyBrainrot", "StealBrainrot", "LockBase", "Rebirth", "StateUpdate", "Notify" } do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
		remotes[name] = remote
	end
	-- The client only ever sends intent (an id, or nothing). Prices, money
	-- and ownership are all decided here, on the server.
	remotes.BuyBrainrot.OnServerEvent:Connect(function(player: Player, brainrotId: unknown)
		GameServer.tryBuyBrainrot(player, brainrotId)
	end)
	remotes.StealBrainrot.OnServerEvent:Connect(function(player: Player, brainrotId: unknown)
		GameServer.tryStealBrainrot(player, brainrotId)
	end)
	remotes.LockBase.OnServerEvent:Connect(function(player: Player)
		GameServer.tryLockBase(player)
	end)
	remotes.Rebirth.OnServerEvent:Connect(function(player: Player)
		GameServer.doRebirth(player)
	end)
end

-- debugSpawn and debugStartWave exist for the TOUR.json the reviewers use
-- to bring the game to a screenshot: spawn a Legendary on the belt, and
-- start the flood now.
function GameServer.debugSpawn(castId: string)
	local cast = findCast(castId)
	if not cast then
		return
	end
	local brainrotId = "B" .. tostring(nextBrainrotId)
	nextBrainrotId += 1
	local model = BrainrotFactory.createBrainrotModel(cast, "Emas", brainrotId)
	model.Parent = Workspace:WaitForChild("WarungWorld")
	local map = BrainrotConfig.MAP
	model:PivotTo(CFrame.new(map.ConveyorStartX + 20, map.ConveyorTopY + 0.9 * cast.scale, map.ConveyorZ) * CFrame.Angles(0, math.rad(-90), 0))
	conveyor[brainrotId] = model
end

function GameServer.debugStartWave()
	waveTimer = 0
	waveState = "warning"
end

-- start builds the world, the remotes, and every loop, then welcomes
-- players who are already here as well as players who join later.
function GameServer.start()
	world = WorldBuilder.buildWorld()
	setupRemotes()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	RunService.Heartbeat:Connect(moveConveyorAndCarried)
	task.spawn(tickIncome)
	task.spawn(conveyorLoop)
	task.spawn(autosaveLoop)
	game:BindToClose(function()
		for player, session in sessions do
			PlayerData.savePlayer(player, sessionToSaveData(session), session.dataLoaded)
		end
	end)
	-- A few brainrots on the belt from the first second, so the first
	-- screenshot already shows the loop.
	for _ = 1, 4 do
		spawnConveyorBrainrot()
	end
	print("[WarungKopi] GameServer started: Warung Kopi Brainrot is open.")
end

return GameServer
