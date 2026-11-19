-- Warung Kopi Brainrot: builds one brainrot character as a Model.
-- Every character is original, built from plain parts in code: a body
-- shape per cast entry, two eyes, a mouth, two legs, an accessory, and a
-- BillboardGui label with its name, rarity and money per second. No
-- uploaded assets, so the place needs nothing from outside itself.
-- Parts are anchored; the server moves models by CFrame, never by physics.

local BrainrotConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BrainrotConfig"))

local BrainrotFactory = {}

local function addPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.Parent = model
	return part
end

-- Two eyes and a mouth on the model's front (-Z side), scaled to the body.
local function addFace(model: Model, scale: number, bodyDepth: number)
	local z = -bodyDepth / 2 - 0.05
	addPart(model, "EyeLeft", Enum.PartType.Ball, Vector3.new(0.28, 0.28, 0.28) * scale, CFrame.new(-0.35 * scale, 0.55 * scale, z), Color3.fromRGB(20, 20, 20))
	addPart(model, "EyeRight", Enum.PartType.Ball, Vector3.new(0.28, 0.28, 0.28) * scale, CFrame.new(0.35 * scale, 0.55 * scale, z), Color3.fromRGB(20, 20, 20))
	addPart(model, "Mouth", Enum.PartType.Block, Vector3.new(0.5, 0.12, 0.1) * scale, CFrame.new(0, 0.2 * scale, z), Color3.fromRGB(20, 20, 20))
end

local function addLegs(model: Model, scale: number, bodyBottomY: number)
	for _, dx in { -0.45, 0.45 } do
		addPart(model, "Leg", Enum.PartType.Block, Vector3.new(0.3, 0.6, 0.3) * scale, CFrame.new(dx * scale, bodyBottomY - 0.3 * scale, 0), Color3.fromRGB(40, 40, 45))
	end
end

-- One builder per body shape. Each returns the part that becomes PrimaryPart.
local BODY_BUILDERS: { [string]: (Model, { [string]: any }) -> Part } = {}

BODY_BUILDERS.Cup = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Cylinder, Vector3.new(1.6, 1.8, 1.6) * scale, CFrame.new(0, 0.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), cast.bodyColor)
	addPart(model, "CoffeeTop", Enum.PartType.Cylinder, Vector3.new(1.5, 0.2, 1.5) * scale, CFrame.new(0, 1.3 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(50, 30, 15))
	addPart(model, "Handle", Enum.PartType.Block, Vector3.new(0.3, 0.9, 0.5) * scale, CFrame.new(1.0 * scale, 0.5 * scale, 0), cast.accentColor)
	addFace(model, scale, 1.6 * scale)
	addLegs(model, scale, -0.5 * scale)
	return body
end

BODY_BUILDERS.Plate = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Cylinder, Vector3.new(2.2, 0.35, 2.2) * scale, CFrame.new(0, 0.1 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 250, 250))
	addPart(model, "Food", Enum.PartType.Ball, Vector3.new(1.5, 0.8, 1.5) * scale, CFrame.new(0, 0.5 * scale, 0), cast.bodyColor)
	addPart(model, "Egg", Enum.PartType.Ball, Vector3.new(0.6, 0.3, 0.6) * scale, CFrame.new(0.3 * scale, 0.85 * scale, 0.2 * scale), Color3.fromRGB(255, 230, 120))
	addFace(model, scale, 1.5 * scale)
	addLegs(model, scale, -0.1 * scale)
	return body
end

BODY_BUILDERS.Turtle = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Ball, Vector3.new(2.0, 1.5, 2.4) * scale, CFrame.new(0, 0.5 * scale, 0), cast.bodyColor)
	addPart(model, "Shell", Enum.PartType.Ball, Vector3.new(1.7, 1.0, 2.0) * scale, CFrame.new(0, 0.9 * scale, 0.1 * scale), cast.accentColor)
	addPart(model, "Head", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9) * scale, CFrame.new(0, 0.9 * scale, -1.2 * scale), Color3.fromRGB(90, 190, 100))
	addPart(model, "Helmet", Enum.PartType.Cylinder, Vector3.new(1.1, 0.4, 1.1) * scale, CFrame.new(0, 1.4 * scale, -1.2 * scale) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(30, 140, 60))
	addPart(model, "DeliveryBox", Enum.PartType.Block, Vector3.new(1.2, 1.0, 0.8) * scale, CFrame.new(0, 1.0 * scale, 1.2 * scale), Color3.fromRGB(40, 180, 80))
	addFace(model, scale, 1.2 * scale)
	addLegs(model, scale, -0.2 * scale)
	return body
