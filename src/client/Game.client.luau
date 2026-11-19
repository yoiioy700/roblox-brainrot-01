-- Warung Kopi Brainrot: the client. It builds the HUD and shows what the
-- server says: money, income per second, the flood timer, the collection,
-- and banners. It never keeps its own copy of the economy and never
-- decides a purchase; every button only sends intent to the server.
-- The HUD stays clear of the top-left corner, where Roblox's own menu
-- buttons sit over the play view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FormatUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FormatUtil"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- formatClock turns seconds into "2:34" for the flood timer.
local function formatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%02d", minutes, rest)
end

-- makeText builds one label with the HUD's shared look: bold, white,
-- stroked so it reads over the 3D world at a glance.
local function makeText(parent: Instance, name: string, text: string, size: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.Font = Enum.Font.SourceSansBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Text = text
	button.TextSize = 18
	button.Font = Enum.Font.SourceSansBold
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.5
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

-- buildHud creates the whole interface: money top-centre, the flood timer
-- and the two action buttons top-right, the collection bottom-centre, the
-- how-to-play hint bottom-left, and a centre banner for server messages.
local function buildHud(): { [string]: Instance }
	local gui = Instance.new("ScreenGui")
	gui.Name = "WarungHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui

	local moneyFrame = Instance.new("Frame")
	moneyFrame.Name = "MoneyFrame"
	moneyFrame.AnchorPoint = Vector2.new(0.5, 0)
	moneyFrame.Position = UDim2.new(0.5, 0, 0, 8)
	moneyFrame.Size = UDim2.fromOffset(260, 64)
	moneyFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	moneyFrame.BackgroundTransparency = 0.25
	moneyFrame.BorderSizePixel = 0
	moneyFrame.Parent = gui
	local moneyCorner = Instance.new("UICorner")
	moneyCorner.CornerRadius = UDim.new(0, 10)
	moneyCorner.Parent = moneyFrame
	local moneyLabel = makeText(moneyFrame, "MoneyLabel", "Rp 100", UDim2.new(1, 0, 0, 36), 30, Color3.fromRGB(255, 220, 90))
	moneyLabel.Position = UDim2.new(0, 0, 0, 2)
	local incomeLabel = makeText(moneyFrame, "IncomeLabel", "Rp 0/detik", UDim2.new(1, 0, 0, 22), 18, Color3.fromRGB(140, 255, 140))
	incomeLabel.Position = UDim2.new(0, 0, 0, 38)
	incomeLabel.Font = Enum.Font.SourceSans

	local waveFrame = Instance.new("Frame")
	waveFrame.Name = "WaveFrame"
	waveFrame.AnchorPoint = Vector2.new(1, 0)
	waveFrame.Position = UDim2.new(1, -12, 0, 8)
	waveFrame.Size = UDim2.fromOffset(220, 40)
	waveFrame.BackgroundColor3 = Color3.fromRGB(30, 60, 90)
	waveFrame.BackgroundTransparency = 0.25
	waveFrame.BorderSizePixel = 0
	waveFrame.Parent = gui
	local waveCorner = Instance.new("UICorner")
	waveCorner.CornerRadius = UDim.new(0, 10)
	waveCorner.Parent = waveFrame
	local waveLabel = makeText(waveFrame, "WaveLabel", "Banjir dalam 3:00", UDim2.fromScale(1, 1), 20, Color3.fromRGB(140, 210, 255))

	local lockButton = makeButton(gui, "LockButton", "Kunci Warung (30 dtk)", UDim2.fromOffset(200, 40), UDim2.new(1, -212, 0, 56), Color3.fromRGB(60, 90, 160))
	local rebirthButton = makeButton(gui, "RebirthButton", "Rebirth", UDim2.fromOffset(200, 40), UDim2.new(1, -212, 0, 104), Color3.fromRGB(160, 90, 30))

	local collectionFrame = Instance.new("Frame")
	collectionFrame.Name = "CollectionFrame"
	collectionFrame.AnchorPoint = Vector2.new(0.5, 1)
	collectionFrame.Position = UDim2.new(0.5, 0, 1, -12)
	collectionFrame.Size = UDim2.fromOffset(420, 36)
	collectionFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	collectionFrame.BackgroundTransparency = 0.25
	collectionFrame.BorderSizePixel = 0
	collectionFrame.Parent = gui
	local collectionCorner = Instance.new("UICorner")
	collectionCorner.CornerRadius = UDim.new(0, 10)
	collectionCorner.Parent = collectionFrame
	local collectionLabel = makeText(collectionFrame, "CollectionLabel", "Koleksi: 0/8", UDim2.fromScale(1, 1), 20, Color3.fromRGB(255, 255, 255))

	local hintLabel = makeText(gui, "HintLabel", "Klik brainrot di conveyor untuk beli  •  Klik brainrot orang lain untuk curi  •  Lari pulang saat banjir!", UDim2.new(1, -24, 0, 24), 16, Color3.fromRGB(230, 230, 230))
	hintLabel.AnchorPoint = Vector2.new(0, 1)
	hintLabel.Position = UDim2.new(0, 12, 1, -56)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Font = Enum.Font.SourceSans

	local bannerLabel = makeText(gui, "BannerLabel", "", UDim2.new(0.8, 0, 0, 44), 28, Color3.fromRGB(255, 255, 255))
	bannerLabel.AnchorPoint = Vector2.new(0.5, 0)
	bannerLabel.Position = UDim2.new(0.5, 0, 0, 96)
	bannerLabel.TextTransparency = 1

	return {
		moneyLabel = moneyLabel,
		incomeLabel = incomeLabel,
		waveLabel = waveLabel,
		lockButton = lockButton,
		rebirthButton = rebirthButton,
		collectionLabel = collectionLabel,
		bannerLabel = bannerLabel,
	}
end

local hud = buildHud()
local moneyLabel = hud.moneyLabel :: TextLabel
local incomeLabel = hud.incomeLabel :: TextLabel
local waveLabel = hud.waveLabel :: TextLabel
local lockButton = hud.lockButton :: TextButton
local rebirthButton = hud.rebirthButton :: TextButton
local collectionLabel = hud.collectionLabel :: TextLabel
local bannerLabel = hud.bannerLabel :: TextLabel

-- showBanner fades a message in centre-screen, holds it, then fades it
-- out. A new message cancels the old fade so they never stack.
local bannerTween: Tween? = nil
local function showBanner(text: string, color: Color3)
	if bannerTween then
		bannerTween:Cancel()
		bannerTween = nil
	end
	bannerLabel.Text = text
	bannerLabel.TextColor3 = color
	bannerLabel.TextTransparency = 0
	bannerTween = TweenService:Create(bannerLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 })
	task.delay(2.5, function()
		if bannerTween then
			bannerTween:Play()
		end
	end)