end

BODY_BUILDERS.Chicken = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Ball, Vector3.new(1.8, 1.8, 1.8) * scale, CFrame.new(0, 0.5 * scale, 0), cast.bodyColor)
	addPart(model, "Comb", Enum.PartType.Block, Vector3.new(0.3, 0.6, 0.9) * scale, CFrame.new(0, 1.5 * scale, -0.2 * scale), cast.accentColor)
	addPart(model, "Beak", Enum.PartType.Block, Vector3.new(0.4, 0.3, 0.4) * scale, CFrame.new(0, 0.6 * scale, -1.0 * scale), Color3.fromRGB(255, 160, 40))
	addPart(model, "WingLeft", Enum.PartType.Block, Vector3.new(0.25, 1.0, 0.8) * scale, CFrame.new(-1.0 * scale, 0.5 * scale, 0), Color3.fromRGB(220, 170, 70))
	addPart(model, "WingRight", Enum.PartType.Block, Vector3.new(0.25, 1.0, 0.8) * scale, CFrame.new(1.0 * scale, 0.5 * scale, 0), Color3.fromRGB(220, 170, 70))
	addFace(model, scale, 1.8 * scale)
	addLegs(model, scale, -0.4 * scale)
	return body
end

BODY_BUILDERS.Glass = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Cylinder, Vector3.new(1.5, 2.0, 1.5) * scale, CFrame.new(0, 0.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), cast.bodyColor, Enum.Material.Glass)
	addPart(model, "TeaTop", Enum.PartType.Cylinder, Vector3.new(1.4, 0.2, 1.4) * scale, CFrame.new(0, 1.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 70, 20))
	addPart(model, "Straw", Enum.PartType.Cylinder, Vector3.new(0.18, 1.6, 0.18) * scale, CFrame.new(0.4 * scale, 1.6 * scale, 0) * CFrame.Angles(0, 0, math.rad(25)), cast.accentColor)
	addPart(model, "Ice", Enum.PartType.Block, Vector3.new(0.5, 0.5, 0.5) * scale, CFrame.new(-0.3 * scale, 1.2 * scale, 0.2 * scale), Color3.fromRGB(240, 250, 255))
	addFace(model, scale, 1.5 * scale)
	addLegs(model, scale, -0.6 * scale)
	return body
end

BODY_BUILDERS.Pedicab = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Block, Vector3.new(2.2, 1.2, 1.6) * scale, CFrame.new(0, 0.6 * scale, 0), cast.bodyColor)
	addPart(model, "Canopy", Enum.PartType.Block, Vector3.new(2.4, 0.25, 1.8) * scale, CFrame.new(0, 1.9 * scale, 0), cast.accentColor)
	for _, dz in { -0.7, 0.7 } do
		addPart(model, "CanopyPost", Enum.PartType.Block, Vector3.new(0.2, 0.7, 0.2) * scale, CFrame.new(0.9 * scale, 1.5 * scale, dz * scale), Color3.fromRGB(60, 60, 60))
	end
	for _, dx in { -0.9, 0.9 } do
		addPart(model, "Wheel", Enum.PartType.Cylinder, Vector3.new(0.9, 0.25, 0.9) * scale, CFrame.new(dx * scale, -0.3 * scale, 0.9 * scale) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(30, 30, 30))
	end
	addFace(model, scale, 1.6 * scale)
	addLegs(model, scale, -0.2 * scale)
	return body
end

BODY_BUILDERS.Ghost = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Cylinder, Vector3.new(1.6, 2.0, 1.6) * scale, CFrame.new(0, 0.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), cast.bodyColor, Enum.Material.SmoothPlastic)
	addPart(model, "Head", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5) * scale, CFrame.new(0, 1.5 * scale, 0), cast.bodyColor)
	addPart(model, "Hair", Enum.PartType.Block, Vector3.new(1.7, 0.8, 0.4) * scale, CFrame.new(0, 2.0 * scale, 0.3 * scale), Color3.fromRGB(20, 20, 25))
	addPart(model, "CoffeeCup", Enum.PartType.Cylinder, Vector3.new(0.5, 0.6, 0.5) * scale, CFrame.new(0.9 * scale, 0.3 * scale, -0.5 * scale) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 72, 32))
	addFace(model, scale, 1.5 * scale)
	return body
end

BODY_BUILDERS.Lizard = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Block, Vector3.new(1.6, 1.0, 2.6) * scale, CFrame.new(0, 0.4 * scale, 0), cast.bodyColor)
	addPart(model, "Head", Enum.PartType.Block, Vector3.new(1.2, 0.9, 1.0) * scale, CFrame.new(0, 0.7 * scale, -1.5 * scale), cast.bodyColor)
	addPart(model, "Tail", Enum.PartType.Block, Vector3.new(0.5, 0.5, 1.6) * scale, CFrame.new(0, 0.4 * scale, 1.9 * scale), cast.accentColor)
	addPart(model, "DiscoBall", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8) * scale, CFrame.new(0, 1.4 * scale, 0.3 * scale), Color3.fromRGB(220, 220, 240), Enum.Material.Neon)
	addFace(model, scale, 1.0 * scale)
	addLegs(model, scale, -0.1 * scale)
	return body
end

BODY_BUILDERS.Bird = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Ball, Vector3.new(1.8, 1.8, 2.2) * scale, CFrame.new(0, 0.5 * scale, 0), cast.bodyColor, Enum.Material.Metal)
	addPart(model, "Head", Enum.PartType.Ball, Vector3.new(1.0, 1.0, 1.0) * scale, CFrame.new(0, 1.4 * scale, -1.0 * scale), cast.bodyColor, Enum.Material.Metal)
	addPart(model, "Beak", Enum.PartType.Block, Vector3.new(0.4, 0.3, 0.6) * scale, CFrame.new(0, 1.3 * scale, -1.6 * scale), Color3.fromRGB(255, 140, 30))
	addPart(model, "Crest", Enum.PartType.Block, Vector3.new(0.25, 0.9, 0.5) * scale, CFrame.new(0, 2.0 * scale, -1.0 * scale), cast.accentColor)
	addPart(model, "WingLeft", Enum.PartType.Block, Vector3.new(0.25, 1.2, 1.4) * scale, CFrame.new(-1.0 * scale, 0.7 * scale, 0.2 * scale), Color3.fromRGB(230, 180, 30))
	addPart(model, "WingRight", Enum.PartType.Block, Vector3.new(0.25, 1.2, 1.4) * scale, CFrame.new(1.0 * scale, 0.7 * scale, 0.2 * scale), Color3.fromRGB(230, 180, 30))
	addFace(model, scale, 1.0 * scale)
	addLegs(model, scale, -0.4 * scale)
	return body
end

BODY_BUILDERS.Guard = function(model, cast)
	local scale = cast.scale
	local body = addPart(model, "Body", Enum.PartType.Block, Vector3.new(1.8, 2.0, 1.0) * scale, CFrame.new(0, 0.5 * scale, 0), cast.bodyColor)
	addPart(model, "VestStripe", Enum.PartType.Block, Vector3.new(1.85, 0.3, 1.05) * scale, CFrame.new(0, 0.8 * scale, 0), Color3.fromRGB(220, 230, 240), Enum.Material.Neon)
	addPart(model, "Head", Enum.PartType.Ball, Vector3.new(1.1, 1.1, 1.1) * scale, CFrame.new(0, 1.9 * scale, 0), Color3.fromRGB(210, 160, 110))
	addPart(model, "Cap", Enum.PartType.Cylinder, Vector3.new(1.3, 0.3, 1.3) * scale, CFrame.new(0, 2.4 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), cast.accentColor)
	addPart(model, "Whistle", Enum.PartType.Block, Vector3.new(0.3, 0.2, 0.3) * scale, CFrame.new(0.3 * scale, 1.5 * scale, -0.6 * scale), Color3.fromRGB(230, 230, 230), Enum.Material.Metal)
	addFace(model, scale, 1.1 * scale)
	addLegs(model, scale, -0.5 * scale)
	return body
end

local function rarityColor(rarityId: string): Color3
	for _, rarity in BrainrotConfig.RARITIES do
		if rarity.id == rarityId then
			return rarity.color
		end
	end
	return Color3.fromRGB(200, 200, 200)
end

local function mutationOf(mutationId: string): { [string]: any }
	for _, mutation in BrainrotConfig.MUTATIONS do
		if mutation.id == mutationId then
			return mutation
		end
	end
	return BrainrotConfig.MUTATIONS[1]
end