end

-- updateHud renders one server state onto every label. It runs only when
-- the server sends a state, never on a timer of its own.
local function updateHud(state: { [string]: any })
	moneyLabel.Text = FormatUtil.formatRupiah(state.money or 0)
	incomeLabel.Text = FormatUtil.formatRupiah(state.incomePerSecond or 0) .. "/detik"
	local waveState = state.waveState or "idle"
	if waveState == "idle" then
		waveLabel.Text = "Banjir dalam " .. formatClock(state.waveCountdown or 0)
		waveLabel.TextColor3 = Color3.fromRGB(140, 210, 255)
	elseif waveState == "warning" then
		waveLabel.Text = "BANJIR DALAM " .. tostring(state.waveCountdown or 0) .. " DETIK!"
		waveLabel.TextColor3 = Color3.fromRGB(255, 180, 60)
	else
		waveLabel.Text = "BANJIR BANDANG!"
		waveLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	end
	local lockRemaining = state.lockRemaining or 0
	local lockCooldown = state.lockCooldownRemaining or 0
	if lockRemaining > 0 then
		lockButton.Text = "Terkunci (" .. tostring(math.ceil(lockRemaining)) .. " dtk)"
	elseif lockCooldown > 0 then
		lockButton.Text = "Kunci cooldown (" .. tostring(math.ceil(lockCooldown)) .. " dtk)"
	else
		lockButton.Text = "Kunci Warung (30 dtk)"
	end
	rebirthButton.Text = "Rebirth (butuh Rp " .. FormatUtil.formatNumber(state.rebirthRequirement or 0, 1) .. ")"
	local plotText = ""
	if (state.plotIndex or 0) > 0 then
		plotText = "  •  Warung " .. tostring(state.plotIndex)
	end
	collectionLabel.Text = "Koleksi: " .. tostring(state.ownedCount or 0) .. "/8  •  Rebirth: " .. tostring(state.rebirths or 0) .. plotText
end

local lockRemote = remotes:WaitForChild("LockBase") :: RemoteEvent
local rebirthRemote = remotes:WaitForChild("Rebirth") :: RemoteEvent
local stateUpdateRemote = remotes:WaitForChild("StateUpdate") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

lockButton.Activated:Connect(function()
	lockRemote:FireServer()
end)

rebirthButton.Activated:Connect(function()
	rebirthRemote:FireServer()
end)

stateUpdateRemote.OnClientEvent:Connect(updateHud)
notifyRemote.OnClientEvent:Connect(function(text: string, color: Color3)
	showBanner(text, color)
end)