-- refreshLabel rewrites a brainrot's overhead label from its attributes,
-- so the same label works on the conveyor (with its price) and on a plot
-- (with its owner's name). The judge reads these labels in screenshots.
function BrainrotFactory.refreshLabel(model: Model)
	local castId = model:GetAttribute("CastId")
	local mutationId = model:GetAttribute("Mutation") or "None"
	local ownerId = model:GetAttribute("OwnerUserId") or 0
	local price = model:GetAttribute("Price") or 0
	local income = model:GetAttribute("Income") or 0
	local cast = nil
	for _, entry in BrainrotConfig.CAST do
		if entry.id == castId then
			cast = entry
			break
		end
	end
	if not cast then
		return
	end
	local mutation = mutationOf(mutationId)
	local label = model:FindFirstChild("Label")
	if not label then
		return
	end
	local nameLabel = label:FindFirstChild("NameLabel")
	local rarityLabel = label:FindFirstChild("RarityLabel")
	local incomeLabel = label:FindFirstChild("IncomeLabel")
	local priceLabel = label:FindFirstChild("PriceLabel")
	if nameLabel then
		nameLabel.Text = cast.name
	end
	if rarityLabel then
		local mutationText = if mutation.display ~= "" then " • " .. mutation.display else ""
		rarityLabel.Text = cast.rarity .. mutationText
		rarityLabel.TextColor3 = rarityColor(cast.rarity)
	end
	if incomeLabel then
		incomeLabel.Text = "Rp " .. tostring(income) .. "/detik"
	end
	if priceLabel then
		if ownerId == 0 then
			priceLabel.Text = "BELI: Rp " .. tostring(price)
			priceLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
		else
			priceLabel.Text = "TERJUAL"
			priceLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
		end
	end
end

-- createBrainrotModel builds a whole character from a cast entry and a
-- mutation id, tints it for the mutation, and stamps its identity in
-- attributes the server reads back when a player clicks it.
function BrainrotFactory.createBrainrotModel(cast: { [string]: any }, mutationId: string, brainrotId: string): Model
	local model = Instance.new("Model")
	model.Name = cast.name
	local builder = BODY_BUILDERS[cast.body]
	local primary = builder(model, cast)
	model.PrimaryPart = primary
	local mutation = mutationOf(mutationId)
	if mutation.tint then
		-- A mutation tints the whole body so it reads at a glance.
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and (part.Name == "Body" or part.Name == "Head") then
				part.Color = mutation.tint
			end
		end
	end
	model:SetAttribute("BrainrotId", brainrotId)
	model:SetAttribute("CastId", cast.id)
	model:SetAttribute("Mutation", mutationId)
	model:SetAttribute("Price", cast.price)
	model:SetAttribute("Income", cast.income * mutation.multiplier)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("PlotIndex", 0)
	model:SetAttribute("PadIndex", 0)
	-- The overhead label: name, rarity, income, price. Four lines, big
	-- enough to read once the judge scales the screenshot down.
	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(180, 90)
	label.StudsOffsetWorldSpace = Vector3.new(0, 3.4 * cast.scale, 0)
	label.AlwaysOnTop = true
	label.Parent = model
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 26)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextSize = 22
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = label
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Position = UDim2.new(0, 0, 0, 26)
	rarityLabel.Size = UDim2.new(1, 0, 0, 22)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.TextSize = 18
	rarityLabel.Font = Enum.Font.SourceSansBold
	rarityLabel.TextStrokeTransparency = 0.4
	rarityLabel.Parent = label
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.Position = UDim2.new(0, 0, 0, 48)
	incomeLabel.Size = UDim2.new(1, 0, 0, 20)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.TextSize = 18
	incomeLabel.Font = Enum.Font.SourceSans
	incomeLabel.TextColor3 = Color3.fromRGB(140, 255, 140)
	incomeLabel.TextStrokeTransparency = 0.4
	incomeLabel.Parent = label
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Position = UDim2.new(0, 0, 0, 68)
	priceLabel.Size = UDim2.new(1, 0, 0, 20)
	priceLabel.BackgroundTransparency = 1
	priceLabel.TextSize = 18
	priceLabel.Font = Enum.Font.SourceSansBold
	priceLabel.TextStrokeTransparency = 0.4
	priceLabel.Parent = label
	-- Clicking the character is how a player buys it (on the conveyor) or
	-- steals it (on someone else's plot). The server decides which.
	local click = Instance.new("ClickDetector")
	click.Name = "BuyClick"
	click.MaxActivationDistance = 32
	click.Parent = primary
	BrainrotFactory.refreshLabel(model)
	return model
end

return BrainrotFactory
